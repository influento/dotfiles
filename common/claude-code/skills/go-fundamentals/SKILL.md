---
name: go-fundamentals
description: Go code style, naming, types, data structures, and design patterns. TRIGGER when writing or reviewing Go code that involves struct design, interface patterns, naming conventions, or idiomatic Go style.
---

# Go Fundamentals

Code style, naming, types, data structures, and design patterns for idiomatic Go.

## Code Style

### Line Length & Breaking

Lines beyond ~120 characters MUST be broken at semantic boundaries. Function calls with 4+ arguments MUST use one argument per line. When a function signature is too long, the real fix is often fewer parameters (use an options struct).

### Variable Declarations

Use `:=` for non-zero values, `var` for zero-value initialization — the form signals intent:

```go
var count int              // zero value, set later
name := "default"          // non-zero, := is appropriate
var buf bytes.Buffer       // zero value is ready to use
```

### Slice & Map Initialization

Slices and maps MUST be initialized explicitly, never nil. Nil maps panic on write; nil slices serialize to `null` in JSON (vs `[]` for empty slices).

```go
users := []User{}                       // always initialized
m := map[string]int{}                   // always initialized
users := make([]User, 0, len(ids))      // preallocate when capacity is known
m := make(map[string]int, len(items))   // preallocate when size is known
```

Do not preallocate speculatively — `make([]T, 0, 1000)` wastes memory when the common case is 10 items.

### Composite Literals

Composite literals MUST use field names — positional fields break when the type adds or reorders fields:

```go
srv := &http.Server{
    Addr:         ":8080",
    ReadTimeout:  5 * time.Second,
    WriteTimeout: 10 * time.Second,
}
```

### Control Flow

Errors and edge cases MUST be handled first (early return). Keep the happy path at minimal indentation:

```go
func process(data []byte) (*Result, error) {
    if len(data) == 0 {
        return nil, errors.New("empty data")
    }

    parsed, err := parse(data)
    if err != nil {
        return nil, fmt.Errorf("parsing: %w", err)
    }

    return transform(parsed), nil
}
```

When the `if` body ends with `return`/`break`/`continue`, the `else` MUST be dropped.

When an `if` condition has 3+ operands, extract into named booleans. Exception: keep expensive checks inline for short-circuit benefit.

```go
isAdmin := user.Role == RoleAdmin
isOwner := resource.OwnerID == user.ID
if isAdmin || isOwner || expensivePermissionCheck(user, resource) {
    allow()
}
```

When comparing the same variable multiple times, prefer `switch` over if-else chains. Scope variables to `if` blocks when only needed for the check: `if err := validate(input); err != nil { return err }`.

### Function Design

- Functions SHOULD be short and focused — one function, one job.
- Functions SHOULD have ≤4 parameters. Beyond that, use an options struct.
- Parameter order: `context.Context` first, then inputs, then output destinations.
- Use `range` over index-based loops. Use `range n` (Go 1.22+) for simple counting.
- Naked returns are discouraged in functions longer than a few lines.

### Value vs Pointer Arguments

Pass small types (`string`, `int`, `bool`, `time.Time`) by value. Use pointers when:
- The function **mutates** the value
- The struct is **large** (~128+ bytes)
- **Nil is meaningful** (optional/nullable parameter)

```go
func FormatUser(name string, age int, createdAt time.Time) string  // value — small types
func PopulateDefaults(cfg *Config)                                  // pointer — mutation
func UpdateUser(ctx context.Context, id string, name *string) error // pointer — nil = "don't update"
```

Do NOT use pointers "just to save memory" — value copy is negligible; stack allocation is fast. For structs <~128 bytes with read-only access, values are typically faster due to cache locality.

### Code Organization Within Files

- Group related declarations: type, constructor, methods together
- Order: package doc, imports, constants, types, constructors, methods, helpers
- One primary type per file when it has significant methods
- Blank imports (`_ "pkg"`) only in `main` and test packages
- Dot imports are never acceptable
- Unexport aggressively — you can always export later; unexporting is a breaking change

### String Handling

Use `strconv` for simple conversions (faster), `fmt.Sprintf` for complex formatting. Use `%q` in error messages to make string boundaries visible. Use `strings.Builder` for loops, `+` for simple concatenation.

### Type Conversions

Prefer explicit, narrow conversions. Use generics over `any` when a concrete type will do:

```go
func Contains[T comparable](slice []T, target T) bool  // not []any
```

---

## Naming Conventions

