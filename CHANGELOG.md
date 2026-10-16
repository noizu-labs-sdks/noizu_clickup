# Changelog

All notable changes to this project are documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: SemVer.

## Unreleased

### Added
- Project docs: layout map (`docs/PROJ-LAYOUT.md` + `docs/layout/`), architecture overview
  (`docs/PROJ-ARCH.md` + `docs/arch/`), threat model (`docs/THREAT-MODEL.md` + `docs/threats/`),
  and durable doc pointers (`.meta/pointers.yaml`).

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
