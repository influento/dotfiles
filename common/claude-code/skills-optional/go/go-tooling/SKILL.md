---
name: go-tooling
description: Go linting (golangci-lint), CLI patterns, dependency management, Go version modernization, and CI/CD. TRIGGER when setting up Go projects, configuring linters, writing CLI tools, or managing dependencies.
---

# Go Tooling

Linting, CLI patterns, dependency management, Go version modernization, and CI/CD.

## Linting (golangci-lint)

`golangci-lint` is the standard Go linting tool — aggregates 100+ linters into a single binary. Every Go project MUST have a `.golangci.yml`.

### Quick Reference

```bash
golangci-lint run ./...           # run all configured linters
golangci-lint run --fix ./...     # auto-fix where possible
golangci-lint fmt ./...           # format code (v2+)
golangci-lint run --enable-only govet ./...  # single linter
golangci-lint linters             # list available linters
```

### Recommended Linter Categories

| Domain | Linters | Catches |
| --- | --- | --- |
| Correctness | govet, staticcheck, unused, errcheck, nilerr, forcetypeassert, copyloopvar | Bugs, unchecked errors, stdlib misuse |
| Style | gocritic, revive, wsl_v5, whitespace, godot, misspell, predeclared, errname | Readability, naming, consistency |
| Complexity | gocyclo, nestif, funlen, dupl | Overly complex or duplicated code |
| Performance | perfsprint, unconvert, ineffassign, goconst | Unnecessary conversions, dead assigns |
| Security | bodyclose, sqlclosecheck, rowserrcheck | Resource leaks (HTTP, SQL) |
| Testing | thelper, paralleltest, testifylint | Test hygiene |
| Modernization | modernize, intrange, usestdlibvars, exhaustive, nolintlint | Modern Go idioms, lint hygiene |
| Formatting | gofmt, gofumpt | Code formatting |

### Key Linters Explained

- **errcheck** — ensures all error returns are checked (configure: `check-type-assertions: true`)
- **forcetypeassert** — flags `v := x.(T)` without comma-ok
- **nilerr** — detects returning nil error when `err` is non-nil
- **bodyclose** — ensures HTTP response bodies are closed
- **sqlclosecheck** — ensures `sql.Rows` and `sql.Stmt` are closed
- **rowserrcheck** — ensures `sql.Rows.Err()` is checked after iteration
- **modernize** — detects code rewritable with newer Go features (golangci-lint v2.6.0+)
- **nolintlint** — enforces `//nolint` directives specify linter name + justification

### Suppressing Lint Warnings

```go
//nolint:errcheck // fire-and-forget logging, error is not actionable
_ = logger.Sync()
```

Rules:
1. MUST specify the linter name: `//nolint:errcheck` not `//nolint`
2. MUST include a justification comment
3. NEVER suppress security linters without strong reason

**When to fix vs suppress:**

| Fix always | OK to suppress with justification |
| --- | --- |
| errcheck, govet, staticcheck, bodyclose, sqlclosecheck | funlen (orchestration functions), gocyclo (complex but clear) |
| nilerr, forcetypeassert, rowserrcheck | dupl (intentional parallel structure), goconst (context-specific) |

### Recommended Config Thresholds

Key settings for `.golangci.yml`:
- `gocyclo` max complexity: 13
- `funlen` max lines: 120, max statements: 80
- `dupl` threshold: 20 tokens
- `goconst` min length: 2 chars, min occurrences: 3
- `errcheck` with `check-type-assertions: true`
- `gofumpt` with `extra-rules: true`

### Makefile Targets

```makefile
lint:
	golangci-lint run ./...
lint-fix:
	golangci-lint run --fix ./...
fmt:
	golangci-lint fmt ./...
```

### Workflow

1. Run after every significant change: `golangci-lint run ./...`
2. Auto-fix: `golangci-lint run --fix ./...`
3. Incremental adoption: set `issues.new-from-rev` to lint only new code

### Common Issues

| Problem | Solution |
| --- | --- |
| "deadline exceeded" | Increase `run.timeout` in config |
| Too many issues on legacy code | `issues.new-from-rev: HEAD~1` |
| v1 config errors after upgrade | `golangci-lint migrate` |

---

## CLI Patterns (Cobra + Viper)

Use Cobra + Viper as the default stack. Cobra provides command/subcommand/flag structure, Viper handles config from files, env vars, and flags.

### Project Structure

