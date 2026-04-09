---
name: go-reliability
description: Go error handling, safety, concurrency, context, testing, and troubleshooting. TRIGGER when writing Go code that involves error handling, goroutines, channels, context propagation, or tests.
---

# Go Reliability

Error handling, safety, concurrency, context, testing, and troubleshooting for robust Go code.

## Error Handling

### Core Rules

1. Returned errors MUST always be checked — NEVER discard with `_`
2. Errors MUST be wrapped with context: `fmt.Errorf("{context}: %w", err)`
3. Error strings MUST be lowercase, without trailing punctuation
4. Use `%w` internally, `%v` at system boundaries to control chain exposure
5. MUST use `errors.Is` and `errors.As` instead of direct comparison or type assertion
6. Errors MUST be either logged OR returned, NEVER both (single handling rule)
7. NEVER use `panic` for expected error conditions
8. Never expose technical errors to users — translate to user-friendly messages, log details separately

### Error Creation

```go
// Sentinel errors — for expected conditions callers need to match
var ErrNotFound = errors.New("not found")
var ErrUnauthorized = errors.New("unauthorized")

// Custom error types — when callers need structured data
type ValidationError struct {
    Field   string
    Message string
}
func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed on %s: %s", e.Field, e.Message)
}

// Custom types that wrap other errors — implement Unwrap()
type QueryError struct {
    Query string
    Err   error
}
func (e *QueryError) Error() string   { return fmt.Sprintf("query %q: %v", e.Query, e.Err) }
func (e *QueryError) Unwrap() error   { return e.Err }
```

| Situation | Strategy |
| --- | --- |
| Caller needs to match a specific condition | Sentinel error (`errors.New` as package var) |
| Caller needs to extract structured data | Custom error type |
| Error is purely informational | `fmt.Errorf` or `errors.New` |

### Error Wrapping

Wrap at each layer to build a readable chain: `creating order: charging card: connection refused`

```go
// Internal — wrap to preserve chain
return fmt.Errorf("querying database: %w", err)

// Public API boundary — break chain to hide internals
return fmt.Errorf("item unavailable: %v", err)  // %v — callers cannot unwrap
```

### Error Inspection

```go
// errors.Is — match sentinel values (traverses entire chain)
if errors.Is(err, sql.ErrNoRows) {
    return nil, ErrNotFound
}

// errors.As — extract typed errors from chain
var ve *ValidationError
if errors.As(err, &ve) {
    log.Printf("validation failed on field %s", ve.Field)
}

// errors.Join — combine independent errors (Go 1.20+)
func validateUser(u User) error {
    var errs []error
    if u.Name == "" { errs = append(errs, errors.New("name is required")) }
    if u.Email == "" { errs = append(errs, errors.New("email is required")) }
    return errors.Join(errs...)  // nil if empty; works with errors.Is/As
}
```

### Low-Cardinality Error Messages

Don't interpolate variable data (IDs, paths) into error strings — APM tools group by message. Static wrapping prefixes are fine.

```go
// Bad — each user/path combo creates a unique error message
return fmt.Errorf("user %s not found in %s", userID, path)

// Good — static message, attach variable data as structured log attributes
err := errors.New("user not found")
slog.Error("lookup failed", "error", err, "user_id", userID, "path", path)
```

---

## Safety

### Nil Safety

**The nil interface trap** — an interface holding a typed nil pointer is not `== nil`:

```go
// Bad — interface{type: *MyHandler, value: nil} != nil
func getHandler() http.Handler {
    var h *MyHandler
    if !enabled { return h }  // NOT nil!
    return h
}

// Good — return nil explicitly
func getHandler() http.Handler {
    if !enabled { return nil }
    return &MyHandler{}
}
```

**Nil behavior table:**

| Type | Read from nil | Write to nil | Len/Cap | Range |
| --- | --- | --- | --- | --- |
| Map | Zero value | **panic** | 0 | 0 iterations |
| Slice | **panic** (index) | **panic** (index) | 0 | 0 iterations |
| Channel | Blocks forever | Blocks forever | 0 | Blocks forever |

**Nil pointer receivers** — a method call on nil doesn't always panic (only if it dereferences the receiver). But NEVER rely on this — always check for nil.

**Nil function values** — calling a nil `func` panics. Provide no-op defaults:

```go
func NewWorker(opts ...Option) *Worker {
    return &Worker{onComplete: func(string) {}}  // no-op default
}
```

**Returning nil error correctly** — return untyped `nil`, not a typed nil pointer:

