# Layout: lib/

All library code lives under `lib/noizu/`. One module per API resource; every
public function takes an explicit `%Noizu.ClickUp.Client{}` and returns
`{:ok, map}` or `{:error, %Noizu.ClickUp.Error{}}`. Responses are decoded JSON
(string-keyed maps), unmodified.

```text
lib/
└── noizu/
    ├── clickup.ex            # Umbrella module: usage docs + module map
    └── clickup/
        ├── client.ex         # Config struct: token, auth style, base URL, Req options
        ├── request.ex        # Internal HTTP layer: Req wiring, retries, error shaping
        ├── error.ex          # Error struct: status / code / message
        ├── oauth.ex          # OAuth 2.0 authorize URL + authorization-code exchange
        ├── workspace.ex      # Authorized workspaces ("teams" in the API)
        ├── user.ex           # The user tied to the client's token
        ├── space.ex          # Spaces within a workspace
        ├── folder.ex         # Folders within a space
        ├── list.ex           # Lists in folders or folderless in spaces
        ├── task.ex           # Task CRUD, filtered team tasks, pagination streams
        ├── comment.ex        # Task comments (cursor: start + start_id), stream
        ├── custom_field.ex   # Accessible definitions; get/set/clear task values
        ├── member.ex         # Members with explicit access to a task/list
        ├── tag.ex            # Space-level tag CRUD + task tagging
        ├── time_entry.ex     # Time entries and timers (Unix ms timestamps)
        └── webhook.ex        # Webhook CRUD + HMAC-SHA256 signature verification
```

## Notes

- **`client.ex`** — `new/0` reads optional defaults from application env; no
  global state is required. The API itself uses
  `Authorization: <token>` (personal `pk_…` token, the default) or
  `Authorization: Bearer <token>` (`auth_style: :bearer`, OAuth).
- **`request.ex`** — every resource module routes through this single layer:
  JSON encoding/decoding, 429 retry honoring `X-RateLimit-Reset` (bounded),
  pagination plumbing, and `Noizu.ClickUp.Error` shaping. It is `@moduledoc false`.
- **`error.ex`** — `status` is the HTTP status (or `nil` for transport failures);
  `code`/`message` carry the API error body.
- **`webhook.ex`** — `verify_signature/3` compares the `X-Signature` header
  (lowercase hex HMAC-SHA256) against the **raw request body**, keyed with the
  secret returned at webhook creation.
