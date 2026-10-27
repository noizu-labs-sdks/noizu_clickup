# Project Layout — Summary

```text
noizu_clickup/
├── lib/                        # Library source → layout/lib.md
│   ├── noizu/clickup.ex        # Umbrella module + module map
│   └── noizu/clickup/          # 16 modules: client, request, error, oauth,
│                               #   workspace, user, space, folder, list, task,
│                               #   comment, custom_field, member, tag,
│                               #   time_entry, webhook
├── test/                       # ExUnit suites → layout/test.md
│   ├── noizu/clickup/*.exs     # 13 suites: one per resource group + client,
│   │                           #   oauth, error/retry, redaction, path-encoding
│   ├── support/case.ex         # Req.Test case template
│   └── test_helper.exs
├── docs/                       # API-CONTRACT.md, PROJ-LAYOUT/ARCH/SCHEMA.md,
│                               #   THREAT-MODEL.md (+ .summary.md), layout/, arch/, threats/
├── .formatter.exs              # Formatter config
├── .gitignore                  # _build/, deps/, doc/, cover/, tarballs
├── CHANGELOG.md                # Dated work log
├── LICENSE                     # MIT
├── README.md                   # Entry point
├── mix.exs                     # Project, deps, Hex package, ExDoc
└── mix.lock                    # Locked deps
```

Gitignored working dirs: `_build/`, `deps/`, `doc/`, `cover/`, `/tmp/`.