```
cmd/myapp/
    main.go       # package main, only calls Execute()
    root.go       # root command + Viper init
    serve.go      # "serve" subcommand
    version.go    # "version" subcommand
```

### Root Command

- `SilenceUsage: true` MUST be set — prevents full usage on every error
- `SilenceErrors: true` MUST be set — lets you control error output
- `PersistentPreRunE` for config initialization before any subcommand
- Logs go to stderr, program output goes to stdout

### Viper Config Precedence

1. CLI flags (highest)
2. Environment variables
3. Config file
4. Defaults (lowest)

Always bind flags to Viper: `viper.BindPFlag("port", cmd.Flags().Lookup("port"))`. Use `viper.SetEnvPrefix("MYAPP")` to namespace env vars.

### Argument Validation

| Validator | Description |
| --- | --- |
| `cobra.NoArgs` | Fails if any args |
| `cobra.ExactArgs(n)` | Requires exactly n |
| `cobra.MinimumNArgs(n)` | At least n |
| `cobra.RangeArgs(min, max)` | Between min and max |

### Exit Codes

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | General error |
| 2 | Usage error |
| 128+N | Terminated by signal N |

### I/O Rules

- NEVER write diagnostics to stdout — stdout is for program output (pipeable)
- Use `cmd.OutOrStdout()` / `cmd.ErrOrStderr()` so tests can capture output
- Support `--output` flag (json/table/plain) for machine-readable output

### Version Embedding

Embed at compile time via ldflags — never hardcode version strings.

### Signal Handling

MUST use `signal.NotifyContext` for clean shutdown propagation through context.

### Common CLI Mistakes

| Mistake | Fix |
| --- | --- |
| `os.Stdout` directly | Use `cmd.OutOrStdout()` for testability |
| `os.Exit()` inside RunE | Return error, let `main()` decide |
| Flags not bound to Viper | Call `viper.BindPFlag` for every flag |
| Missing `viper.SetEnvPrefix` | Namespace env vars to avoid collisions |
| Logging to stdout | Logs go to stderr |
| Config file required | Ignore `viper.ConfigFileNotFoundError` |
| Hardcoded version | Inject via ldflags |

---

## Dependency Management

### AI Agent Rule

Before adding ANY new dependency, agents MUST ask the user for confirmation. Present: package name, purpose, stdlib alternative, GitHub stars, license, alternatives.

### Key Rules

- `go.sum` MUST be committed — cryptographic checksums detect supply-chain tampering
- `govulncheck ./...` before every release
- `go mod tidy` before every commit that changes dependencies
- Prefer `go get -u=patch` for routine updates (safer than `-u`)

### Essential Commands

| Command | Purpose |
| --- | --- |
| `go mod tidy` | Add missing, remove unused |
| `go mod verify` | Verify checksums |
| `go mod why -m pkg` | Why is this dep needed? |
| `govulncheck ./...` | Vulnerability scan |
| `go get pkg@none` | Remove dependency |
| `go get -u=patch ./...` | Patch-level upgrades |

### tools.go Pattern

Pin tool versions without importing in production:

```go
//go:build tools
package tools
import (
    _ "github.com/golangci/golangci-lint/cmd/golangci-lint"
    _ "golang.org/x/vuln/cmd/govulncheck"
)
```

---

## Go Modernization

Use modern Go features. Check `go.mod` version to determine available features.

### Deprecated Packages

| Deprecated | Replacement | Since |
| --- | --- | --- |
| `math/rand` | `math/rand/v2` | Go 1.22 |
| `runtime.SetFinalizer` | `runtime.AddCleanup` | Go 1.24 |
| `golang.org/x/crypto/sha3` | `crypto/sha3` | Go 1.24 |
| `golang.org/x/crypto/hkdf` | `crypto/hkdf` | Go 1.24 |
| `golang.org/x/crypto/pbkdf2` | `crypto/pbkdf2` | Go 1.24 |
| `testing/synctest.Run` | `testing/synctest.Test` | Go 1.25 |

### Migration Priority

**High (safety and correctness):**
1. Remove loop variable shadow copies (Go 1.22+)
2. Replace `math/rand` with `math/rand/v2` (Go 1.22+)
3. Use `os.Root` for user-supplied file paths (Go 1.24+)
4. Run `govulncheck` (Go 1.22+)
5. Use `errors.Is`/`errors.As` (Go 1.13+)

