# Sanity Check — Database Migrations Module

> Loaded by `sanity-check` skill when migration files appear in the changed set. Migrations are the most dangerous code in any project — they run once, they're hard to reverse, and a bad one can corrupt production data or lock a table for minutes under live traffic.
>
> Detection: load this file if changed files include any of: `migrations/`, `db/migrate/`, `alembic/versions/`, `prisma/migrations/`, files matching `*_migration*`, `*migrate*`, `schema.sql`, or `*.sql`.

---

## Migration Safety Checks

**1. Destructive operations — data loss risk**

The most irreversible category. Once data is dropped, it's gone unless you have a backup.

- `DROP TABLE` — is this intentional? Is data migrated elsewhere first?
- `DROP COLUMN` — data in that column is permanently deleted. Is it backed up or no longer needed?
- `DELETE FROM` / `TRUNCATE` in a migration — bulk deletes with no rollback
- Column rename: many ORMs implement this as DROP + ADD, which loses all existing data — use explicit rename syntax instead (`ALTER TABLE ... RENAME COLUMN`)
- `grep -n "DROP\|TRUNCATE\|DELETE FROM" <migration files>` — every hit is a potential data loss event, verify it's intentional and the data is either migrated or genuinely disposable

**2. Missing rollback / down migration**

Every migration that goes up must be able to come back down. LLMs write `up()` and skip `down()`.

- Every migration file: does it have a `down()` / `def downgrade()` / `change` with reversible operations?
- `DROP TABLE` in `up()` → `down()` cannot recreate the data, only the schema — is that acceptable?
- Irreversible `up()` operations (data transformations, deletes) must at minimum have a `down()` that raises an error with a clear message rather than silently doing nothing
- `grep -n "def down\|exports\.down\|async down\|downgrade" <migration files>` — if absent, the migration has no rollback path

**3. NOT NULL columns added to existing tables**

Adding a `NOT NULL` column without a default to a table that already has rows will fail immediately in production.

- `ALTER TABLE ADD COLUMN column_name TYPE NOT NULL` with no `DEFAULT` — will reject if any existing rows exist
- The correct pattern: add column as nullable first → backfill existing rows → add NOT NULL constraint
- Or: add column with a temporary default → remove the default after backfill if needed
- `grep -n "NOT NULL\|notNull\|:null => false" <migration files>` — cross-check each with whether a DEFAULT is provided and whether the table could have existing rows

**4. Table locks on large tables**

Some DDL operations acquire an exclusive lock that blocks all reads AND writes for the duration. On a large table under live traffic, this means downtime.

- `ALTER TABLE` adding a column with a volatile default (PostgreSQL < 11): locks the table while rewriting every row
- Adding a non-concurrent index: `CREATE INDEX` (not `CREATE INDEX CONCURRENTLY`) locks the table
- `ALTER TABLE ... SET NOT NULL` without a prior constraint check: full table scan + lock
- Renaming a column or table: briefly locks dependent queries
- For PostgreSQL: prefer `CREATE INDEX CONCURRENTLY`, use `ADD COLUMN` with a constant default (fast in PG11+), and add constraints with `NOT VALID` then `VALIDATE CONSTRAINT` separately
- `grep -n "CREATE INDEX\b\|ALTER TABLE\|ADD COLUMN.*DEFAULT" <migration files>` — flag non-concurrent operations on tables that have production data

**5. Foreign key constraints without indexes**

Adding a foreign key constraint does NOT automatically create an index on the referencing column in most databases. This causes full table scans on every join or lookup from child to parent.

- Every `REFERENCES` / `foreign_key` added: is there a corresponding `CREATE INDEX` on the FK column?
- In Rails: `add_reference` adds both the column and index by default, but `add_column` + `add_foreign_key` does not
- In Prisma: `@relation` does not auto-create an index — must use `@@index`
- `grep -n "REFERENCES\|foreign_key\|add_foreign_key\|@relation" <migration files>` — verify a matching index exists for each

**6. Deploy order — code vs. migration timing**

The migration and the code change that depends on it must deploy in the correct order. LLMs write both at once without thinking about the gap between them.

- **Additive-first pattern** (safe): migration adds new column/table → code is deployed to use it. Old code ignores the new column, new code can use it.
- **Remove-last pattern** (safe): code is deployed to stop using a column → migration removes the column. Never remove a column while code still references it.
- **Dangerous pattern**: migration renames or removes a column at the same time as the code change — if the migration runs first, old code breaks; if code deploys first, it references a column that doesn't exist yet
- Assess: is there any window during rolling deployment where old code + new schema (or new code + old schema) would cause errors?

**7. Data migration correctness**

Migrations that transform existing data are the hardest to get right. LLMs write the transformation for the typical case and miss edge cases.

- Backfill operations: does the `UPDATE` or `INSERT` handle all rows, including NULLs, empty strings, or zero values?
- Batch size: backfilling millions of rows in a single transaction can lock the table and timeout — should be batched
- Idempotency: if the migration is run twice (accidental re-run), does it corrupt data or is it safe?
- `grep -n "UPDATE\|INSERT INTO.*SELECT\|batch" <migration files>` — review every data transformation for edge cases and batch safety

**8. Schema drift — migration matches the ORM model**

The migration file and the ORM model/schema definition must stay in sync. LLMs sometimes edit the model but forget to generate a migration, or vice versa.

- Prisma: `prisma migrate dev` was run after schema changes — `prisma/migrations/` reflects the current `schema.prisma`
- Django: `makemigrations` was run — no "model changes detected but no migration created" warning
- SQLAlchemy/Alembic: `alembic revision --autogenerate` was run and reviewed
- Rails: `db/schema.rb` is updated — matches the current migration state
- Cross-check: the model definition and the migration describe the same final schema

**9. Seed data and test data safety**

- Migrations that modify `seed.rb`, `seeds.sql`, or equivalent: will re-running seeds on production cause duplicate data or overwrites?
- Test fixtures that depend on specific IDs or sequences: will they break after this migration changes the schema?
- Environment checks: does any data migration have a hard-coded production-only or development-only data assumption?

**10. Backup and recovery verification**

Not something the code can check, but must be explicitly confirmed before a destructive migration ships.

- For any migration with `DROP`, `TRUNCATE`, `DELETE`, or complex data transforms: confirm a database backup exists and has been tested (i.e., can actually be restored) before running in production
- Migration tested on a production data copy (staging with prod data snapshot), not just dev with seed data — row counts and data distribution in prod are different and can expose timing/lock issues
- Rollback plan documented: if this migration fails halfway through, what is the recovery procedure?