```go
// Bad — var err *ValidationError; return err (non-nil interface)
// Good — return nil
```

### Slice & Map Safety

**Append aliasing** — `append` reuses backing array if capacity allows:

```go
a := make([]int, 3, 5)
b := append(a, 4)
b[0] = 99  // also modifies a[0]!

// Fix — full slice expression forces new allocation
b := append(a[:len(a):len(a)], 4)
```

**Subslice retains full backing array** — use `slices.Clone()` to detach small slices from large arrays.

**Defensive copies** — exported functions returning slices/maps SHOULD return copies:

```go
type Config struct { hosts []string }
func (c *Config) Hosts() []string { return slices.Clone(c.hosts) }
```

**Range loop variable capture** — pre-Go 1.22 all closures see the last value. Go 1.22+ fixed this with per-iteration scoping. Check your `go.mod` version.

**Deleting during iteration** — maps: safe. Slices: use `slices.DeleteFunc` or iterate backwards.

**Comparing slices/maps** — use `slices.Equal`/`maps.Equal` (Go 1.21+), never `==`.

### Numeric Safety

```go
// Integer conversion truncates silently
var val int64 = 3_000_000_000
i32 := int32(val)  // -1294967296 (silent wraparound)
// Fix: check bounds first

// Float comparison
0.1+0.2 == 0.3  // false
math.Abs((0.1+0.2)-0.3) < 1e-9  // true

// Integer division by zero panics — always guard
```

### Variable Shadowing

`:=` inside an inner scope creates a NEW variable — the outer one stays unchanged:

```go
// Bug — inner err shadows outer err, outer stays nil
var err error
if condition {
    val, err := doSomething()  // new err! outer err is still nil
    process(val)
}
return err  // always nil — the real error was in the inner scope

// Fix — pre-declare, use = not :=
var err error
var val int
if condition {
    val, err = doSomething()  // assigns to outer err
}
```

Detect with `go vet -shadow`. This is one of the most common Go bugs.

### Concurrent Map Access is Fatal

Concurrent map read+write is NOT a panic — it's a **fatal runtime crash** that cannot be caught with `recover()`:

```go
// This kills the entire process — no recovery possible
go func() { m["a"] = 1 }()
go func() { _ = m["a"] }()
```

Always protect maps with `sync.Mutex`, `sync.RWMutex`, or use `sync.Map`.

### Resource Safety

`defer` runs at **function** exit, not loop iteration. Also: defer arguments are evaluated at declaration time, not execution time:

```go
// Gotcha — i is captured at defer time
for i := range 5 {
    defer fmt.Println(i)  // prints 4,3,2,1,0 (correct — each i evaluated at defer time)
}
```

```go
// Bad — all files stay open until function returns
for _, path := range paths {
    f, _ := os.Open(path)
    defer f.Close()
}

// Good — extract to function
for _, path := range paths {
    if err := processOne(path); err != nil { return err }
}
func processOne(path string) error {
    f, err := os.Open(path)
    if err != nil { return err }
    defer f.Close()
    return process(f)
}
```

### Initialization Safety

Use `sync.Once` for lazy init under concurrency:

```go
type DB struct {
    once sync.Once
    conn *sql.DB
}
func (db *DB) connection() *sql.DB {
    db.once.Do(func() { db.conn, _ = sql.Open("postgres", connStr) })
    return db.conn
}
```

Go 1.21+: `sync.OnceValue` for simpler cases:

```go
var loadConfig = sync.OnceValue(func() *Config {
    cfg, _ := parseConfig("config.yaml")
    return cfg
})
```

---

## Concurrency

### Core Principles

1. Every goroutine MUST have a clear exit — context, done channel, or WaitGroup
2. Only the sender closes a channel — closing from receiver panics
3. Send copies, not pointers on channels
4. Specify channel direction (`chan<-`, `<-chan`) in function signatures
5. Default to unbuffered channels — buffers mask backpressure
6. Always include `ctx.Done()` in select — prevents goroutine leaks
7. Never use `time.After` in loops — leaks timers. Use `time.NewTimer` + `Reset`
8. Track goroutine leaks in tests with `go.uber.org/goleak`

### Goroutine Lifecycle

```go
// Bad — fire-and-forget, leaks on shutdown
go func() { for { doWork() } }()

// Good — respects cancellation, caller can wait
func startWorker(ctx context.Context) *sync.WaitGroup {
    var wg sync.WaitGroup
    wg.Add(1)
    go func() {
        defer wg.Done()
        for {
            select {
            case <-ctx.Done():
                return
            default:
                doWork(ctx)
            }
        }
    }()
    return &wg
}
```

