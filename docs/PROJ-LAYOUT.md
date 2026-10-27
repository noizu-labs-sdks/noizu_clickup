# Project Layout

<!-- 〚📁:cb5aa103-6799-5e0c-a34d-d62f41224891〛 noizu_clickup:proj_layout :: Navigable project tree — lib/, test/, docs/ with per-directory breakdowns in layout/. -->

`noizu_clickup` is a single-purpose Hex library: a ClickUp API v2 client built on
[`Req`](https://hex.pm/packages/req). It is designed contract-first —
[`docs/API-CONTRACT.md`](API-CONTRACT.md) is the source of truth for endpoint
coverage, pagination, errors, and retry behavior.

```text
noizu_clickup/
├── lib/                              # Library source → [layout/lib.md](layout/lib.md)
│   ├── noizu/clickup.ex              # Umbrella module: usage docs + module map
│   └── noizu/clickup/                # One module per API resource (16 modules)
├── test/                             # ExUnit suites → [layout/test.md](layout/test.md)
│   ├── noizu/clickup/*.exs           # One suite per resource module
│   ├── support/case.ex               # `Req.Test`-based case template (no live HTTP)
│   └── test_helper.exs               # ExUnit bootstrap
├── docs/                             # Project documentation
│   ├── API-CONTRACT.md               # Contract-first endpoint/behavior spec
│   ├── PROJ-LAYOUT.md                # This file (+ .summary.md companion)
│   ├── PROJ-ARCH.md                  # Architecture overview (+ .summary.md)
│   ├── PROJ-SCHEMA.md                # Structured-data inventory (+ .summary.md)
│   ├── THREAT-MODEL.md               # Living threat model (+ .summary.md)
│   ├── layout/                       # Detailed per-directory breakdowns
│   ├── arch/                         # Request lifecycle + errors/retry detail
│   └── threats/                      # Threat-model detail sections
├── .formatter.exs                    # Elixir formatter config (line length)
├── .gitignore                        # _build/, deps/, doc/, cover/, tarballs
├── CHANGELOG.md                      # Dated work log, newest first
├── LICENSE                           # MIT
├── README.md                         # Entry point: install, quickstart, error model
├── mix.exs                           # Project, deps, Hex package, ExDoc config
└── mix.lock                          # Locked dependency versions
```

`_build/` and `deps/` are Mix working directories (gitignored), not project content.

## Key Files

| File | Role |
|------|------|
| `lib/noizu/clickup.ex` | Start here — module map and calling conventions |
| `lib/noizu/clickup/client.ex` | `Noizu.ClickUp.Client` config struct every call takes |
| `lib/noizu/clickup/request.ex` | Internal HTTP layer (all modules go through it) |
| `docs/API-CONTRACT.md` | The contract the code implements — kept in sync |
| `mix.exs` | `req ~> 0.7` and `jason ~> 1.4` are the only runtime deps |

## Files Requiring Setup

None in-repo — this is a library, not an application. Consumers supply the
ClickUp token themselves, e.g. `Noizu.ClickUp.Client.new(token: System.fetch_env!("CLICKUP_TOKEN"))`
(personal token, default auth style) or an OAuth access token with `auth_style: :bearer`.
There is no `.envrc` / `.env.example` in this repository.
