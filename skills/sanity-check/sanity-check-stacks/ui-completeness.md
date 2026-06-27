# Sanity Check — UI Completeness Module

> Loaded by `sanity-check` skill when a frontend stack is detected (Next.js, React SPA). LLMs always build the happy path. This module checks the three states they almost always forget: loading, error, and empty.

---

## UI Completeness Checks

**1. Loading state**

Every async operation needs a loading state. Without it, the UI shows stale data or a blank screen while fetching.

- Components that fetch data: is there a loading indicator while the request is in-flight?
- Buttons that trigger async actions (submit, save, delete): disabled + visual feedback while pending? Without this, users double-submit
- Skeleton screens or spinners: present for any content that loads asynchronously
- `grep -n "isLoading\|isPending\|loading\|fetching" <changed files>` — if async data fetching exists but none of these appear, loading state is missing
- Next.js App Router: is there a `loading.tsx` alongside any async `page.tsx` that fetches data?

**2. Error state**

When a fetch, mutation, or action fails, something must tell the user. Silent failures are the worst UX.

- Every `fetch`/`axios`/`useMutation`/`useQuery` call: is there a `.catch()` / `onError` / `isError` handler that updates UI?
- Error boundary: wrapping async components in `<ErrorBoundary>` or Next.js `error.tsx`?
- Form submissions: server-side validation errors displayed to the user, not just logged to console
- Network errors (offline, timeout): handled with a user-visible message, not a blank screen
- `grep -n "isError\|onError\|catch\|error\.tsx\|ErrorBoundary" <changed files>` — cross-check against every async operation

**3. Empty state**

A list with no items should show something intentional, not render nothing.

- Every `.map()` over a data array: what renders when the array is empty `[]`?
- Search results: "No results found" when the query returns nothing
- Tables with no rows: empty state message, not a table with just headers
- User dashboards/feeds on first use (zero data): onboarding prompt, not a blank page
- `grep -n "\.map(\|\.length" <changed files>` — for each, check if there's a conditional for the empty case

**4. Optimistic updates gone wrong**

Optimistic UI (updating the UI before the server confirms) is great for feel but dangerous if not handled correctly.

- Optimistic update applied but server request fails: is the UI rolled back to the previous state?
- Optimistic update not rolled back leaves the UI showing data that doesn't exist on the server
- Race condition: two rapid actions, optimistic updates applied out of order
- `grep -n "optimistic\|onMutate\|rollback\|previousData" <changed files>` — verify rollback logic exists alongside every optimistic update

**5. Form state and validation feedback**

Forms are the most interaction-dense UI. LLMs write the submission logic but skip the UX details.

- Required fields: validated before submission, with visible error messages inline (not just an alert)
- Submit button: disabled while submitting to prevent double-submit
- Success feedback: after a successful form submission, does the user know it worked? (redirect, toast, message)
- Field-level errors: shown adjacent to the field, not just at the top of the form
- `grep -n "<form\|onSubmit\|handleSubmit" <changed files>` — trace each form for validation, loading, and success states

**6. Conditional rendering null leaks**

The most common React crash in production: rendering `null` or `undefined` as a child.

- `user.name` rendered directly where `user` could be `null` before data loads — use optional chaining: `user?.name`
- `{count} items` where `count` is `undefined` while loading — renders "undefined items"
- `{items.map(...)}` where `items` could be `undefined` — use `{items?.map(...)}` or default to `[]`
- `{isLoggedIn && <Component prop={user.id} />}` — if `isLoggedIn` can be true while `user` is still null
- `grep -n "{[a-zA-Z]*\.[a-zA-Z]*}" <changed .tsx/.jsx files>` — spot-check property access inside JSX for null safety

**7. Accessibility of interactive states**

State changes that are only visual break screen readers and keyboard users.

- Loading states: `aria-busy="true"` on loading containers, or `aria-label` on spinners
- Disabled buttons: `disabled` attribute set (not just visually styled as disabled)
- Error messages: associated with their input via `aria-describedby` or `role="alert"` for dynamic errors
- Modal/dialog: focus trapped inside while open, returned to trigger element on close
- `grep -n "disabled\|aria-\|role=" <changed files>` — verify interactive state changes have accessible equivalents

**8. Responsive and overflow edge cases**

LLMs design for average content. Real data breaks layouts.

- Long strings (username, product title, URL) without `overflow: hidden` / `text-overflow: ellipsis` / `truncate` — will overflow their container
- Dynamic lists: tested with 0 items, 1 item, and many items? Layout that works for 3 items may break with 100
- Images without explicit dimensions or `aspect-ratio` — cause layout shift (CLS) while loading
- Modals/drawers on mobile: scrollable content if it exceeds viewport height?
- `grep -n "className=.*text-\|style=.*overflow\|truncate\|ellipsis" <changed files>` — check text containers for overflow handling

**9. Navigation and routing edge cases**

- Deep links: does navigating directly to a URL (not via the app) work, or does it require app state that only exists after a previous page visit?
- Browser back button: does it work correctly? (especially with modals, multi-step forms, or programmatic navigation)
- Auth redirect: protected routes redirect to login correctly; after login, do they redirect back to the originally requested page?
- 404 handling: navigating to a non-existent route shows a proper not-found page, not a crash

**10. Toast / notification cleanup**

- Success/error toasts: do they auto-dismiss? Is there a way to dismiss them manually?
- Multiple rapid actions: do toasts stack correctly or replace each other?
- Toast on unmount: if the component unmounts before the async action completes, does a toast still fire into a dead component? (memory leak + state update on unmounted component warning)
- `grep -n "toast\|notify\|notification\|alert(" <changed files>` — verify dismiss behavior and cleanup
