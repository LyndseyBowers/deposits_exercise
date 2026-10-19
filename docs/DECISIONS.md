# Decision Log

Key decisions for adding deposits to tradelines, with alternatives considered.

## Assumptions

Where the spec was silent, these are the calls made. Each would be a quick conversation with product.

- **Balance counts every deposit,** including future-dated ones. It means "not yet scheduled for payoff", not "paid to date".
- **Extra decimals are rounded, not rejected.** `decimal(8,2)` rounds half-up on assignment, and validation sees the
  rounded value: `10.005` is stored as `10.01`, and `0.004` becomes `0.00` and fails `> 0`.
- **One currency.** No currency field. Amounts are capped at 999,999.99 by `decimal(8,2)`, matching `tradelines.amount`.
- **Deposits are immutable.** No update or delete endpoints; corrections would be a new feature (e.g. reversals).
- **Tradeline amounts don't change.** There's no endpoint to edit them. If one were lowered below its deposit total,
  the balance would go negative; nothing guards against that today.
- **`tradelines.amount` stays nullable,** as in the starter schema. Null means "unknown", not zero; whether it should
  be required is a question for product.
- **Dates are calendar days in ISO 8601** (`YYYY-MM-DD`), with no time zone. Past dates are allowed, future dates are
  unbounded, and an unparseable date is treated as missing.
- **No auth or ownership.** Any client can read or create deposits for any tradeline.
- **No idempotency keys.** A retried `POST` creates a second deposit. The lock prevents *overpaying*, not *duplicates*.
- **No pagination.** Index endpoints return everything; deposits are ordered by `deposit_date`, then `id`.

---

## 1. `Deposit` model

`Deposit belongs_to :tradeline`; `Tradeline has_many :deposits`.

| Column | Type | Notes |
|---|---|---|
| `tradeline_id` | reference | required, indexed, foreign key |
| `amount` | `decimal(8,2)` | required; matches `tradelines.amount` |
| `deposit_date` | `date` | required; a calendar day, not a timestamp |

DB `CHECK (amount > 0)` backs up the model validation.
`dependent: :restrict_with_error` plus a foreign key: a tradeline with deposits can't be deleted. Financial history
is never silently cascaded away; real systems would close/archive rather than delete.

**Rejected:** a JSON column on `tradelines` (no per-deposit ids, validation, or SQL sums);
a generic ledger/transaction model (nothing in the spec needs other entry types);
`dependent: :destroy` (silently erases financial records).

## 2. Compute balance on read

`outstanding_balance = amount - SUM(deposits.amount)`, computed per request. `Tradeline.with_deposits_total` adds the sum as a
correlated subquery, so index is one query (spec-enforced). The overpayment check never uses that preloaded value:
`with_lock` reloads the row, dropping it, so the check always sums fresh under the lock.

**Why:** single source of truth that can't drift; data volume makes caching pointless.
**Rejected:** a cached balance column. It gives faster reads and a lock-free conditional `UPDATE`,
but it can drift and needs more code. Worth revisiting for a read-heavy system at scale.

## 3. PostgreSQL instead of SQLite

**Why:** the overpayment check needs a real row lock. SQLite ignores `with_lock` (no `FOR UPDATE`);
concurrent writers fail with `BusyException` instead of waiting. Verified that Postgres emits `SELECT ... FOR UPDATE`.
**Cost:** reviewers need Postgres running locally (`bin/rails db:setup`).

## 4. Overpayment check: model validation + row lock

The rule (`amount <= outstanding balance`) is a `Deposit` validation, so errors come through `deposit.errors`.
Creation goes through one entry point using standard Rails pessimistic locking:

```ruby
# Tradeline
def create_deposit(attrs)
  with_lock { deposits.create(attrs) }
end
```

**Why:** without the lock, two concurrent $60 deposits against a $100 balance both pass validation and overpay.
`with_lock` makes the second request wait, then see the first deposit in its SQL sum and fail validation.
Only same-tradeline requests block each other.

**Rejected:** a service object (an extra layer for a few lines of logic); a lock in `before_validation` (bypass-proof but hidden);
optimistic locking or `SERIALIZABLE` isolation (the second request errors and needs retry logic);
a DB `CHECK` (can't reference other rows); a trigger (business logic in PL/pgSQL).
No automated concurrency test: it needs threads and non-transactional specs, which is flaky and costly for this scope.

## 5. Fully nested deposit routes

`/tradelines/:tradeline_id/deposits` (index, create) and `/tradelines/:tradeline_id/deposits/:id` (show).
Tradelines restricted to `only: %i[index show]` (unimplemented create/update/destroy routes were exposed).

**Why:** matches the spec's "deposits for a given tradeline"; lookups via `tradeline.deposits.find` 404 on mismatched ids.
**Rejected:** shallow `/deposits/:id` (inconsistent, loses scoping); top-level `/deposits?tradeline_id=` (weaker scoping).

## 6. Jbuilder for JSON, money as two-decimal strings

Shared `_tradeline` / `_deposit` partials; money rendered as `"18500.00"` via `MoneyHelper#money`
(`ActionController::API` needs `include ActionController::Helpers` for view helpers).

**Why:** Rails default, already in the Gemfile, one place to format money. Strings keep decimals exact.
**Rejected:** `as_json` overrides (presentation in models); serializer gems (a new dependency for no gain here).

## 7. Edge cases and error format

- **Tradeline with `amount: nil`:** deposits rejected with a validation error; `outstanding_balance` is `null` (unknown, not zero).
- **Past `deposit_date`:** allowed. The spec only says "most likely" future, and backdated deposits are plausible.
- **Errors:** every error response is `{ "errors": [{ "attribute", "code", "message" }] }` (422 validation, 404, 400 missing params).
  Clients branch on `code` (Rails' error types, e.g. `blank`, `exceeds_outstanding_balance`). `message` is for humans and
  deliberately playful. Messages live in `config/locales/en.yml`, scoped to `Deposit`, so jokes can change without breaking clients or specs.
  **Rejected:** Rails' default `{ "amount": ["..."] }` (clients would have to string-match witty messages).
- **JSON by default:** routes default to `format: :json`, so requests without an `Accept` header don't get 406.

## 8. Request specs instead of controller specs

The starter repo's tradeline controller specs were moved to request specs; `spec/controllers/` is gone.

**Why:** request specs run the real stack (router, JSON default, middleware, Jbuilder). Controller specs bypass it,
needing `render_views` and `format: :json` workarounds, and Rails/RSpec have recommended request specs since Rails 5.
A small routing spec covers what request specs can't: removed routes and missing actions both return 404.