**Medium (readability):**
6. Replace `interface{}` with `any` (Go 1.18+)
7. Use `min`/`max` builtins (Go 1.21+)
8. Use `range` over int (Go 1.22+)
9. Use `slices`/`maps` packages (Go 1.21+)
10. Use `cmp.Or` for defaults (Go 1.22+)
11. Use `sync.OnceValue` (Go 1.21+)
12. Use `t.Context()` in tests (Go 1.24+)
13. Use `b.Loop()` in benchmarks (Go 1.24+)

**Lower (gradual):**
14. Adopt iterators (Go 1.23+)
15. Replace `sort.Slice` with `slices.SortFunc` (Go 1.21+)
16. Enable PGO for production builds (Go 1.21+)

### Key Modernizations by Version

**Go 1.21:** `min`/`max`/`clear` builtins, `slices`/`maps` packages, `slog` logging, `sync.OnceValue`/`OnceFunc`, `context.WithoutCancel`/`AfterFunc`

**Go 1.22:** `range` over int, loop variable per-iteration scoping (fixes closure bug), `math/rand/v2`, enhanced `net/http` routing with `{id}` patterns, `cmp.Or`, `strings.CutPrefix`/`CutSuffix`

**Go 1.23:** iterators (`range` over functions), `iter` package, `slices.Chunk`/`slices.Sorted`, `unique` package, timer/ticker GC without Stop()

**Go 1.24:** generic type aliases, `os.Root` (path traversal prevention), `omitzero` JSON tag, `strings.SplitSeq`/`FieldsSeq`/`Lines`, `t.Context()`, `b.Loop()`, `runtime.AddCleanup`, `weak.Pointer`, `crypto/sha3`/`hkdf`/`pbkdf2` promoted to stdlib, tool directives in `go.mod`

**Go 1.25:** `sync.WaitGroup.Go`, `testing/synctest.Test`, `runtime/trace.FlightRecorder`, container-aware `GOMAXPROCS`, `encoding/json/v2` (experimental)

**Go 1.26:** `errors.AsType[T]()`, enhanced `new()` with initial value, `crypto/hpke`, Green Tea GC (10-40% less overhead), modernized `go fix`

---

## CI/CD (GitHub Actions)

### Pipeline Stages

| Stage | Tool | Purpose |
| --- | --- | --- |
| Test | `go test -race -shuffle=on` | Unit + race detection |
| Coverage | `codecov/codecov-action` | Coverage reporting |
| Lint | `golangci-lint` | Comprehensive linting |
| SAST | `gosec`, `CodeQL`, `govulncheck` | Security analysis |
| Deps | Dependabot / Renovate | Automated updates |
| Release | GoReleaser | Binary releases |

### Test Configuration

- `-race` MUST be used in CI
- `-shuffle=on` to catch order-dependent tests
- `-count=1` for integration tests (disable caching)
- `fail-fast: false` so one Go version failure doesn't cancel others
- Check `go mod tidy && git diff --exit-code`

### Dependency Updates

**Dependabot:** group minor/patch updates, individual PRs for majors. Auto-merge with branch protection as safety net.

**Renovate (alternative):** native automerge, `gomodTidy`, better grouping, regex managers for Dockerfiles/Makefiles.

### GoReleaser

Automates cross-compiled binaries, checksums, GitHub Releases. Config varies by project type (CLI, library, monorepo). Always check latest action versions before writing workflow YAML.

### Common CI Mistakes

| Mistake | Fix |
| --- | --- |
| Missing `-race` | Always `go test -race` |
| No `-shuffle=on` | Randomize test order |
| Caching integration tests | `-count=1` |
| `go mod tidy` not checked | `go mod tidy && git diff --exit-code` |
| Not pinning action versions | Use `@vN`, not `@master` |
| No `permissions` block | Least-privilege per job |

---

## Dependency Injection

For Arc's size (< 20 services), use manual constructor injection. No DI library needed.

```go
func main() {
    db := store.New(connStr)
    logger := zerolog.New(os.Stdout)
    spawner := spawner.New(db, logger, dockerClient)
    api := api.New(db, spawner, logger)
    daemon.New(api, cfg).Start()
}
```

Rules:
- Dependencies MUST be injected via constructors — never globals or `init()`
- Interfaces defined where consumed, not where implemented
- DI container only at composition root (`main()`) — never pass as dependency
- Consider a library at 20+ services with lifecycle management needs
