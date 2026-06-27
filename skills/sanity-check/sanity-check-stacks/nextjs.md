# Sanity Check — Next.js Stack Module

> Loaded by `sanity-check` skill when a Next.js project is detected. Run all checks below against changed files and include results in the STACK CHECKS section of the report.

---

## Next.js Checks

**1. `"use client"` / `"use server"` directives**
- Components using `useState`, `useEffect`, `useRef`, `useContext`, event handlers → must have `"use client"` at top
- Server Actions → must have `"use server"` (file-level or inline function)
- A `"use client"` component should not be directly imported by a Server Component as a default child — must be passed as a prop or composed correctly
- `grep -n "useState\|useEffect\|useRef\|onClick\|onChange" <changed files>` — if hits appear in a file without `"use client"`, flag it

**2. App Router file conventions**
- `page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `not-found.tsx` are only valid inside `app/`
- `route.ts` API routes only valid in `app/` — not `pages/api/`
- If migrating from Pages Router: check for orphaned `pages/api/` routes that were supposed to be replaced

**3. Next.js 15 async params**
- In Next.js 15+, `params` and `searchParams` in page/layout components are `Promise<...>` and must be awaited:
  ```ts
  // Wrong: const { id } = params
  // Right: const { id } = await params
  ```
- Check all `page.tsx` / `layout.tsx` files that destructure `params` or `searchParams`

**4. Route handler exports**
- API route handlers in `app/` must use named uppercase HTTP method exports: `GET`, `POST`, `PUT`, `DELETE`, `PATCH`
- Response must use `NextResponse` or `new Response()` — not `res.json()` (Pages Router pattern)
- `grep -n "res\.json\|res\.send\|res\.status" app/` — these are wrong in App Router

**5. Metadata API**
- `<Head>` from `'next/head'` in `app/` directory files → wrong, should use `export const metadata` or `generateMetadata`
- `generateMetadata` must be `async` if it fetches data
- `grep -rn "from 'next/head'" app/` — flag any hits

**6. Image and Link components**
- Raw `<img>` tags that should be `<Image>` from `next/image` (missing optimization + LCP impact)
- `<a href>` tags for internal navigation that should be `<Link>` from `next/link`
- `<Image>` must have `width` + `height` props, or `fill` prop — not both, not neither

**7. Environment variables**
- Client-side env vars must use `NEXT_PUBLIC_` prefix — non-prefixed vars are `undefined` in client code
- Server-only packages (`fs`, `path`, `crypto`, `bcrypt`) imported in `"use client"` files → will break build
- `.env.local` must be in `.gitignore`
- `grep -rn "process\.env\." app/` in client components — check for missing `NEXT_PUBLIC_` prefix

**8. next.config changes**
- New external image domains: must be in `images.remotePatterns`, not the deprecated `images.domains`
- New path aliases: must be consistent in both `next.config` and `tsconfig.json` `paths`
- `experimental` flags used: are they stable in the current Next.js version?

**9. Middleware**
- `middleware.ts` must be at project root, not inside `app/` or `src/`
- `matcher` config: verify patterns actually match the intended routes
- Middleware must not import Node.js-only modules (runs on Edge Runtime)

**10. Data fetching hygiene**
- `fetch()` in Server Components: `cache` and `revalidate` options set intentionally, not defaulted
- Client-side `fetch` in `useEffect`: missing abort controller → memory leak on fast navigation
- Async Server Components: `loading.tsx` or `<Suspense>` wrapping slow data fetches?
