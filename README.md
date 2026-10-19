# Deposits Exercise


## Requirements

A tradeline on a credit report represents an account, such as a credit card or car loan.

In the codebase, the following exists:

* The `Tradeline` model, which can be used to store tradelines in the database.
* A `Tradeline` controller, which serves both the `index` and `show` routes for tradelines.
* Basic `rspec` tests on the controller with a `tradeline` FactoryBot.

Add in the ability to create deposits for a specific tradeline using a JSON API call. You should store the deposit date (this is most likely a future date), and amount. Expose the outstanding balance for a given tradeline in the JSON output for `TradelinesController#show`, and `TradelinesController#index`. The oustanding balance should be calculated as the `amount` minus all of the deposit amounts.

In addition:

* A deposit should not be able to be created that exceeds the outstanding balance of a tradeline.
* You should return validation errors if a deposit cannot be created.
* Expose endpoints for seeing all deposits for a given tradeline, as well as seeing an individual deposit.

Feel free to add any gems to the `Gemfile`, and touch any of the existing code. For example, if you prefer to use PostgreSQL or MySQL over the included SQLite, or a serializer of your choice, please go ahead. This is not required, but you can be as creative as you want.

This exercise is purely API based, and will not have any frontend components. Please do not spend more than 3 hours on this.

## Setup

The exercise requires Ruby 3.3.0. Simply clone the repo, and run `bundle` to get started. This will install Rails 7.1.2, and the other specified gems.

## Submission

Please do not fork the repo; if forked accidentally, please delete the fork. For review, either of the following methods for submission are preferred:

* Cloning the repository and then uploading it under your Github account for review.
* Zipping up the directory. 

---

# Submission Notes (Lyndsey)

Everything above this line is the original exercise, unchanged.

## Setup

Requires Ruby 3.3.0 and **PostgreSQL**. This submission switches from SQLite for real row-level locking; see [`docs/DECISIONS.md`](docs/DECISIONS.md) §3.

```sh
bundle install
bin/rails db:setup    # creates dev + test databases, loads the schema, seeds sample data
bundle exec rspec
bin/rails server
```

Connects over the local socket as your OS user. Point `DATABASE_URL` elsewhere if needed.

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/tradelines` | All tradelines, each with `outstanding_balance` |
| `GET` | `/tradelines/:id` | One tradeline, with `outstanding_balance` |
| `GET` | `/tradelines/:tradeline_id/deposits` | A tradeline's deposits, ordered by date |
| `GET` | `/tradelines/:tradeline_id/deposits/:id` | One deposit |
| `POST` | `/tradelines/:tradeline_id/deposits` | Create a deposit: `{ "amount": "40.50", "deposit_date": "2026-12-01" }` |

Money is returned as two-decimal strings (`"2619.54"`), so it stays exact. The outstanding balance subtracts *all* deposits, including future-dated ones.

## Try it

With a fresh `db:setup`, the seeded tradelines have ids 1–6.

```sh
curl localhost:3000/tradelines
curl localhost:3000/tradelines/1
curl localhost:3000/tradelines/1/deposits

# create a deposit
curl -X POST localhost:3000/tradelines/1/deposits \
  -H 'Content-Type: application/json' \
  -d '{"amount": "25.00", "deposit_date": "2026-12-01"}'

# try to overpay
curl -X POST localhost:3000/tradelines/1/deposits \
  -H 'Content-Type: application/json' \
  -d '{"amount": "999999", "deposit_date": "2026-12-01"}'
```

## Errors

Every error response has the same shape. Clients branch on `code`; `message` is for humans.

```json
{ "errors": [{ "attribute": "amount", "code": "exceeds_outstanding_balance",
               "message": "Whoa there, overachiever. That's more than the 2619.54 left on this tradeline." }] }
```

Validation errors are `422`, unknown records `404`, missing params `400`.

## Design decisions

[`docs/DECISIONS.md`](docs/DECISIONS.md) records assumptions, each decision, and the alternatives I rejected. Highlights:
the balance is computed on read, deposit creation takes a row lock so concurrent requests can't overpay, and the tradeline index loads all balances in one query.

## About the seed data

Each seeded tradeline covers a balance edge case (typical, zero, smallest payable, max precision, `nil`). The names are a cover letter in disguise. Try `curl localhost:3000/tradelines/6`.
