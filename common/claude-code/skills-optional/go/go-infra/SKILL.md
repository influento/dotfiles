---
name: go-infra
description: Go database (PostgreSQL/pgx), security, performance, and benchmarking. TRIGGER when writing Go code that involves database queries, SQL, connection pools, security, or performance optimization.
---

# Go Infrastructure

Database (PostgreSQL/pgx), security, performance, and benchmarking for production Go services.

## Database (PostgreSQL with pgx)

### Core Rules

1. Use pgx, not ORMs — ORMs hide SQL, generate unpredictable queries, and make debugging harder
2. Queries MUST use parameterized placeholders (`$1`, `$2`) — NEVER concatenate user input into SQL
3. Context MUST be passed to all database operations — use `QueryContext`, `ExecContext`
4. `pgx.ErrNoRows` MUST be handled explicitly — distinguish "not found" from real errors with `errors.Is`
5. Rows MUST be closed after iteration — `defer rows.Close()` immediately
6. NEVER use `Query` for statements that don't return rows — use `Exec` (Query returns Rows that must be closed)
7. Use transactions for multi-statement operations
8. Use `SELECT ... FOR UPDATE` when reading data you intend to modify
9. Handle NULLable columns with pointer fields (`*string`, `*time.Time`)
10. Connection pool MUST be configured
11. Use external tools for migrations (golang-migrate, Atlas) — never AI-generated migration SQL
12. Never create or modify database schemas — requires human review with production context
13. Avoid triggers, views, stored procedures — keep SQL explicit in Go code

### Parameterized Queries

```go
// NEVER do this — SQL injection
query := fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email)

// Always parameterize
row := pool.QueryRow(ctx, "SELECT id, name, email FROM users WHERE email = $1", email)
```

**Dynamic column names** — use an allowlist, never interpolate from user input:

```go
allowed := map[string]bool{"name": true, "email": true, "created_at": true}
if !allowed[sortCol] {
    return fmt.Errorf("invalid sort column: %s", sortCol)
}
query := fmt.Sprintf("SELECT id, name FROM users ORDER BY %s", sortCol)
```

### Struct Scanning with pgx

```go
rows, err := pool.Query(ctx, "SELECT id, name, email FROM users WHERE active = true")
if err != nil {
    return fmt.Errorf("querying users: %w", err)
}
users, err := pgx.CollectRows(rows, pgx.RowToStructByName[User])
```

### NULLable Columns

Use pointer fields (recommended) — clean, works with JSON marshaling:

```go
type User struct {
    ID        int64      `db:"id"         json:"id"`
    Name      string     `db:"name"       json:"name"`
    Bio       *string    `db:"bio"        json:"bio,omitempty"`  // nil when NULL
    DeletedAt *time.Time `db:"deleted_at" json:"deleted_at"`     // nil when NULL
}
```

### Error Handling

```go
func GetUser(ctx context.Context, pool *pgxpool.Pool, id string) (*User, error) {
    var user User
    err := pool.QueryRow(ctx, "SELECT id, name FROM users WHERE id = $1", id).Scan(&user.ID, &user.Name)
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return nil, ErrUserNotFound
        }
        return nil, fmt.Errorf("querying user %s: %w", id, err)
    }
    return &user, nil
}
```

**Always close rows and check rows.Err():**

```go
rows, err := pool.Query(ctx, "SELECT id, name FROM users")
if err != nil { return fmt.Errorf("querying users: %w", err) }
defer rows.Close()

for rows.Next() { /* scan */ }
if err := rows.Err(); err != nil {
    return fmt.Errorf("iterating users: %w", err)
}
```

**Common database error patterns:**

| Error | Detection | Action |
| --- | --- | --- |
| Row not found | `errors.Is(err, pgx.ErrNoRows)` | Return domain error |
| Unique constraint | Check PostgreSQL error code | Return conflict error |
| Connection refused | `err != nil` on `pool.Ping` | Fail fast, retry with backoff |
| Serialization failure | PostgreSQL error code `40001` | Retry entire transaction |
| Context canceled | `errors.Is(err, context.Canceled)` | Stop, propagate |

### Transactions

```go
tx, err := pool.Begin(ctx)
if err != nil { return fmt.Errorf("beginning transaction: %w", err) }
defer tx.Rollback(ctx)  // no-op if committed

// ... execute queries using tx ...

if err := tx.Commit(ctx); err != nil {
    return fmt.Errorf("committing: %w", err)
}
```

**Isolation levels:**

| Level | Use when |
| --- | --- |
| Read Committed | Default — good for most operations |
| Repeatable Read | Need consistent reads within a transaction |
| Serializable | Financial ops, inventory, strict consistency |

**SELECT FOR UPDATE:**

```go
var balance int
err := tx.QueryRow(ctx, "SELECT balance FROM accounts WHERE id = $1 FOR UPDATE", id).Scan(&balance)
// Row locked until tx.Commit() or tx.Rollback()
```

