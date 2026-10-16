# Threats: Supply Chain (Hex Dependencies)

Scope: everything compiled into a consumer's release because it depends on
`noizu_clickup`. Locked tree inspected 2026-10-17 (v0.1.0, `mix.lock`).

## Dependency inventory

| Dep | Version (locked) | Scope | Why |
|---|---|---|---|
| `req` | 0.7.5 | **runtime** | HTTP client |
| `jason` | 1.4.5 | **runtime** | JSON codec |
| `plug` | 1.20.3 | test only | `Req.Test` stubs |
| `ex_doc` | 0.40.4 | dev only | docs |

Mandatory transitive closure of `req`: `finch` 0.24.0 → `mint`, `nimble_pool`,
`nimble_options`, `telemetry`, `mime` 2.0.7; plus `castore`/`cacerts` for TLS
roots. Optional req deps (brotli, nimble_csv) are not unlocked here except as
their own trees require.

## T-004 (Medium) — a compromised Hex package runs inside every consumer

**Finding.** Any compromised or maliciously updated package in the closure —
direct (`req`, `jason`) or transitive (`mint`, `castore`, …) — executes with
the consumer's full privileges and sees the ClickUp token on every call. This
is the classic Hex/typosquat/registry risk; severity is Medium because the
library cannot sandbox its deps, only shrink and pin them.

**Mitigations in place:**

- **Minimal runtime surface** — exactly two runtime deps; `plug` and `ex_doc`
  are scoped to `:test` / `:dev` and never ship in consumer releases.
- **`mix.lock` committed** — every package pinned with name, version, and
  Hex **sha256 checksum**; builds are reproducible and a tampered artifact
  fails checksum verification.
- **No exotic sources** — no git/path/override deps; everything from `hexpm`.
- **Pure Elixir** — no NIFs, no ports, no `System.cmd/1` anywhere in the tree
  we control; the only "system" call surface is `:crypto` (OTP, BSL'd).
- **Small blast radius by design** — the library performs no dynamic `Code`
  evaluation and no filesystem access.

**Residual risk (accepted):** Hex registry compromise or a malicious
*upstream update* within a version range only surfaces at lockfile-change
review. Revisit triggers: wide adoption of the package, or adding a third
runtime dep.

**Standing guidance (this repo):**

- Any `mix.lock` diff in a PR is reviewed as a security change (who bumped,
  why, changelog of the new version).
- Consumers are advised to run `mix hex.audit` (retired-package check) and
  keep `deps.checksum`/`mix deps.audit`-style checks in their CI; the library
  cannot run these for them.
- `deps/` is gitignored and never committed; only `mix.exs` + `mix.lock`
  represent the dependency set.

## Non-elastic risks noted for completeness

- **`base_url` + `req_options`** mean a consumer's own config can route
  traffic anywhere — supply chain adjacent, but covered under T-006
  ([token-handling.md](token-handling.md)).
- **CI** currently runs the hermetic ExUnit suite only (no network); no
  third-party actions fetch secrets into the build.
