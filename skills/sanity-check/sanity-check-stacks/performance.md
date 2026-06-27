# Sanity Check — Performance Module

> Loaded by `sanity-check` skill on EVERY run, regardless of stack. Performance bugs are invisible in development (small data, single user) and only surface in production (real data, concurrent users). Catch them before they get there.
>
> For each check: read the changed code and ask "what happens when this runs against 100,000 records, or 1,000 concurrent users?"

---

## Performance Checks

**1. N+1 database queries**

The most common and most damaging performance bug. Code makes one query to get a list, then one query *per item* to get related data — what looks like O(1) is actually O(n).

- Loop that calls the database per iteration: `users.forEach(async u => await db.query('SELECT * FROM posts WHERE user_id = ?', u.id))` — this is N+1; should be one query with `WHERE user_id IN (?)` or a JOIN
- ORM patterns: `.findAll()` followed by accessing a related model property inside a loop without eager loading (`include`/`with`/`preload`/`joinedload` depending on ORM)
- Nested component data fetching: parent fetches a list, each child component fetches its own data — consolidate at the parent
- `grep -n "\.forEach\|\.map\|for.*of\|for.*in\|for.*range" <changed files>` — inspect every loop for DB calls, fetch calls, or API calls inside it

**2. Unbounded queries and over-fetching**

Queries that return everything, every time. Fine for 100 rows. A silent killer for 100,000.

- `SELECT *` / `.findAll()` / `.find({})` / `.all()` with no `LIMIT` or pagination on tables that will grow with usage
- Fetching full documents/rows when only one or two fields are needed — `SELECT *` when only `id` and `name` are used
- List/index endpoints that return all records without pagination — add `limit`/`offset` or cursor-based pagination
- Loading entire file contents into memory when streaming would work (large file processing)
- `grep -n "SELECT \*\|findAll(\|\.find({\|\.objects\.all()\|\.fetchAll" <changed files>` — review each for LIMIT and field selection

**3. Missing database indexes**

Unindexed queries do full table scans. 100ms on 1,000 rows becomes 100 seconds on 1,000,000.

- New columns added to a model/schema that are used in `WHERE` clauses — do they have an index?
- New `ORDER BY` columns — sort without an index is a full scan + sort
- Foreign key columns: most ORMs don't auto-create indexes on FK columns — a lookup from orders → users without an index on `orders.user_id` is a full scan
- Composite query patterns: if you filter on `(status, created_at)` together, you need a composite index on both — a single-column index on just `status` won't cover the full query efficiently
- Check migration files: new columns added without `CREATE INDEX` or `add_index` statements are suspect

**4. Algorithmic complexity — O(n²) hiding in plain sight**

Code that looks simple but scales quadratically. Works fine in tests with 10 items, hangs the server with 10,000.

- Nested loops over the same collection: `for item in list: for other in list` — O(n²); often replaceable with a `Map`/`Set` lookup
- `.find()` / `.filter()` / `.includes()` / `in list` inside a loop over a large collection — each is O(n), making the overall loop O(n²); build a `Set` or `Map` before the loop for O(1) lookups
- Sorting inside a loop: even O(n log n) sort done n times = O(n² log n)
- Recursive algorithms without memoization on overlapping subproblems — exponential blowup
- `grep -n "\.find(\|\.filter(\|\.includes(\| in " <changed files>` — check if any are inside a `for`/`forEach`/`.map()` loop

**5. Blocking the event loop (Node.js / async JS)**

The Node.js event loop is single-threaded. One synchronous CPU-intensive operation blocks *all* requests until it finishes.

- `JSON.parse()` or `JSON.stringify()` on very large payloads in a request handler — consider streaming parsers
- `fs.readFileSync()` / `fs.writeFileSync()` in any request handler — use async `fs.readFile()` / `fs.writeFile()`
- CPU-intensive loops (image processing, data transformation, complex calculations) done synchronously on the main thread — offload to a worker thread (`worker_threads`) or background job queue
- Synchronous crypto operations on large inputs: prefer async variants
- Complex regex on long strings: catastrophic backtracking is a CPU DoS vector
- `grep -n "Sync(\|JSON\.parse\|JSON\.stringify" <changed files>` — flag sync I/O in request-path code