| Clause | Effect |
| --- | --- |
| `FOR UPDATE` | Locks rows — other transactions block |
| `FOR UPDATE NOWAIT` | Fails immediately instead of waiting |
| `FOR SHARE` | Prevents writes, allows reads |

### Connection Pool

```go
config, _ := pgxpool.ParseConfig(dsn)
config.MaxConns = 25
config.MinConns = 5
config.MaxConnLifetime = 5 * time.Minute
config.MaxConnIdleTime = 1 * time.Minute
pool, _ := pgxpool.NewWithConfig(ctx, config)
```

Monitor pool stats in production — if `AcquireCount` keeps climbing without `AcquiredConns` dropping, the pool is exhausted.

### Batch Processing

Avoid row-by-row (N round trips) and one giant batch (locks, memory). Sweet spot: 100-1,000 rows.

**pgx COPY protocol** (fastest for bulk inserts):

```go
rows := make([][]any, len(users))
for i, u := range users {
    rows[i] = []any{u.Name, u.Email}
}
_, err := pool.CopyFrom(ctx,
    pgx.Identifier{"users"},
    []string{"name", "email"},
    pgx.CopyFromRows(rows),
)
```

**Cursor-based pagination** (never use OFFSET for large datasets):

```go
// Bad — OFFSET re-scans rows, O(offset + limit)
SELECT * FROM events ORDER BY created_at LIMIT 100 OFFSET 10000

// Good — cursor-based, O(limit) regardless of depth
SELECT * FROM events WHERE created_at > $1 ORDER BY created_at LIMIT 100
```

### Indexing Guidelines

Never create or drop indexes yourself — suggest to the developer.

**When to suggest adding:** foreign key columns (PostgreSQL does NOT auto-index FKs), columns in `WHERE`/`JOIN`/`ORDER BY`, composite indexes (leftmost column most selective), partial indexes for filtered queries.

**When to suggest removing:** near-zero `idx_scan` count, duplicates, write-heavy tables where indexes slow INSERT/UPDATE.

Check existing indexes: `SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'mytable';`

### Query Tips

- `EXPLAIN ANALYZE` before optimizing — measure, don't guess
- List columns explicitly — avoid `SELECT *`
- Prefer `EXISTS` over `COUNT` for existence checks
- Avoid N+1 queries — use `JOIN` or batch `WHERE id IN (...)`

---

## Security

### Security Thinking Model

Before writing or reviewing code:
1. **What are the trust boundaries?** — Where does untrusted data enter?
2. **What can an attacker control?** — Which inputs flow into sensitive operations?
3. **What is the blast radius?** — If this defense fails, what's the worst outcome?

### Quick Reference

| Severity | Vulnerability | Defense | Stdlib Solution |
| --- | --- | --- | --- |
| Critical | SQL Injection | Parameterized queries | pgx with `$1` placeholders |
| Critical | Command Injection | Pass args separately | `exec.Command` with separate args |
| High | XSS | Auto-escaping | `html/template` |
| High | Path Traversal | Scope file access | `os.Root` (Go 1.24+), `filepath.Clean` |
| Medium | Timing Attacks | Constant-time comparison | `crypto/subtle.ConstantTimeCompare` |
| High | Crypto Issues | Vetted algorithms | `crypto/aes` GCM, `crypto/rand` |
| Medium | Rate Limiting | Rate limits | `golang.org/x/time/rate`, server timeouts |

### Research Before Reporting

Trace the full data flow — don't assess in isolation. Check upstream validation, trust boundaries, surrounding middleware. Adjust severity based on defense layers. Add inline comments: `// security: safe here — input validated by parseID() which returns int`.

### Security Tooling

```bash
gosec ./...         # SAST security scanner
govulncheck ./...   # known vulnerability detection
go test -race ./... # race detector
go test -fuzz=Fuzz  # fuzz testing
```

### Common Security Mistakes

| Severity | Mistake | Fix |
| --- | --- | --- |
| High | `math/rand` for tokens | Use `crypto/rand` |
| Critical | SQL string concatenation | Parameterized queries |
| Critical | `exec.Command("bash", "-c", userInput)` | Pass args separately |
| Critical | Hardcoded secrets | Env vars or secret managers |
| Medium | Comparing secrets with `==` | `crypto/subtle.ConstantTimeCompare` |
| Medium | Returning detailed errors to users | Generic messages externally, log details server-side |
| High | MD5/SHA1 for passwords | Argon2id or bcrypt |
| High | AES without GCM | GCM provides encrypt+authenticate |

### Security Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Security through obscurity | Auth + authz on all endpoints |
| Trusting client headers (`X-Forwarded-For`) | Server-side identity verification |
| Client-side authorization | Server-side permission checks |
| Shared secrets across environments | Per-environment secrets |
| Ignoring crypto errors | Always check — fail closed |
| Rolling your own crypto | Use stdlib `crypto/*` |

---

## Performance

### Core Philosophy

1. **Profile before optimizing** — intuition is wrong ~80% of the time
2. **Allocation reduction yields the biggest ROI** — Go's GC is fast but not free
3. **Rule out external bottlenecks first** — if 90% of latency is a slow DB query, reducing allocations won't help
4. **One change at a time** — measure, change, re-measure