Go favors short, readable names. Capitalization controls visibility — uppercase is exported, lowercase is unexported. All identifiers MUST use MixedCaps, NEVER underscores.

### Quick Reference

| Element | Convention | Example |
| --- | --- | --- |
| Package | lowercase, single word | `json`, `http`, `tabwriter` |
| File | lowercase, underscores OK | `user_handler.go` |
| Exported name | UpperCamelCase | `ReadAll`, `HTTPClient` |
| Unexported | lowerCamelCase | `parseToken`, `userCount` |
| Interface | method name + `-er` | `Reader`, `Closer`, `Stringer` |
| Struct | MixedCaps noun | `Request`, `FileHeader` |
| Constant | MixedCaps (not ALL_CAPS) | `MaxRetries`, `defaultTimeout` |
| Receiver | 1-2 letter abbreviation | `func (s *Server)`, `func (b *Buffer)` |
| Error variable | `Err` prefix | `ErrNotFound`, `ErrTimeout` |
| Error type | `Error` suffix | `PathError`, `SyntaxError` |
| Constructor | `New` (single type) or `NewTypeName` (multi-type) | `ring.New`, `http.NewRequest` |
| Boolean field | `is`, `has`, `can` prefix | `isReady`, `IsConnected()` |
| Acronym | all caps or all lower | `URL`, `HTTPServer`, `xmlParser` |
| Option func | `With` + field name | `WithPort()`, `WithLogger()` |
| Enum (iota) | type name prefix, zero = unknown | `StatusUnknown` at 0, `StatusReady` |
| Error string | lowercase, no punctuation | `"image: unknown format"` |
| Import alias | short, only on collision | `mrand "math/rand"` |

### Single-Letter Variable Conventions

Name length SHOULD be proportional to scope size. Common single-letter conventions:

| Letter | Meaning |
| --- | --- |
| `i`, `j`, `k` | Loop indices |
| `n` | Count or length |
| `v` | Value (in range loops) |
| `k` | Key (in map ranges) |
| `r` | `io.Reader` |
| `w` | `io.Writer` |
| `b` | `[]byte` or buffer |
| `s` | String |
| `t` | `*testing.T` |
| `ctx` | `context.Context` |
| `err` | Error |

Avoid type in the name — `users` not `userSlice`, `count` not `countInt`. Use the same name for the same concept across the codebase — `user` everywhere, not `user`/`account`/`person` depending on the file.

### Package & Directory Naming

Packages MUST be lowercase, single-word, singular. No `util`, `helper`, `common` — they say nothing about content.

Directory names SHOULD match the package name. Multi-word directories use hyphens, package drops them: `rate-limit/` → `package ratelimit`.

Special directories:
- `cmd/` — entry points, each subdirectory is `package main`
- `internal/` — restricts import visibility to parent module
- `testdata/` — ignored by the Go tool
- `vendor/` — vendored dependencies

File names MUST be lowercase with underscores: `user_handler.go`. Special suffixes: `_test.go` (excluded from production), `_linux.go` (build constraints).

### Avoid Stuttering

A name MUST NOT repeat information already present in the package name:

```go
http.Client       // not http.HTTPClient
json.Decoder      // not json.JSONDecoder
user.New()        // not user.NewUser()
```

### Frequently Missed Conventions

- **Constructor naming**: single primary type in a package uses `New()`, not `NewTypeName()`. Use `NewTypeName()` only when a package has multiple constructible types.
- **Boolean struct fields**: unexported booleans MUST use `is`/`has`/`can` prefix — `isConnected`, not `connected`.
- **Error strings are fully lowercase** — including acronyms. `"invalid message id"` not `"invalid message ID"`. Sentinel errors include the package name: `errors.New("apiclient: not found")`.
- **Enum zero values**: always place `Unknown`/`Invalid` sentinel at iota position 0.
- **Name length matches scope**: `i` is fine for a 3-line loop, `userIndex` is noise.

### Common Naming Mistakes

| Mistake | Fix |
| --- | --- |
| `ALL_CAPS` constants | Use `MixedCaps` (`MaxRetries`) |
| `GetName()` getter | Go omits `Get` — use `Name()`. Keep `Is`/`Has`/`Can` for booleans |
| `Url`, `Http` acronyms | All caps or all lower: `URL`, `HTTPServer` |
| `this` or `self` receiver | Use 1-2 letter abbreviation (`s` for `Server`) |
| `util`, `helper` packages | Use specific names that describe the abstraction |
| Inconsistent receiver names | Use one name consistently across all methods |

