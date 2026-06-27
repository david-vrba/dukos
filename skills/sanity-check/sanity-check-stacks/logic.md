# Sanity Check — Logic & Edge Cases Module

> Loaded by `sanity-check` skill on EVERY run, regardless of stack. These are not syntax errors or import issues — they are logical correctness failures: code that compiles, type-checks, and looks fine, but produces wrong results or crashes with specific inputs.
>
> For each check: read the changed code, reason about what inputs are possible, and ask "what happens when this assumption breaks?"

---

## 1. Zero, Empty, and Null — The Holy Trinity of Runtime Crashes

The most common class of logic bug. Code assumes a non-zero, non-empty, non-null value and never guards against it.

**Division**
- Every division operation: can the denominator ever be zero?
  - User input → always possible
  - Calculated value (count, sum, difference) → possible if data is empty or equal
  - Time delta → possible if two timestamps are identical
- `grep -n "[^=!<>]/[^/=]" <changed files>` — find division operators, inspect each denominator

**Empty collections**
- `.reduce()` without an initial value on a potentially empty array → `TypeError: Reduce of empty array with no initial value`
- `.find()`, `.filter()` result used without null check — they return `undefined` / `[]` on no match
- `arr[0]`, `arr[arr.length - 1]` on a potentially empty array → `undefined`
- `Math.min()` / `Math.max()` called with no arguments → returns `Infinity` / `-Infinity`
- `list[0]` in Python on empty list → `IndexError`

**Null / None / undefined propagation**
- Value that can be `null`/`None`/`undefined` used in arithmetic → `NaN` or `TypeError`
- Optional chaining used to *access* a value but then the value is passed to a function that doesn't accept `undefined`
- Default values that are themselves falsy: `const val = input || 0` fails for `input = 0` (use `?? 0` instead)
- `grep -n "\|\| 0\|\| ''\|\| \[\]\|\| {}" <changed files>` — check each: should this be `??` instead of `||`?

---

## 2. Mathematical Invariants

Code that performs math without enforcing the mathematical rules that make the operation valid.

**Square roots, logs, powers**
- `Math.sqrt(x)` / `math.sqrt(x)` — can `x` be negative? → `NaN` (JS) or `ValueError` (Python)
- `Math.log(x)` — can `x` be zero or negative? → `-Infinity` / `NaN` / `ValueError`
- `x ** (1/3)` for negative `x` in JS → `NaN` (unlike Python which handles cube roots of negatives)
- Integer exponentiation with large exponents → overflow or very slow computation

**Percentages and ratios**
- Percentage of a total: if total is 0, result is `NaN` or `Infinity` — needs guard
- Percentages that must sum to 100: if they're calculated independently, floating point drift means they may not
- Ratio comparisons: `a/b > c/d` when `b` or `d` could be zero

**Modulo**
- `x % 0` → `NaN` in JS, `ZeroDivisionError` in Python
- Negative modulo: `-7 % 3` is `-1` in JS/C but `2` in Python — if mixing languages or porting code, behavior differs
- `grep -n "% " <changed files>` — check every modulo for zero divisor possibility

**Absolute values and signs**
- `Math.abs(INT_MIN)` in languages with fixed-width integers → overflow (result is still negative)
- Assuming a "distance" or "magnitude" calculation always returns positive without `Math.abs()`

---

## 3. Boundary Conditions

Code that works for typical inputs but breaks at the edges.

**Numeric boundaries**
- Negative inputs to functions that assume positive: age, price, quantity, index, count, size, duration
- Zero as input to functions that assume positive (e.g. pagination: `page=0` causing off-by-one, `limit=0` returning all records)
- Very large numbers: does integer arithmetic overflow? (JavaScript: numbers above `Number.MAX_SAFE_INTEGER` lose precision)
- Very small numbers: floating point underflow, near-zero comparisons with `===` instead of epsilon check

**String boundaries**
- Empty string `""` — does the function handle it, or does it assume `length >= 1`?
- Whitespace-only string `"   "` — often passes `if (str)` but fails business logic
- String longer than expected — database column length, API limit, UI display
- `str.trim()` never called on user input before comparison or storage

