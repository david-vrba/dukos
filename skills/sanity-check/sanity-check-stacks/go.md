# Sanity Check — Go Stack Module

> Loaded by `sanity-check` skill when a Go project is detected. Run all checks below against changed files and include results in the STACK CHECKS section of the report.

---

## Go Checks

**1. Error handling discipline**
- Every function returning `error` must have its error checked at the call site — Go will compile without it, but it's a logic bug
- `err` shadowing: `:=` redeclaring `err` in an inner scope while the outer `err` is silently ignored
- `log.Fatal()` / `os.Exit()` called inside non-`main` packages → prevents `defer` cleanup from running
- `grep -n "_\s*=" <changed files>` — blank identifier discarding errors is the most common Go mistake

**2. Goroutine lifecycle**
- Every `go func()` launch: is there a `WaitGroup`, channel, or `context.Done()` to know when it finishes?
- Goroutines writing to channels: is the channel still open, and is the receiver still alive?
- `context.Context` passed but cancellation not propagated to the goroutine → goroutine leaks
- Goroutine that references a loop variable: in Go < 1.22, loop variable capture requires `v := v` inside the loop

**3. Interface satisfaction**
- If a struct is supposed to implement an interface, verify all methods are present with correct signatures
- Pattern to check: `var _ InterfaceName = (*StructName)(nil)` — if this doesn't compile, the interface is not satisfied
- Pointer receiver vs value receiver: mixing them breaks interface satisfaction in non-obvious ways

**4. Module and import hygiene**
```bash
go mod tidy --check 2>/dev/null || echo "go.mod out of sync"
```
- `go.mod` module path must match the actual directory structure and import paths
- All new imports present in `go.mod` (run `go mod tidy` if needed)
- Unused imports left in changed files → compilation error, but catch before running
- `grep -n "\"" <changed .go files>` — spot check import paths for typos

**5. Nil safety**
- Pointer dereference without nil check at function boundaries
- Map read without ok check: `val := m[key]` when zero value is ambiguous — should be `val, ok := m[key]`
- Interface nil trap: a typed nil (`(*T)(nil)` wrapped in an interface) is NOT `== nil`
- `grep -n "\*[a-zA-Z]" <changed files>` — spot-check dereferences in changed code

**6. Resource cleanup with defer**
- `defer file.Close()` after every `os.Open()`
- `defer rows.Close()` after every `db.Query()`
- `defer resp.Body.Close()` after every `http.Get()` / `client.Do()`
- `defer mu.Unlock()` after every `mu.Lock()`
- `grep -n "\.Open\|\.Query\|http\.Get\|\.Lock()" <changed files>` — verify each has a corresponding defer

**7. HTTP handler patterns**
- `http.Error(w, msg, code)` called but execution continues → must `return` immediately after
- JSON decode: `decoder.Decode()` error checked; body size limit set with `http.MaxBytesReader`
- `r.Body.Close()` deferred in handlers
- `grep -n "http\.Error" <changed files>` — verify each is followed by `return`

**8. Concurrency correctness**
- Shared state accessed from multiple goroutines: protected by `sync.Mutex`, `sync.RWMutex`, or `atomic` ops?
- `sync.WaitGroup`: `wg.Add()` called before `go func()`, not inside it
- Channel sends without a corresponding receive path → deadlock

**9. Build tags and generated code**
- Build tags: new-style syntax `//go:build ...` (Go 1.17+) — not old `// +build ...`
- `go generate` stubs or mocks: were they regenerated after interface changes?
```bash
go build ./... 2>&1   # catch compilation errors before running tests
go vet ./...          # catches common correctness issues
```

**10. Test correctness**
- `t.Parallel()` used: is any shared state between parallel tests? → data races
- Table-driven tests: in Go < 1.22, loop variable capture inside `t.Run()` requires `tc := tc`
- Subtests using `t.Run()`: parent test must not return before subtests finish (use `t.Cleanup` or `wg`)
- `grep -n "t\.Parallel()" <changed test files>` — verify no unprotected shared state nearby