---

## Structs & Interfaces

### Interface Design

Interfaces SHOULD have 1-3 methods. Compose larger ones from smaller ones:

```go
type Reader interface { Read(p []byte) (n int, err error) }
type Writer interface { Write(p []byte) (n int, err error) }
type ReadWriter interface { Reader; Writer }
```

Interfaces MUST be defined where consumed, not where implemented. Accept interfaces, return structs:

```go
func NewService(store UserStore) *Service  // good
func NewService(store UserStore) ServiceInterface  // bad — never return interfaces
```

NEVER create interfaces prematurely — wait for 2+ implementations or a testability requirement. Start concrete, extract later.

### Make the Zero Value Useful

Design structs so `var x MyType` is safe. Use lazy initialization for map/slice fields:

```go
func (r *Registry) Register(name string, item Item) {
    if r.items == nil {
        r.items = make(map[string]Item)
    }
    r.items[name] = item
}
```

### Key Standard Library Interfaces

| Interface | Package | Method |
| --- | --- | --- |
| `Reader` | `io` | `Read(p []byte) (n int, err error)` |
| `Writer` | `io` | `Write(p []byte) (n int, err error)` |
| `Closer` | `io` | `Close() error` |
| `Stringer` | `fmt` | `String() string` |
| `error` | builtin | `Error() string` |
| `Handler` | `net/http` | `ServeHTTP(ResponseWriter, *Request)` |

Canonical method signatures MUST be honored — don't invent `ToString()` or `ReadData()`.

### Compile-Time Interface Check

```go
var _ io.ReadWriter = (*MyBuffer)(nil)
```

Place near the type definition. Zero runtime cost — build fails if `MyBuffer` stops satisfying the interface.

### Type Assertions & Type Switches

Type assertions MUST use the comma-ok form:

```go
s, ok := val.(string)
if !ok { /* handle */ }
```

Use type switches for branching on dynamic type:

```go
switch v := val.(type) {
case string:
    fmt.Println(v)
case int:
    fmt.Println(v * 2)
default:
    fmt.Printf("unexpected type %T\n", v)
}
```

### Optional Behavior with Type Assertions

Check if a value supports additional capabilities without requiring them upfront:

```go
func writeData(w io.Writer, data []byte) error {
    if _, err := w.Write(data); err != nil {
        return err
    }
    if f, ok := w.(interface{ Flush() error }); ok {
        return f.Flush()
    }
    return nil
}
```

This pattern is used extensively in the standard library (e.g., `http.Flusher`, `io.ReaderFrom`).

### Struct & Interface Embedding

Embedding promotes the inner type's methods and fields — composition, not inheritance:

```go
type Server struct {
    http.Handler  // embed — promotes ServeHTTP
    store *DataStore  // named field — doesn't expose store methods
}
```

Embed when the outer type "is a" enhanced version. Use a named field when the outer type "has a" dependency.

### Struct Field Tags

Exported fields in serialized structs MUST have field tags:

```go
type Order struct {
    ID        string    `json:"id"         db:"id"`
    UserID    string    `json:"user_id"    db:"user_id"`
    Total     float64   `json:"total"      db:"total"`
    CreatedAt time.Time `json:"created_at" db:"created_at"`
    Internal  string    `json:"-"          db:"-"`
}
```

### Pointer vs Value Receivers

| Use pointer `(s *Server)` | Use value `(s Server)` |
| --- | --- |
| Method modifies the receiver | Receiver is small and immutable |
| Receiver contains `sync.Mutex` or similar | Receiver is a basic type |
| Receiver is a large struct | Method is a read-only accessor |
| Consistency: if any method uses pointer, all should | |

Receiver type MUST be consistent across all methods of a type.

### Preventing Struct Copies with `noCopy`

Structs containing a mutex, channel, or internal pointers must never be copied. Embed a `noCopy` sentinel so `go vet` catches it:

```go
type noCopy struct{}
func (*noCopy) Lock()   {}
func (*noCopy) Unlock() {}

type ConnPool struct {
    noCopy noCopy
    mu     sync.Mutex
    conns  []*Conn
}
```

Always pass these structs by pointer — `go vet` flags value copies.

### Dependency Injection via Interfaces

Accept dependencies as interfaces in constructors:

```go
type UserStore interface {
    FindByID(ctx context.Context, id string) (*User, error)
}

type UserService struct { store UserStore }

func NewUserService(store UserStore) *UserService {
    return &UserService{store: store}
}
```

