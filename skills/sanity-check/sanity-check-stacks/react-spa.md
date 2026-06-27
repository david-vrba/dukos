# Sanity Check — React SPA Stack Module

> Loaded by `sanity-check` skill when a Vite + React (non-Next.js) project is detected. Run all checks below against changed files and include results in the STACK CHECKS section of the report.

---

## React SPA Checks

**1. Rules of Hooks**
- Hooks called inside `if`, `for`, `while`, `switch`, or ternaries → Rules of Hooks violation, breaks React's state ordering
- Hooks called in regular functions that aren't components or custom hooks
- Custom hooks not named with `use` prefix → React won't enforce the rules for them
- `grep -n "useState\|useEffect\|useRef\|useCallback\|useMemo" <changed files>` — spot-check they're at the top level of the component

**2. useEffect discipline**
- Missing dependency array: `useEffect(() => { ... })` — runs after every render, almost never intentional
- Missing dependencies in the array: stale closure captures old values silently
- Effect with side effects that need cleanup (event listeners, timers, subscriptions, fetch): must return a cleanup function
- Data fetch without abort controller:
  ```ts
  useEffect(() => {
    const controller = new AbortController()
    fetch(url, { signal: controller.signal })
    return () => controller.abort()  // this is required
  }, [url])
  ```
- `grep -n "useEffect" <changed files>` — check every instance for a return/cleanup

**3. State mutation**
- Direct array mutation: `arr.push()`, `arr.splice()`, `arr.sort()` on state arrays → React won't re-render
- Direct object mutation: `obj.key = value` on state objects → same problem
- `setState` with a stale closure: reading state inside a callback without functional update form
  ```ts
  // Wrong: setCount(count + 1) inside a closure
  // Right: setCount(prev => prev + 1)
  ```

**4. Event handler mistakes**
- `onClick={handler()}` calls the function immediately at render instead of on click — should be `onClick={handler}` or `onClick={() => handler(arg)}`
- `grep -n "onClick={[a-zA-Z]*()" <changed files>` — flag any direct call syntax

**5. Key prop correctness**
- Missing `key` props on mapped lists → React reconciliation bugs
- Array index as `key` when the list can reorder or filter → causes wrong component state to persist
- Keys not unique within their sibling set
- `grep -n "\.map(" <changed files>` — check every `.map()` for a `key` prop

**6. Component structure**
- Component defined inside another component → recreated every render, loses all hook state
- `grep -n "function [A-Z]\|const [A-Z].*=.*(" <changed files>` — verify no component definitions inside render functions

**7. Vite environment variables**
- Must use `import.meta.env.VITE_` prefix for client-exposed vars — `process.env` doesn't exist in Vite
- `grep -n "process\.env" <changed files>` — every hit is wrong in a Vite project
- `import.meta.env.VITE_*` vars must be defined in `.env` / `.env.local` to avoid `undefined` at runtime

**8. Path aliases consistency**
- Aliases defined in `vite.config.ts` (e.g. `@` → `./src`) must also be in `tsconfig.json` `paths`
- Missing from either location → works at runtime but TypeScript errors, or vice versa
- `grep -n "resolve.*alias" vite.config.*` then cross-check `tsconfig.json`

**9. TypeScript prop types**
- Component props without type definition → `any` by default, hides bugs
- Event handler types: `React.ChangeEvent<HTMLInputElement>` not bare `any` or `Event`
- `useRef<T>(null)` — typed refs prevent null dereference errors at compile time
- `grep -n "props: any\|: any[^;]" <changed files>` — flag untyped props

**10. Accessibility basics**
LLMs routinely omit these. Check changed UI components:
- Interactive elements: `<div onClick>` and `<span onClick>` should be `<button>` (keyboard + screen reader accessible)
- Images: `<img>` must have `alt` attribute (empty `alt=""` is valid for decorative images)
- Form inputs: each `<input>` should have an associated `<label>` (via `htmlFor` + `id`, or wrapping)
- `grep -n "<div onClick\|<span onClick" <changed files>` — flag non-semantic interactive elements
