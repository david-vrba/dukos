# Sanity Check — Python Stack Module

> Loaded by `sanity-check` skill when a Python project is detected. Run all checks below against changed files and include results in the STACK CHECKS section of the report.

---

## Python Checks

**1. Virtual environment & dependency tracking**
- New packages imported in changed files: are they in `requirements.txt` / `pyproject.toml`?
- `pip install` run globally instead of inside the project venv → not reproducible
- If using `pyproject.toml`: are new deps in `[project.dependencies]` or `[tool.poetry.dependencies]`?
- `grep -n "^import\|^from" <changed files>` — for each third-party import, verify it's declared

**2. Package structure / imports**
- Every new directory that's a Python package: does it have `__init__.py`?
- Relative vs absolute imports: if `src/` layout, imports must reflect it (`from src.module` vs `from module`)
- Circular imports: if module A imports from B and B imports from A → `ImportError` at runtime
- `grep -rn "from \.\." <changed files>` — verify relative import depth is correct

**3. Async correctness**
- `async def` functions must be `await`-ed when called — look for unawaited coroutine calls
- Sync blocking I/O inside async functions: `open()`, `requests.get()`, `time.sleep()` → use `aiofiles`, `httpx`, `asyncio.sleep()`
- `asyncio.run()` called inside an already-running event loop (common in FastAPI background tasks or Jupyter)
- `grep -n "requests\.\|open(\|time\.sleep" <async changed files>` — flag sync calls in async context

**4. Exception handling**
- Bare `except:` → catches `BaseException` including `KeyboardInterrupt` — should be `except Exception:`
- Silent swallowing: `except Exception: pass` without any logging → hides real errors
- `raise NewError()` without `from original_error` loses traceback context
- `grep -n "except:" <changed files>` — every bare except is a flag

**5. Type hints consistency**
- If type hints were added or changed, verify they match actual usage
- `Optional[X]` vs `X | None` — pick one style and be consistent with the rest of the file (Python version matters: `|` union requires 3.10+)
- Return type annotations that don't match what the function actually returns
- `grep -n "-> None\|-> Any\|-> dict" <changed files>` — spot-check return types

**6. Configuration and secrets**
- Hardcoded credentials, API keys, connection strings, or tokens in source files
- `os.environ["KEY"]` (raises `KeyError` if missing) vs `os.environ.get("KEY")` — is the crash-on-missing behavior intentional?
- If using `python-dotenv`: `load_dotenv()` called before any `os.environ` access
- `grep -n "os\.environ\[" <changed files>` — verify each one should hard-fail on missing key

**7. Mutable default arguments**
- `def func(data=[])` or `def func(config={})` → shared across all calls, classic Python footgun
- `grep -n "def .*=\[\|def .*={}" <changed files>` — flag any hits

**8. FastAPI-specific (if `fastapi` detected in deps)**
- New routers: included in the main `app` with `app.include_router()`?
- Pydantic response models: do they match what the endpoint actually returns?
- `async` route handlers that call sync blocking I/O: use `run_in_executor` or make I/O async
- CORS: `allow_origins=["*"]` acceptable only in dev — flag if in production config path

**9. Django-specific (if `django` detected in deps)**
- New views: registered in `urls.py`?
- New models: migration created (`python manage.py makemigrations`)? Migration applied?
- New admin-registered models: `admin.py` updated?
- `settings.py` changes: `DEBUG=True` left on in production config path?

**10. Test discovery**
- Test files must be named `test_*.py` or `*_test.py` for pytest to collect them
- Fixtures used in tests: actually defined or imported from `conftest.py`?
- `pytest.mark` decorators: markers registered in `pyproject.toml` or `pytest.ini` if custom?
- `grep -rn "def test_" <changed test files>` — verify naming convention