In tests, pass a mock that satisfies `UserStore` — no real database needed.

---

## Data Structures

### Slices

A slice is a 3-word header: pointer to backing array, length, capacity.

- Preallocate with `make([]T, 0, n)` when size is known — avoids repeated growth copies
- Growth: doubles under 256 elements, ~25% above that. Each growth copies everything — O(n)
- NEVER rely on capacity growth timing — the algorithm may change between Go versions
- `append` may reuse the backing array if capacity allows — both slices share memory silently. Force a new allocation with `append(s[:len(s):len(s)], elem)`
- Sub-slicing keeps the entire original array alive for GC. Use `slices.Clone(s[2:4])` to detach
- Nil slice and empty slice behave the same for `len`/`range`/`append` but differ in JSON (`null` vs `[]`)

`slices` package (Go 1.21+):

| Category | Key Functions |
| --- | --- |
| Sort | `Sort`, `SortFunc`, `SortStableFunc`, `IsSorted` |
| Search | `BinarySearch`, `BinarySearchFunc`, `Contains`, `Index` |
| Mutate | `Insert`, `Delete`, `Replace`, `Compact`, `Reverse`, `Grow`, `Clip` |
| Create | `Concat` (1.22+), `Repeat` (1.23+), `Chunk` (1.23+) |
| Compare | `Clone`, `Equal`, `EqualFunc`, `Compare`, `DeleteFunc` |

Copy operations:

| Operation | Use When |
| --- | --- |
| `copy(dst, src)` | Copying into pre-allocated slice |
| `append(dst, src...)` | Appending to a slice |
| `slices.Clone(s)` | Creating independent copy |
| `s[:len(s):len(s)]` | Preventing append aliasing |

### Maps

Hash tables with 8-entry buckets and overflow chains. Reference types — assigning copies the pointer, not the data.

- Keys must be comparable (`==` must work) — no slices, maps, or functions as keys
- Iteration order is intentionally randomized
- NOT safe for concurrent access — concurrent read+write is a hard crash. Use `sync.RWMutex` or `sync.Map`
- Never shrinks — `delete` marks entries empty but memory stays. Create a new map to reclaim
- Reading a missing key returns zero value silently — use comma-ok: `v, ok := m[key]`
- `delete(m, key)` is safe on missing keys and nil maps
- Preallocate: `make(map[K]V, n)` avoids rehashing during population

`maps` package (Go 1.21+): `Keys`, `Values`, `Clone`, `Equal`, `Collect` (1.23+).

### Arrays

Fixed-size value types — `[5]int` and `[6]int` are different types. Copied entirely on assignment. Use only for fixed, compile-time-known sizes (hash digests, coordinates as map keys). Use slices for everything else.

### Standard Library Containers

| Package | Data Structure | Best For |
| --- | --- | --- |
| `container/heap` | Min-heap (priority queue) | Top-K, scheduling |
| `container/list` | Doubly-linked list | LRU caches, frequent middle insertion |
| `container/ring` | Circular buffer | Rolling windows, round-robin |

### strings.Builder vs bytes.Buffer

Use `strings.Builder` for building strings (avoids copy on `String()`). Use `bytes.Buffer` when you need `io.Reader` or byte manipulation.

### Generic Collections (Go 1.18+)

Use the tightest constraint possible — `comparable` for keys, `cmp.Ordered` for sorting:

```go
type Set[T comparable] map[T]struct{}
func (s Set[T]) Add(v T)           { s[v] = struct{}{} }
func (s Set[T]) Contains(v T) bool { _, ok := s[v]; return ok }
```

### Pointer Types

| Type | Use Case | Zero Value |
| --- | --- | --- |
| `*T` | Normal indirection, mutation, optional values | `nil` |
| `unsafe.Pointer` | FFI, low-level memory layout (6 spec patterns only) | `nil` |
| `weak.Pointer[T]` (1.24+) | Caches, canonicalization, weak references | N/A |

`unsafe.Pointer` MUST only follow the 6 valid conversion patterns from the Go spec — NEVER store in a `uintptr` variable across statements (GC can move the object between statements).

### Third-Party Data Structure Libraries

For advanced structures beyond stdlib:
- `emirpasic/gods` — trees, sets, lists, stacks, maps, queues
- `deckarep/golang-set` — thread-safe and non-thread-safe sets
- `gammazero/deque` — fast double-ended queue