**Array / collection boundaries**
- Single-element array in code that assumes multiple elements (e.g. zip, chunk, sliding window)
- Array length that's odd when code assumes even (e.g. pairing elements)
- Duplicate values when code assumes unique (set operations, deduplication not performed)

**Index and offset**
- Off-by-one: `< len` vs `<= len`, first element vs last element, 0-indexed vs 1-indexed confusion
- Negative index used as array index: valid in Python (wraps around), silent `undefined` in JS
- Slice end index exceeding array length: safe in most languages but signals a logic error

---

## 4. Floating Point Traps

Floating point arithmetic does not behave like real-number arithmetic. LLMs routinely write code that assumes it does.

**Equality comparisons**
- `0.1 + 0.2 === 0.3` is `false` in JavaScript (and most languages)
- Never use `===` or `==` to compare floating point results — use epsilon: `Math.abs(a - b) < 1e-9`
- `grep -n "=== 0\.\|== 0\.\|!== 0\.\|!= 0\." <changed files>` — every float equality comparison is suspect

**Money and currency**
- Financial calculations using `float` / `double` → rounding errors that compound
- Money must use integer arithmetic (store as cents/pence) or a `Decimal` type
- `grep -n "price\|amount\|cost\|fee\|balance\|total" <changed files>` — verify no float arithmetic on monetary values

**NaN propagation**
- `NaN` is infectious: `NaN + 1 === NaN`, `NaN > 5 === false`, `NaN === NaN === false`
- A single `NaN` in a calculation chain produces `NaN` at the end with no error
- `parseInt("abc")` → `NaN` in JS — always validate before parsing
- `grep -n "parseInt\|parseFloat\|Number(" <changed files>` — check if result is validated

**Infinity**
- Division of any positive number by zero in JS → `Infinity` (not an error)
- `Infinity` in comparisons: `Infinity > 1000000` is `true` — may cause incorrect branching
- `isFinite()` / `isNaN()` checks missing before using parsed numbers in logic

---

## 5. Ordering and Uniqueness Assumptions

Code that assumes data arrives in a specific order or contains only unique values, without enforcing it.

**Sorted order**
- Binary search, merge operations, or "first/last" logic on data that isn't guaranteed to be sorted
- Sorting by multiple fields: secondary sort key only matters if primary sort key is equal — is this handled?
- Sort stability: some sorts are stable (preserve original order for equal elements), some aren't — does the logic depend on stability?

**Uniqueness**
- Set operations, deduplication, or "find one" logic on data that may contain duplicates
- Unique constraint assumed but not enforced at the data layer
- Hash map keys that can collide: using mutable objects as keys (JS `Map` vs object keys)

**Sequence gaps**
- Code that assumes IDs are sequential and gapless (e.g. `id + 1` to get the next record)
- Pagination that assumes no records are inserted between pages (cursor-based vs offset-based)

---

## 6. Recursion and Loops

**Recursion base cases**
- Every recursive function: is there a base case? Does every possible input eventually reach it?
- Base case that's only checked for one type of termination, missing another (e.g. checks for empty but not for negative)
- Mutual recursion: A calls B calls A — is there a guaranteed termination condition?
- Stack overflow potential: recursion depth unbounded for large inputs (should be iterative or use tail recursion)

**Loop termination**
- `while` loops: does the loop variable always move toward the exit condition?
- Loop that increments inside a conditional → may never increment in some branches → infinite loop
- `do...while` that performs a side effect before checking the condition — side effect happens at least once even if condition is immediately false

**Loop variable modification**
- Modifying a collection while iterating over it → skipped elements or infinite loop
- `for i in range(len(arr)): arr.pop()` → index out of bounds partway through

---

## 7. State and Preconditions

Code that assumes a specific state exists without verifying it.

**Assumed preconditions**
- Function that assumes "user is logged in" but is called before auth check
- Function that assumes "connection is open" but called before connect()
- Function that assumes "data is initialized" but called in a code path where init may have failed silently
- For each function with a precondition: trace all call sites and verify the precondition is met