**6. Memory leaks**

Memory that grows without bound until the process runs out and crashes. LLMs never write the cleanup code.

- `addEventListener` / `.on()` / `.subscribe()` calls without a corresponding `removeEventListener` / `.off()` / `.unsubscribe()` — common in React `useEffect` without a cleanup return, or in class components without `componentWillUnmount`
- `setInterval()` stored in a variable that's never cleared with `clearInterval()` — especially inside components or request handlers
- In-memory caches / Maps / objects used as caches with no maximum size, no TTL, and no eviction — they grow with every unique key forever
- Closures in long-lived objects (module-level variables, singletons) that capture large request-scoped data
- `grep -n "addEventListener\|setInterval\|new Map\|new Set\|\.on(" <changed files>` — verify each has a cleanup path

**7. Missing caching — repeated expensive work**

Doing the same expensive thing on every request when the result won't change between requests.

- Database queries for rarely-changing data (config values, feature flags, user roles, categories) executed on every request — these should be cached with a TTL
- Expensive external API calls made synchronously per request when the data could be cached
- Heavy computation (report generation, aggregation, transformation) run on demand without caching the result
- Static assets served without `Cache-Control` headers — browsers re-fetch on every page load
- DB connection created per request (`new Client()`, `new Pool()`) instead of a shared pool initialized at startup
- `grep -n "fetch(\|axios\.\|http\.get\|requests\.get" <changed files>` — check which calls happen on every request vs. could be cached

**8. Render performance (frontend)**

React re-renders unnecessarily, causing jank and wasted CPU on the client.

- Expensive components (large lists, complex visualizations, heavy calculations) that re-render on every parent render without `React.memo`
- Calculations that depend only on props/state but are done inline in render without `useMemo` — recalculated every render even when inputs haven't changed
- New object or array literals created inline as props or context values: `<Component style={{ color: "red" }} />` — a new object is created every render, breaking `memo` equality checks; extract to a constant or `useMemo`
- Entire large libraries imported at the top level: `import _ from 'lodash'` / `import * as d3 from 'd3'` — import only what's used, or use dynamic `import()` for route-level code splitting
- Long lists rendered without virtualization (`react-window`, `react-virtual`) — rendering 10,000 DOM nodes is always slow
- `grep -n "import.*from 'lodash'\|import.*from 'd3'\|import \* as" <changed files>` — flag full library imports

**9. Payload and network**

Data sent over the wire that's larger than it needs to be. Every extra byte costs latency, especially on mobile.

- API responses that include every field of every related model when the client uses only 2-3 fields — select only needed fields or use a response DTO/serializer
- Images served at full resolution without compression or responsive sizing — use WebP, set explicit dimensions, use CDN transforms
- No gzip/brotli compression middleware on API responses (`compression` in Express, built-in in Next.js/Nginx)
- Polling with `setInterval + fetch` to check for updates when Server-Sent Events or WebSocket would be more efficient and lower-latency
- Chatty API patterns: 5+ sequential requests on page load that could be a single batched request or GraphQL query
- `grep -n "setInterval.*fetch\|setInterval.*axios" <changed files>` — flag polling patterns

**10. Startup and initialization**

Work done at module load time or cold start that slows down every deployment and serverless invocation.

- Heavy synchronous computation at the module level (outside of any function) — runs on every `require`/`import`, including in serverless cold starts
- Database connections not established at startup: if the first request pays the connection cost, all concurrent cold-start requests wait and then connection-pool-storm the DB
- Large data structures (lookup tables, in-memory indexes) built synchronously at startup — should be async and ideally lazy or pre-warmed
- All routes/controllers imported eagerly at startup in a monolith that could use lazy loading — increases cold start time for rarely-used routes
- `grep -n "^const\|^let\|^var" <changed module-level code>` — check for heavy computation at module scope (outside functions)
