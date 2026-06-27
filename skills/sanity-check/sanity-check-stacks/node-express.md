# Sanity Check — Node/Express Stack Module

> Loaded by `sanity-check` skill when a Node.js / Express project is detected. Run all checks below against changed files and include results in the STACK CHECKS section of the report.

---

## Node/Express Checks

**1. Async error propagation**
- Async route handlers must propagate errors to Express: wrap in `try/catch` and call `next(err)`, OR use `express-async-errors` / `express-async-handler`
- Unhandled promise rejections in routes → Express 4 silently hangs the request; Express 5 crashes
- Error-handling middleware must have exactly 4 params: `(err, req, res, next)` — Express identifies error middleware by arity
- `grep -n "async.*req.*res" <changed files>` — verify each async handler has error handling

**2. Middleware order**
This is the most common Express bug. The order in `app.use()` calls is the execution order:
- `express.json()` / `express.urlencoded()` before any route that reads `req.body`
- CORS middleware before everything else (including auth)
- Auth / validation middleware before the route handlers they protect
- Error-handling middleware last (after all `app.use()` route registrations)
- `grep -n "app\.use\|router\.use" <changed files>` — trace the registration order

**3. Routes registered**
- New route files: imported and mounted in the main `app.js` / `server.js`?
- Route prefix matches where the frontend expects to call (e.g. `/api/v1/users` not `/users`)
- `grep -rn "app\.use\|app\.get\|app\.post" <entry point file>` — verify new routes appear

**4. Response completion**
Routes that don't call `res.send()` / `res.json()` / `res.end()` on every code path → hanging requests:
- `if/else` branches where one path returns but another doesn't call `res`
- Missing `return` after `res.json()` in conditional branches → double-send crash
- `grep -n "return res\.\|res\.json\|res\.send" <changed files>` — trace every code path

**5. Security basics**
- `helmet()` middleware present — adds security headers
- `express.static()` not accidentally serving sensitive directories (`.env`, `config/`, `keys/`)
- Rate limiting on auth routes and public-facing endpoints
- `req.params` / `req.query` used in filesystem paths → path traversal risk (must sanitize)
- User input interpolated into queries → SQL/NoSQL injection (must use parameterized queries)
- `grep -n "req\.params\|req\.query\|req\.body" <changed files>` — trace each to its usage

**6. Environment and process**
- `process.env.PORT` used for server listen port (required for Railway, Render, Heroku, etc.)
- `NODE_ENV` checked where behavior should differ between dev and production (error detail in responses, etc.)
- `dotenv.config()` called before any `process.env` access — typically first line of entry point
- `grep -n "process\.env\.PORT\|\.listen(3000\|\.listen(8080" <entry point>` — hardcoded ports are a deploy footgun

**7. Module system consistency**
- `"type": "module"` in `package.json` → must use `import`/`export` throughout, not `require()`
- No `"type": "module"` → `require()` is correct, don't mix ESM syntax
- In ESM: `__dirname` and `__filename` don't exist — need:
  ```js
  import { fileURLToPath } from 'url'
  const __dirname = path.dirname(fileURLToPath(import.meta.url))
  ```
- `grep -n "require(\|__dirname\|__filename" <changed files>` in an ESM project → flag

**8. Database patterns (if DB usage detected)**
- Connection pooling used — not a new connection per request
- All queries parameterized, not string-concatenated
- DB connection errors handled at startup — app should not silently start with no DB connection
- Transactions: multiple writes that must be atomic are in a transaction, not sequential individual queries
- `grep -n "pool\|Pool\|createConnection" <changed files>` — verify pool not one-off connections

**9. File uploads (if multer or similar detected)**
- File size limits configured (`limits: { fileSize: ... }`)
- File type validation: MIME type check, not just extension (extensions are user-controlled)
- Temp upload files cleaned up after processing (not just on success — also on error paths)

**10. Process hygiene**
- `process.on('uncaughtException', ...)` and `process.on('unhandledRejection', ...)` handlers present
- Graceful shutdown: `SIGTERM` handler closes the HTTP server and DB connections before `process.exit(0)`
- Sensitive data not logged: passwords, tokens, full request bodies with PII
- `console.log` in request hot paths → use `pino` or `winston` with log levels