### Optimization Methodology

1. Define metric (latency, throughput, memory, CPU)
2. Write benchmark: `go test -bench=BenchmarkMyFunc -benchmem -count=6 ./... | tee /tmp/report-1.txt`
3. Diagnose with pprof
4. Apply ONE optimization
5. Compare: `benchstat /tmp/report-1.txt /tmp/report-2.txt`
6. Repeat

### Decision Tree

| Bottleneck | Signal (pprof) | Action |
| --- | --- | --- |
| Too many allocations | `alloc_objects` high | Reduce allocations, preallocate, sync.Pool |
| CPU-bound hot loop | Function dominates CPU profile | Optimize algorithm, reduce work |
| GC pauses / OOM | High GC%, container limits | Set `GOMEMLIMIT` to 80-90% of container memory |
| Network / I/O latency | Goroutines blocked | Connection pools, circuit breakers |
| Repeated expensive work | Same computation multiple times | `singleflight`, caching |
| Lock contention | Mutex/block profile hot | Reduce critical sections, sharding |

### HTTP Transport Configuration

Default `http.Client` has no timeout and only 2 idle connections per host:

```go
client := &http.Client{
    Timeout: 30 * time.Second,
    Transport: &http.Transport{
        MaxIdleConns:        100,
        MaxIdleConnsPerHost: 10,   // default is 2 — too low
        IdleConnTimeout:     90 * time.Second,
    },
}
```

**Always drain response body** for connection reuse, even on error status:

```go
defer resp.Body.Close()
io.Copy(io.Discard, resp.Body)  // enables connection reuse
```

### Streaming JSON

Process large JSON arrays one item at a time instead of loading all into memory:

```go
dec := json.NewDecoder(resp.Body)
dec.Token() // read opening [
for dec.More() {
    var item Item
    if err := dec.Decode(&item); err != nil { return err }
    process(item)
}
```

### Common Performance Mistakes

| Mistake | Fix |
| --- | --- |
| Optimizing without profiling | Profile with pprof first |
| Default `http.Client` without Transport config | Set `MaxIdleConnsPerHost` to match concurrency |
| No GC tuning in containers | `GOMEMLIMIT` = 80-90% of container memory |
| `reflect.DeepEqual` in production | Use `slices.Equal`, `maps.Equal` (50-200x faster) |
| `panic`/`recover` as control flow | Use error returns |

---

## Benchmarking

### Writing Benchmarks

**`b.Loop()` (Go 1.24+)** — preferred, prevents dead code elimination:

```go
func BenchmarkParse(b *testing.B) {
    data := loadFixture("large.json")  // setup excluded from timing
    for b.Loop() {
        Parse(data)
    }
}
```

**Memory tracking:**

```go
func BenchmarkAlloc(b *testing.B) {
    b.ReportAllocs()
    for b.Loop() {
        _ = make([]byte, 1024)
    }
}
```

**Sub-benchmarks:**

```go
func BenchmarkEncode(b *testing.B) {
    for _, size := range []int{64, 256, 4096} {
        b.Run(fmt.Sprintf("size=%d", size), func(b *testing.B) {
            data := make([]byte, size)
            for b.Loop() { Encode(data) }
        })
    }
}
```

### Running Benchmarks

```bash
go test -bench=. -benchmem -count=10 ./... | tee bench.txt
```

| Flag | Purpose |
| --- | --- |
| `-bench=.` | Run all benchmarks |
| `-benchmem` | Report allocations |
| `-count=10` | Run 10 times for statistical significance |
| `-benchtime=3s` | Minimum time per benchmark |
| `-cpuprofile=cpu.prof` | Write CPU profile |
| `-memprofile=mem.prof` | Write memory profile |

### Profiling from Benchmarks

```bash
go test -bench=BenchmarkParse -cpuprofile=cpu.prof ./pkg/parser
go tool pprof cpu.prof

go test -bench=BenchmarkParse -memprofile=mem.prof ./pkg/parser
go tool pprof -alloc_objects mem.prof  # GC churn
go tool pprof -inuse_space mem.prof    # leaks
```

---

## Common Mistakes (All Infra)

| Category | Mistake | Fix |
| --- | --- | --- |
| Database | `SELECT *` | List columns explicitly |
| Database | N+1 queries | Use `JOIN` or `WHERE id IN (...)` |
| Database | OFFSET for pagination | Cursor-based pagination |
| Database | Unconfigured connection pool | Set MaxConns, MinConns, MaxConnLifetime |
| Security | SQL concatenation | Parameterized queries |
| Security | `exec.Command("bash", "-c", input)` | Pass args separately |
| Security | Hardcoded secrets | Env vars or secret manager |
| Security | `math/rand` for tokens | `crypto/rand` |
| Performance | Optimizing without profiling | pprof first |
| Performance | No `GOMEMLIMIT` in containers | Set to 80-90% of container memory |