**Panic recovery at goroutine boundaries** — a panic in a goroutine crashes the entire process:

```go
go func() {
    defer func() {
        if r := recover(); r != nil { /* log */ }
    }()
    doWork(ctx)
}()
```

### Channel vs Mutex vs Atomic

| Scenario | Use |
| --- | --- |
| Passing data between goroutines | Channel |
| Coordinating goroutine lifecycle | Channel + context |
| Protecting shared struct fields | `sync.Mutex` / `sync.RWMutex` |
| Simple counters, flags | `sync/atomic` (typed: `atomic.Int64`, `atomic.Bool`) |
| Read-heavy concurrent map | `sync.Map` |
| Caching expensive computations | `sync.Once` / `singleflight` |

### Channel Patterns

**Buffer sizes:**

| Size | When |
| --- | --- |
| 0 (unbuffered) | Default. Synchronizes sender and receiver |
| 1 | Signal channels, sender must not block on single pending item |
| N > 1 | Only with measured justification — document why |

**Select with context:**

```go
func process(ctx context.Context, in <-chan Task, out chan<- Result) {
    for {
        select {
        case <-ctx.Done():
            return
        case task, ok := <-in:
            if !ok { return }
            select {
            case out <- handle(ctx, task):
            case <-ctx.Done():
                return
            }
        }
    }
}
```

**Timer reuse in loops:**

```go
// Bad — time.After leaks a timer every iteration
case <-time.After(5 * time.Second):

// Good — reuse timer
timer := time.NewTimer(5 * time.Second)
defer timer.Stop()
// ... Reset after each use
```

### Sync Primitives

| Primitive | Use case | Key notes |
| --- | --- | --- |
| `sync.Mutex` | Protect shared state | Keep critical sections short; never hold across I/O |
| `sync.RWMutex` | Many readers, few writers | Never upgrade RLock to Lock (deadlock) |
| `sync/atomic` | Simple counters, flags | Go 1.19+: typed `atomic.Int64`, `atomic.Bool` |
| `sync.Map` | Concurrent map, read-heavy | No locking; use `RWMutex`+map when writes dominate |
| `sync.Pool` | Reuse temporary objects | Always `Reset()` before `Put()`; GC can reclaim anytime |
| `sync.Once` | One-time initialization | Go 1.21+: `OnceFunc`, `OnceValue`, `OnceValues` |
| `sync.WaitGroup` | Wait for goroutines | `Add` before `go`; Go 1.24+: `wg.Go()` |
| `singleflight` | Deduplicate concurrent calls | Cache stampede prevention |
| `errgroup` | Goroutine group + errors | `SetLimit(n)` replaces hand-rolled worker pools |

**Mutex example:**

```go
type SafeCache struct {
    mu    sync.Mutex  // protects items
    items map[string]string
}
func (c *SafeCache) Get(key string) (string, bool) {
    c.mu.Lock()
    defer c.mu.Unlock()
    v, ok := c.items[key]
    return v, ok
}
```

**errgroup with bounded concurrency:**

```go
g, ctx := errgroup.WithContext(ctx)
g.SetLimit(10)
for _, task := range tasks {
    g.Go(func() error { return process(ctx, task) })
}
return g.Wait()
```

**singleflight for deduplication:**

```go
var group singleflight.Group
func GetUser(ctx context.Context, id string) (*User, error) {
    v, err, _ := group.Do(id, func() (any, error) {
        return db.QueryUser(ctx, id)
    })
    if err != nil { return nil, err }
    return v.(*User), nil
}
```

### Concurrency Checklist

Before spawning a goroutine:
- How will it exit? (context, channel close, signal)
- Can I signal it to stop? (`context.Context` or done channel)
- Can I wait for it? (`WaitGroup` or `errgroup`)
- Who owns the channels? (creator/sender owns and closes)
- Should this be synchronous instead?

---

## Context

### Core Rules

1. Propagate the same context through the entire request lifecycle
2. `ctx` MUST be the first parameter, named `ctx context.Context`
3. NEVER store context in a struct — pass through function parameters
4. NEVER pass `nil` context — use `context.TODO()` if unsure
5. `cancel()` MUST always be deferred immediately after creation
6. `context.Background()` only at top level (main, init, tests)
7. Context values MUST only carry request-scoped metadata, NEVER function parameters
8. Context value keys MUST be unexported types

