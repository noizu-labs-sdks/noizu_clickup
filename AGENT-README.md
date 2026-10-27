# AGENT-README

> Orientation for AI coding agents working in this repo. Human docs: README.md (plus docs/API-CONTRACT.md — the exact coverage contract).

## Type

elixir-lib (Hex package, API client)

## Purpose

Elixir client for the ClickUp API v2 — workspaces, spaces, folders, lists, tasks (incl. subtasks), comments, custom fields, members, tags, time tracking, and signed webhooks. Built on Req, contract-first.

## Stack

Elixir ~> 1.15. Deps: `req` (~> 0.7), `jason`; `plug` test-only. Typed errors (`Noizu.ClickUp.Error`), pagination pages + lazy `*_stream` variants, bounded 429 retries honoring `X-RateLimit-Reset`.

## Dev mode

```bash
mix deps.get
mix test
```

## Ports / URLs

- none (library/CLI)

## Tests

```bash
mix test    # Req.Test stubs; no live network
```

## Gotchas

- `CLICKUP_TOKEN` env feeds the quickstart (`Client.new(token: ...)`); pass `auth_style: :bearer` for OAuth tokens (default auth is the `pk_...` personal-token header style).
- Webhook signature verification signs the body only (no timestamp): verify against the RAW request body (pre-`Plug.Parsers`) and dedupe deliveries — see `docs/threats/webhook-signature.md` (T-003).
