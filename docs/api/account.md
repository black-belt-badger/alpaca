# GET /v2/account — M3 API coverage and parity

Scope: [Kirke #32](https://github.com/black-belt-badger/kirke/issues/32), paired with [Medea #33](https://github.com/black-belt-badger/medea/issues/33).

Sources checked 2026-11-13: [Alpaca GET /v2/account](https://docs.alpaca.markets/us/reference/getaccount-1), its [current machine-readable OpenAPI definition](https://docs.alpaca.markets/us/reference/getaccount-1.md), and the [June 2026 schema changes](https://docs.alpaca.markets/us/changelog/2026-06-24-trading-api-00bf221).

This covers **all 34 properties in the current published Account schema**. Phase 1 introduced the status enum; phase 2 covers remaining field types and nullability. It does **not** decide the later shared CLI/diagnostics design.

## Request contract

| Requirement | Kirke implementation |
| --- | --- |
| `GET https://paper-api.alpaca.markets/v2/account` | Fixed, HTTPS, read-only paper host |
| API credentials | From environment; never printed or committed |
| Query, path, body parameters | **None**; no invented account filters |
| Success body | One JSON object with typed, validated known fields |
| Errors | Transport and HTTP failures sanitized; no raw response body in errors |
| Data confidentiality | Account ID excluded from terminal summary, complete original body written atomically with owner-only permissions via `--out PATH` |

## Documented response fields

The current OpenAPI `required` list has **only `id` and `status`**; notably, `account_number` may be null. All other documented properties are optional. `Maybe` retains **present false/zero** separately from absent/null, while the original unmodified `--out` bytes preserve the distinction between **absent** and **explicit null** when callers need it.

| Alpaca JSON property | Haskell representation | Requirement | Model |
| --- | --- | --- | --- |
| `id` | `Text (UUID wire string)` | required | `Account` |
| `status` | `AccountStatus` | required | `Account` |
| `account_number` | `Maybe Text (nullable)` | optional / nullable | `Account` |
| `crypto_status` | `Maybe AccountStatus` | optional | `Account` |
| `currency` | `Maybe Text` | optional | `Account` |
| `cash` | `Maybe Text (decimal string)` | optional | `Account` |
| `equity` | `Maybe Text (decimal string)` | optional | `Account` |
| `buying_power` | `Maybe Text (decimal string)` | optional | `Account` |
| `trading_blocked` | `Maybe Bool` | optional | `Account` |
| `account_blocked` | `Maybe Bool` | optional | `AccountDetails` |
| `accrued_fees` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `balance_asof` | `Maybe Text (date string)` | optional | `AccountDetails` |
| `created_at` | `Maybe Text (RFC3339 wire string)` | optional | `AccountDetails` |
| `initial_margin` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `intraday_adjustments` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `last_equity` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `last_maintenance_margin` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `long_market_value` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `maintenance_margin` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `multiplier` | `Maybe Text (string)` | optional | `AccountDetails` |
| `non_marginable_buying_power` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `options_approved_level` | `Maybe OptionsLevel` | optional | `AccountDetails` |
| `options_buying_power` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `options_trading_level` | `Maybe OptionsLevel` | optional | `AccountDetails` |
| `pending_reg_taf_fees` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `pending_transfer_in` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `pending_transfer_out` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `portfolio_value` | `Maybe Text (deprecated decimal string)` | optional | `AccountDetails` |
| `regt_buying_power` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `short_market_value` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `shorting_enabled` | `Maybe Bool` | optional | `AccountDetails` |
| `sma` | `Maybe Text (decimal string)` | optional | `AccountDetails` |
| `trade_suspended_by_user` | `Maybe Bool` | optional | `AccountDetails` |
| `transfers_blocked` | `Maybe Bool` | optional | `AccountDetails` |

## Enums and forward compatibility

- `status` and `crypto_status`: the shared `AccountStatus` enum covers `INACTIVE`, `PAPER_ONLY`, `ONBOARDING`, `SUBMITTED`, `SUBMISSION_FAILED`, `ACTION_REQUIRED`, `ACCOUNT_UPDATED`, `APPROVAL_PENDING`, `APPROVED`, `REJECTED`, `ACTIVE`, `ACCOUNT_CLOSED`, `ACCOUNT_CLOSED_PENDING`, and `LIMITED`. `StatusOther Text` preserves future non-listed strings.
- `options_approved_level` and `options_trading_level` are **integer enums**, not strings: `0` disabled, `1` covered call/cash-secured put, `2` long call/put, `3` spreads/straddles. `OptionsOther Integer` preserves future integer levels. Fractions, strings, bools and objects are invalid.

**Exact financial decimals:** all Alpaca monetary fields in the schema are JSON **strings**, retained in `Text`. There is no float/Double conversion, rounding, or normalization. `created_at` and `balance_asof` preserve original text spelling, including fractional-second precision.

**Forward-compatible fields:** a successful API body may include additional undocumented properties (e.g., `effective_buying_power`, `position_market_value`, configuration objects). The decoder ignores unknown properties rather than failing; `--out` saves the *original complete bytes* without losing them. Legacy fields omitted or removed in recent API versions are not made mandatory.

## CLI and tests

- No CLI flag or default-format changes. `kirke account` prints a concise summary, displaying `not provided` for omitted/null optional fields. `kirke account --out PATH` stores the original complete JSON privately.
- Offline tests cover a synthetic full-schema response, all 34 types, extremely long decimal strings, flags, present/missing/null/zero, option enums and future integer variants, invalid property types, unknown properties, unexpected account statuses, empty/malformed bodies, and existing safe HTTP behavior.
- An opt-in `./scripts/it.sh` covers the actual paper API with private credentials; nothing secret or account-specific belongs in CI or fixtures.

**Follow-up outside this phase:** formal UUID and date-time string *format validation*, response provenance/field presence as a general abstraction, optional business diagnostics, status coloring, Unix stream conventions, output-mode flags, shell completion and cross-language parity. See [cross-cutting Kirke #44](https://github.com/black-belt-badger/kirke/issues/44) and [Medea #44](https://github.com/black-belt-badger/medea/issues/44).

Do not close the parent account M3 issue until full endpoint acceptance has been reviewed and Medea is brought to parity.
