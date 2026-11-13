# M3 account endpoint — coverage and parity notes

Scope: [Kirke #32](https://github.com/black-belt-badger/kirke/issues/32) and [Medea #33](https://github.com/black-belt-badger/medea/issues/33).

Sources: [Alpaca GET /v2/account](https://docs.alpaca.markets/us/reference/getaccount-1) and [June 24, 2026 schema update](https://docs.alpaca.markets/us/changelog/2026-06-24-trading-api-00bf221).

This document records **phase one: typed account statuses**; the broader M3 audit remains open.

## Request coverage

| Alpaca contract | Kirke behavior | Status |
| --- | --- | --- |
| `GET` | `GET` | Covered |
| `https://paper-api.alpaca.markets/v2/account` | Fixed HTTPS paper-only host/path | Covered |
| Authentication headers | Environment-based `APCA_API_KEY_ID` and `APCA_API_SECRET_KEY` | Covered |
| Query/path/body parameters: **none** | No account filters or additional request parameters | Covered |
| HTTP 200, one account object | Existing typed decoder; full original JSON via `--out PATH` | Covered |
| Non-2xx / transport failures | Sanitized error codes/messages without secrets or response body | Covered; more negative tests in later M3 work |
| Private account data | Summary omits UUID; `--out` atomically writes owner-only file | Covered |

## Response coverage

| Fields | Existing typed representation | Phase-one refinement |
| --- | --- | --- |
| `status` | Required text | **Required `AccountStatus` enum** |
| `crypto_status` | Optional text | **Optional `AccountStatus` enum**; null/omitted = `Nothing` |
| `id`, `account_number`, `currency` | Required text | Unchanged for now |
| `cash`, `equity`, `buying_power` | Required exact decimal strings | Unchanged; no floating-point conversions |
| `trading_blocked` | Required boolean | Unchanged |
| All other documented fields: margin, option levels, account flags, timestamps, previous balances, deprecated fields | Original provider JSON bytes in `--out` | **Typed field audit deferred** to next M3 phase; no data discarded from full export |

### AccountStatus enum

Both `status` and `crypto_status` refer to the same documented status vocabulary:

`INACTIVE`, `PAPER_ONLY`, `ONBOARDING`, `SUBMITTED`, `SUBMISSION_FAILED`, `ACTION_REQUIRED`, `ACCOUNT_UPDATED`, `APPROVAL_PENDING`, `APPROVED`, `REJECTED`, `ACTIVE`, `ACCOUNT_CLOSED`, `ACCOUNT_CLOSED_PENDING`, `LIMITED`.

Every recognized value has an explicit constructor. `StatusOther Text` captures **future/unrecognized strings** without rejecting otherwise-valid responses. `statusValue` and JSON encoding reproduce the exact upstream spelling. Non-string statuses are rejected, rather than coerced. `status` is required, while `crypto_status` is optional.

The default CLI summary still prints the raw enum spelling (e.g. `Status: ACTIVE`, `Crypto status: PAPER_ONLY`); `--out` remains byte-for-byte original JSON. No new flags are added.

**Not in scope for this PR:** interpreting a non-`ACTIVE` status as a guaranteed trading capability; relaxing `account_number` nullability or handling all documented account response fields; choosing new summary/detail formatting or shell completion. Those require further M3 refinement. No paper trading or order-write capability is introduced.

## Kirke–Medea parity decision

The observable CLI contract is the same: default concise summary, exact status spelling, optional crypto-status display, owner-only complete JSON via `--out`; both implementations should use a typed enum with a forward-compatible unknown-value case. Haskell and Rust internals may differ.