### Copy Semantics

| Type | Copy Behavior | Independence |
| --- | --- | --- |
| `int`, `float`, `bool`, `string` | Value (deep copy) | Fully independent |
| `array`, `struct` | Value (deep copy) | Fully independent |
| `slice` | Header copied, backing array shared | Use `slices.Clone` |
| `map` | Reference copied | Use `maps.Clone` |
| `channel` | Reference copied | Same channel |
| `*T` (pointer) | Address copied | Same underlying value |
| `interface` | Value copied (type + value pair) | Depends on held type |

---

## Design Patterns

### Functional Options (Preferred Constructor Pattern)

Functional options MUST return an error if validation can fail — catch bad config at construction, not at runtime.

```go
type Option func(*Server)

func WithReadTimeout(d time.Duration) Option {
    return func(s *Server) { s.readTimeout = d }
}

func NewServer(addr string, opts ...Option) *Server {
    s := &Server{
        addr:        addr,
        readTimeout: 5 * time.Second,
        maxConns:    100,
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}
```

### Avoid `init()` and Mutable Globals

`init()` runs implicitly, cannot return errors, and makes testing unpredictable. Use explicit constructors:

```go
// Bad — hidden global state
var db *sql.DB
func init() {
    db, _ = sql.Open("postgres", os.Getenv("DATABASE_URL"))
}

// Good — explicit, injectable
func NewUserRepository(db *sql.DB) *UserRepository {
    return &UserRepository{db: db}
}
```

### Enums

Zero values should represent invalid/unset state:

```go
const (
    StatusUnknown Status = iota // 0 = invalid/unset
    StatusActive                // 1
    StatusInactive              // 2
)
```

### When to Panic vs Return Error

- **Return error**: network failures, file not found, invalid input — anything a caller can handle
- **Panic**: violated invariant, `Must*` constructors used at init time
- **`.Close()` errors**: acceptable to not check — `defer f.Close()` is fine

### Resource Management

`defer Close()` immediately after opening:

```go
f, err := os.Open(path)
if err != nil { return err }
defer f.Close()
```

### Resilience

- Every external call SHOULD have a timeout via `context.WithTimeout`
- Limit everything — pool sizes, queue depths, buffers
- Retry logic MUST check `ctx.Err()` between attempts
- Compile regexp once at package level: `var re = regexp.MustCompile(...)`
- Use `crypto/rand` for keys/tokens — `math/rand` is predictable
- Use `//go:embed` for static assets
- Prefer `runtime.AddCleanup` over `runtime.SetFinalizer` (Go 1.24+) — no resurrection risk, supports cycles

### Graceful Shutdown

Use `signal.NotifyContext` for clean termination:

```go
func main() {
    ctx, stop := signal.NotifyContext(context.Background(),
        syscall.SIGINT, syscall.SIGTERM,
    )
    defer stop()

    srv := &http.Server{Addr: ":8080", Handler: router}
    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Error("server error", "error", err)
        }
    }()

    <-ctx.Done()

    shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    srv.Shutdown(shutdownCtx)
    db.Close()
}
```

### Data Types

| Type | Use when |
| --- | --- |
| `string` | Immutable, display, map keys |
| `[]byte` | I/O, mutations, building strings |
| `[]rune` | `len()` must mean characters, not bytes |

Avoid repeated conversions — each one allocates.

### Architecture Principles

- Keep domain pure — no framework dependencies in the domain layer
- Fail fast — validate at boundaries, trust internal code
- Make illegal states unrepresentable — use types to enforce invariants
- A little recode > a big dependency
- Design for testability — accept interfaces, inject dependencies

---

## Common Mistakes

| Mistake | Fix |
| --- | --- |
| Large interfaces (5+ methods) | Split into 1-3 method interfaces, compose if needed |
| Defining interfaces in the implementor package | Define where consumed |
| Returning interfaces from constructors | Return concrete types |
| Bare type assertions without comma-ok | Always use `v, ok := x.(T)` |
| Missing field tags on serialized structs | Tag all exported fields |
| Mixing pointer and value receivers | Pick one, be consistent |
| Premature interface with single implementation | Start concrete, extract when needed |
| Growing slice in loop without preallocation | Use `make([]T, 0, n)` |
| `bytes.Buffer` for pure string building | Use `strings.Builder` |
| Using `any` for type-safe operations | Use generics |
| `container/list` when a slice would suffice | Benchmark first — slices have better cache locality |