**State machine violations**
- Operations that only make sense in certain states, called from any state
  - e.g. "pause" called when already paused, "submit" called when form is already submitting
- Boolean flags used to represent state that has more than 2 meaningful values → should be an enum/union type
- State updated in one place but read in another without synchronization

**Idempotency**
- Operations that should be idempotent (safe to call twice) but aren't
  - e.g. "initialize" that doubles values if called twice, "register" that creates duplicate records
- Retry logic that calls a non-idempotent operation multiple times on failure

---

## 8. Date, Time, and Timezone

**Timezone assumptions**
- `new Date()` / `datetime.now()` without explicit timezone → uses server/local timezone, not UTC
- Date comparisons between values in different timezones
- Displaying UTC time directly as local time without conversion
- `grep -n "new Date()\|Date\.now()\|datetime\.now()" <changed files>` — check timezone handling

**Calendar edge cases**
- Leap year: February 29 handling in date arithmetic (adding 1 year to Feb 29 → Feb 28 or March 1?)
- Month-end arithmetic: adding 1 month to Jan 31 → Feb 31 doesn't exist
- Daylight saving time: adding 24 hours ≠ adding 1 day (clocks change)

**Timestamp arithmetic**
- Duration calculations that cross DST boundaries off by 1 hour
- Unix timestamp storage: 32-bit integers overflow in 2038 — use 64-bit
- Comparing dates as strings: `"2024-12-01" > "2024-09-30"` works but `"9/30/2024" > "12/1/2024"` doesn't

---

## 9. Input Trust and Validation Boundaries

**Unvalidated user input used in logic**
- Numeric input from user/API treated as a number without parsing and range validation
  - e.g. `quantity * price` where `quantity` came from a form field and could be `-1` or `999999`
- String input used in a regex without escaping → `RegExp(userInput)` is an injection vector
- Boolean input from query string: `"false"` is truthy in JS — must explicitly compare to the string `"false"`

**Type coercion surprises (JavaScript)**
- `[] + []` → `""`, `[] + {}` → `"[object Object]"`, `{} + []` → `0`
- `==` comparisons across types: `"" == false`, `0 == ""`, `null == undefined` are all `true`
- `parseInt("08")` → `8` in modern JS but historically `0` (octal) — always pass radix: `parseInt("08", 10)`
- `grep -n "[^=!<>]==[^=]" <changed files>` — flag loose equality comparisons

**API response trust**
- Assuming API response fields are always present and the right type
- Using `response.data.user.name` without checking if `user` exists
- Assuming an API always returns an array (it may return `null` or an object on error)

---

## 10. Business Logic Invariants

Domain-specific rules that the code must enforce but LLMs often forget.

**Questions to ask about the changed code's domain:**

| Domain | Invariants to check |
|--------|-------------------|
| E-commerce / payments | Price always ≥ 0? Quantity always ≥ 1? Discount never exceeds price? Total = sum of line items? |
| User accounts | Username/email uniqueness enforced? Password never stored in plain text? Session invalidated on logout? |
| Inventory / stock | Stock count never goes negative? Reservation released if order cancelled? |
| Scheduling / calendar | Event end time always after start time? No overlapping bookings for same resource? |
| Voting / ratings | User can only vote once? Rating within allowed range (1-5)? |
| File operations | File size within limits? Extension in allowlist? Path stays within allowed directory? |
| Permissions | User can only access their own data? Admin actions require re-auth? |
| Pagination | Page number ≥ 1? Page size within min/max bounds? |

For each check: read the changed code and ask "what prevents a user or bad data from violating this invariant?"

---

## How to Run These Checks

1. Read each changed file completely — logic bugs require understanding intent, not just pattern matching
2. For each function, mentally trace: **what are all possible input values?** What happens at the extremes?
3. Pay extra attention to: arithmetic operations, collection access, user input usage, date handling, state transitions
4. If a function looks like it has a mathematical or domain invariant (calculator, financial, scheduling), explicitly test that invariant in your head
5. Flag anything where the code works for "normal" inputs but you can construct a specific input that breaks it
