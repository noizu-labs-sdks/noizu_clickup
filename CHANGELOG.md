# Changelog

All notable changes to this project are documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: SemVer.

## Unreleased

### Security
- `Noizu.ClickUp.Client` has a redacting `Inspect` impl (T-001): `inspect/2` masks the token
  to a ≤4-character prefix + `[REDACTED]`, so debug logs, telemetry, and crash reports no
  longer print the raw credential. Error paths verified to never surface the token or the
  OAuth `client_secret` (`Noizu.ClickUp.RedactionTest`).
- Every resource id is URI-encoded into its URL path via a shared path-segment
  helper on the internal request module (T-005): a crafted id like `1/../../team?x=1`
  can no longer traverse the path or inject a query (`Noizu.ClickUp.PathEncodingTest`).
- 429 retry hardening: waits are clamped to `0..retry_cap_ms` for negative, past, garbage,
  and far-future reset values; small `X-RateLimit-Reset` values are honored as
  seconds-until-reset instead of being misread as past epochs; `Retry-After` (seconds) is
  honored as a fallback; the sleep is injectable (`Client` `:retry_sleep`) for tests
  (`Noizu.ClickUp.ErrorRateLimitTest`). Also fixes the header lookup against Req 0.7's
  map-shaped response headers — the reset header was silently ignored and the retry always
  slept the fixed 1 s default.
- Webhook docs (T-003 guidance, no new crypto — scheme is ClickUp's): the `Webhook`
  moduledoc and README now instruct consumers to verify against the **raw** request body
  and dedupe on `webhook_id` + `event` + `history_items[].id`.

### Added
- Project docs: layout map (`docs/PROJ-LAYOUT.md` + `docs/layout/`), architecture overview
  (`docs/PROJ-ARCH.md` + `docs/arch/`), threat model (`docs/THREAT-MODEL.md` + `docs/threats/`),
  and durable doc pointers (`.meta/pointers.yaml`).
- CI: GitHub Actions workflow (format check, `--warnings-as-errors` compile, tests,
  `mix hex.audit`) on Elixir 1.15/OTP 25 and 1.18/OTP 27 for push/PR on develop, stage, main.

### Changed
- Doc sweep: added `docs/PROJ-SCHEMA.md` + summary (structured-data inventory — wire shapes,
  Client/Error structs, app-env config; no persistence layer exists), recorded the two
  security suites in `docs/layout/test.md`, corrected the suite count in
  `PROJ-LAYOUT.summary.md`, and listed all docs in both layout trees. Follow-up:
  minted the missing doc-pointer for the new schema doc (marker in `PROJ-SCHEMA.md`
  + record in `.meta/pointers.yaml`; `build --check` clean at 9 declarations).
- Moved the project to the `noizu-labs-sdks` GitHub org: the source/homepage/package links
  in `mix.exs` now point at `github.com/noizu-labs-sdks/noizu_clickup`.

## 0.1.0 - 2026-10-17

Initial release. Contract-first client for the ClickUp API v2 (see `docs/API-CONTRACT.md`).

### Added
- `Noizu.ClickUp.Client` — explicit config struct (token, auth style `:personal`/`:bearer`,
  base URL, Req options); app-env defaults optional, no global state.
- Auth: personal token (`pk_...`, raw header) and OAuth bearer; `Noizu.ClickUp.OAuth`
  authorize-URL + code exchange helpers.
- Resources: authorized user + workspaces, spaces, folders, lists, tasks (CRUD, filtered
  team tasks, subtask support), task comments, custom fields (list/set/clear value), task and
  list members, space tags + task tags, time tracking entries (incl. start/stop), webhooks.
- Pagination: page-based `get_team_tasks/3` plus `stream_team_tasks/3`; cursor-based
  `list_task_comments/3` plus `stream_task_comments/3`.
- Errors: `{:error, %Noizu.ClickUp.Error{status, code, message}}` decoded from ClickUp's
  `err`/`ECODE` bodies; bounded 429 retries honoring `X-RateLimit-Reset`.
- Webhooks: `Noizu.ClickUp.Webhook` CRUD plus `verify_signature/3` (X-Signature = hex
  HMAC-SHA256 of the raw body, constant-time compare).
- Requires `req ~> 0.7` (tested against 0.7.x; query encoding is built around 0.7 behaviour).
