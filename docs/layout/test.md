# Layout: test/

ExUnit suites. All HTTP is faked through `Req.Test` — no suite touches the live
ClickUp API, so the set runs offline and hermetic.

```text
test/
├── noizu/clickup/
│   ├── client_test.exs              # Client struct defaults + application env
│   ├── error_rate_limit_test.exs    # Error shaping + 429 retry behavior
│   ├── oauth_test.exs               # Authorize URL + code exchange
│   ├── user_workspace_test.exs      # User + Workspace endpoints
│   ├── space_folder_list_test.exs   # Space, Folder, List endpoints
│   ├── task_test.exs                # Task CRUD, team-task queries, streams
│   ├── comment_test.exs             # Comments + cursor pagination
│   ├── custom_field_test.exs        # Definitions, set/clear values
│   ├── member_tag_test.exs          # Members + tags
│   ├── time_entry_test.exs          # Time entries + timers
│   └── webhook_test.exs             # Webhook CRUD + signature verification
├── support/
│   └── case.ex                      # `Noizu.ClickUp.Case`: Req.Test case template
└── test_helper.exs                  # ExUnit bootstrap
```

## Notes

- **`support/case.ex`** — compiled only under `:test` (see `elixirc_paths/1`
  in `mix.exs`); supplies `Req.Test` wiring so each suite mounts a fake
  ClickUp endpoint instead of a real base URL.
- Suite names mirror the modules they cover; the split `error_rate_limit_test.exs`
  and the combined `member_tag_test.exs` / `space_folder_list_test.exs` /
  `user_workspace_test.exs` group small resource pairs.