### Creating Contexts

| Situation | Use |
| --- | --- |
| Entry point | `context.Background()` |
| Placeholder | `context.TODO()` |
| HTTP handler | `r.Context()` |
| Cancellation | `context.WithCancel(parentCtx)` |
| Timeout | `context.WithTimeout(parentCtx, duration)` |
| Absolute deadline | `context.WithDeadline(parentCtx, time)` |

### Propagation

```go
// Bad — breaks the chain
func (s *OrderService) Create(ctx context.Context, order Order) error {
    return s.db.ExecContext(context.Background(), "INSERT ...", order.ID)
}

// Good — propagates caller's context
func (s *OrderService) Create(ctx context.Context, order Order) error {
    return s.db.ExecContext(ctx, "INSERT ...", order.ID)
}
```

### Cancellation and Timeouts

Every `WithCancel`/`WithTimeout`/`WithDeadline` allocates resources — always `defer cancel()`:

```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()
return doWork(ctx)
```

Nested timeouts take the shorter deadline — a child with 10s timeout under a parent with 2s still expires at 2s.

**Listening for cancellation:**

```go
select {
case <-ctx.Done():
    return ctx.Err()  // context.Canceled or context.DeadlineExceeded
case <-ticker.C:
    doWork(ctx)
}
```

For CPU-bound loops, periodically check `ctx.Err()`.

### Advanced Context Patterns

**`context.WithoutCancel`** (Go 1.21+) — for background work that must outlive the request (audit logs, async tasks). Preserves values (trace_id) but detaches cancellation.

**`context.AfterFunc`** (Go 1.21+) — registers cleanup callback that runs when context is cancelled.

---

## Testing

### Core Rules

1. Table-driven tests MUST use named subtests via `t.Run`
2. Integration tests MUST use build tags (`//go:build integration`)
3. Tests MUST NOT depend on execution order
4. NEVER test implementation details — test observable behavior
5. Mock interfaces, not concrete types
6. Keep unit tests fast (< 1ms)
7. Run tests with `-race` in CI

### Table-Driven Tests

```go
func TestCalculatePrice(t *testing.T) {
    tests := []struct {
        name     string
        quantity int
        price    float64
        expected float64
    }{
        {"single item", 1, 10.0, 10.0},
        {"bulk discount", 100, 10.0, 900.0},
        {"zero quantity", 0, 10.0, 0.0},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := CalculatePrice(tt.quantity, tt.price)
            if got != tt.expected {
                t.Errorf("got %.2f, want %.2f", got, tt.expected)
            }
        })
    }
}
```

### Test File Conventions

```go
package mypackage      // white-box, access unexported
package mypackage_test // black-box, public API only
```

### Goroutine Leak Detection

```go
func TestMain(m *testing.M) {
    goleak.VerifyTestMain(m)
}
```

### Integration Tests

```go
//go:build integration

func TestDatabaseIntegration(t *testing.T) {
    db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil { t.Fatal(err) }
    defer db.Close()
}
```

Run separately: `go test -tags=integration ./...`

### Parallel Tests

```go
t.Run(tt.name, func(t *testing.T) {
    t.Parallel()
    // ...
})
```

### Fuzzing

```go
func FuzzReverse(f *testing.F) {
    f.Add("hello")
    f.Fuzz(func(t *testing.T, input string) {
        if Reverse(Reverse(input)) != input {
            t.Errorf("double reverse failed for %q", input)
        }
    })
}
```

### Debugging Flaky Tests

Common causes: shared mutable state, test order dependence, timing sensitivity, port conflicts. Diagnostic flags:

```bash
go test -shuffle=on ./...     # randomize order — catch order-dependent tests
go test -count=100 ./...      # repeat to find intermittent failures
go test -parallel 1 ./...     # serialize — isolate concurrency issues
```

### Quick Reference

```bash
go test ./...                       # all tests
go test -run TestName ./...         # specific test
go test -run TestName/subtest ./... # subtest
go test -race ./...                 # race detection
go test -cover ./...                # coverage
go test -bench=. -benchmem ./...    # benchmarks
go test -fuzz=FuzzName ./...        # fuzzing
go test -tags=integration ./...     # integration tests
go test -count=10 ./...             # repeat (find flaky tests)
```

---

## Troubleshooting

### Golden Rules

1. **Read the error message first** — file/line, type mismatch, "undefined", "cannot use X as Y"
2. **Reproduce before you fix** — write a failing test, make it deterministic, use `git bisect`
3. **One hypothesis at a time** — change one thing, measure, confirm
4. **Find the root cause** — no band-aid fixes. Trace data flow backwards, question assumptions, ask "why" five times
5. **Research the codebase** — trace callers, check upstream validation, read surrounding code
6. **Start simple** — `fmt.Println` first, escalate to pprof/Delve only when needed
7. **Never propose a fix you cannot explain**

### Decision Tree

| Symptom | First step |
| --- | --- |
| Build won't compile | `go build ./... 2>&1`, `go vet ./...` |
| Wrong output / logic bug | Write a failing test |
| Random crashes / panics | `GOTRACEBACK=all ./app`, `go test -race` |
| Sometimes works, sometimes fails | `go test -race ./...` |
| Program hangs | `curl localhost:6060/debug/pprof/goroutine?debug=2` |
| High CPU | pprof CPU profiling |
| Memory growing | pprof heap profiling |
| Slow / high latency | CPU + mutex + block profiles |

Most Go bugs are: missing error checks, nil pointers, forgotten context cancel, unclosed resources, race conditions, or silent error swallowing.

### Red Flags — You're Debugging Wrong

- "Quick fix for now, investigate later" — there is no later
- Multiple simultaneous changes — one hypothesis at a time
- Proposing fixes without understanding the cause
- Each fix reveals a new problem — real bug is elsewhere
- 3+ attempts on the same issue — wrong mental model, start over
- Blaming the framework/stdlib — it's almost never a Go bug

### HTTP Client Rules

1. ALL HTTP clients MUST use `http.NewRequestWithContext(ctx, ...)` — never `http.NewRequest`
2. Always `defer resp.Body.Close()` after checking err
3. Always set timeouts on `http.Client` — default has no timeout
4. Read and discard body even on error status (enables connection reuse)

```go
req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
if err != nil { return err }
resp, err := client.Do(req)
if err != nil { return err }
defer resp.Body.Close()
```

### pprof in Production

Enable via environment variable, protect with auth:

```go
if os.Getenv("PPROF_ENABLED") == "true" {
    go func() {
        mux := http.NewServeMux()
        mux.HandleFunc("/debug/pprof/", pprof.Index)
        http.ListenAndServe("localhost:6060", mux)
    }()
}
```

Capture remotely: `go tool pprof http://host:6060/debug/pprof/heap`

### Code Review Red Flags

Watch for these patterns — each signals a potential bug:
- Error discarded with `_` or unchecked
- `go func()` without context or shutdown mechanism
- No `defer close` after opening a resource
- `time.After` inside a loop
- Map accessed from multiple goroutines without sync
- `:=` inside if/for that shadows an outer variable
- `context.Background()` in the middle of a request path
- Channel never closed (goroutine leak)
- Named return + defer interaction (confusing control flow)
- `reflect.DeepEqual` in production code (50-200x slower)

---

## Common Mistakes

| Mistake | Fix |
| --- | --- |
| Discarding errors with `_` | Always check returned errors |
| `err == sql.ErrNoRows` | Use `errors.Is(err, sql.ErrNoRows)` — traverses wrapped chains |
| Log AND return error | Either log OR return, never both |
| Bare type assertion `v := x.(T)` | Use `v, ok := x.(T)` |
| Returning typed nil in interface | Return untyped `nil` for the nil case |
| Writing to nil map | Initialize with `make()` or lazy-init |
| `append` assuming it always copies | Use `s[:len(s):len(s)]` to force new allocation |
| `defer` in a loop | Extract loop body to separate function |
| `int64` to `int32` without bounds check | Check against `math.MaxInt32` first |
| Fire-and-forget goroutine | Provide stop mechanism (context, done channel) |
| Closing channel from receiver | Only sender closes |
| `time.After` in loop | Reuse `time.NewTimer` + `Reset` |
| Missing `ctx.Done()` in select | Always select on context for cancellation |
| `wg.Add` inside goroutine | Call `Add` before `go` |
| `context.Background()` mid-request | Propagate the caller's context |
| Storing context in a struct | Pass through function parameters |
| Forgetting `defer cancel()` | Always defer immediately after WithCancel/WithTimeout |
| Variable shadowing with `:=` | Pre-declare variables, use `=` not `:=` in inner scopes |
| Concurrent map read/write | Fatal crash (not panic) — always use mutex or sync.Map |
| `http.NewRequest` without context | Use `http.NewRequestWithContext(ctx, ...)` |
| HTTP client without timeout | Set timeouts on `http.Client` — default is infinite |
