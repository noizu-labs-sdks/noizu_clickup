# Noizu.ClickUp — API Contract

Elixir client contract for the **ClickUp API v2**. Every fact below was verified against the
official reference at `developer.clickup.com` (2026-10-17); endpoint pages are cited inline.
The client follows this document; deviations are bugs.

---

## 1. Authentication

Source: `developer.clickup.com/docs/authentication`.

| Mode | Header value | Notes |
|---|---|---|
| Personal API token | `Authorization: pk_...` — **raw token, no `Bearer` prefix** | Does not expire |
| OAuth 2.0 access token | `Authorization: Bearer {access_token}` | Currently non-expiring (subject to change) |

- **Base URL (all endpoints in this contract):** `https://api.clickup.com/api/v2`
- **OAuth authorize URL (browser step, not an API call):**
  `https://app.clickup.com/api?client_id={client_id}&redirect_uri={redirect_uri}[&state={state}]`
- **OAuth token exchange:** `GET /oauth/token` with `client_id`, `client_secret`, `code`
  (authorization-code grant). Returns an `access_token`. Covered by `Noizu.ClickUp.OAuth`.
- Client design: `Noizu.ClickUp.Client` struct carries `token`, `auth_style` (`:personal` |
  `:bearer`), `base_url`, and `req_options`; it is passed explicitly to every call. App env
  (`Application.get_env(:noizu_clickup, :client)`) is an **optional** default for `new/0` only —
  no global process state.

## 2. API version

**v2 everywhere.** ClickUp's newer v3 surface (Docs 3.0 API) is **not** used; no v3 endpoints
are chosen. All paths in this contract are relative to the v2 base URL.

## 3. Resources and endpoints covered

All confirmed against the linked reference pages. `Response` = 200/2xx body shape (string-keyed
maps, returned as-is by the client).

### 3.1 User & Workspaces
| Operation | Endpoint | Response |
|---|---|---|
| Authorized user | `GET /user` ([getauthorizeduser]) | `{user: {...}}` |
| Authorized workspaces | `GET /team` ([getauthorizedteams]) | `{teams: [...]}` |

### 3.2 Spaces ([getspaces], [createspace], [updatespace], [deletespace])
| Operation | Endpoint |
|---|---|
| List in workspace | `GET /team/{team_id}/space` (`archived` query) → `{spaces: [...]}` |
| Get / Update / Delete | `GET|PUT|DELETE /space/{space_id}` (DELETE → `{}`) |
| Create | `POST /team/{team_id}/space` → Space object (top-level, no wrapper) |

### 3.3 Folders ([getfolders], [createfolder], [updatefolder], [deletefolder])
| Operation | Endpoint |
|---|---|
| List in space | `GET /space/{space_id}/folder` (`archived`) → `{folders: [...]}` (subfolders flat, `parent_folder` field) |
| Get / Update / Delete | `GET|PUT|DELETE /folder/{folder_id}` (update = rename only; `parent_folder_id` ignored) |
| Create | `POST /space/{space_id}/folder` (optional `parent_folder_id`) → Folder object |

### 3.4 Lists ([getlists], [getfolderlesslists], [createlist], [updatelist], [deletelist])
| Operation | Endpoint |
|---|---|
| List in folder | `GET /folder/{folder_id}/list` (`archived`) → `{lists: [...]}` |
| List in space (folderless) | `GET /space/{space_id}/list` (`archived`) → `{lists: [...]}` |
| Create in folder / in space | `POST /folder/{folder_id}/list` · `POST /space/{space_id}/list` |
| Get / Update / Delete | `GET|PUT|DELETE /list/{list_id}` (DELETE → `{}`) |

`status` on lists is the **List color**, not task statuses.

### 3.5 Tasks ([createtask], [gettask], [updatetask], [deletetask], [getfilteredteamtasks])
| Operation | Endpoint |
|---|---|
| Create (in list) | `POST /list/{list_id}/task` — required: `name`; `parent` makes a **subtask** (same list) |
| Get | `GET /task/{task_id}` — query: `custom_task_ids` + `team_id`, `include_subtasks`, `include_markdown_description`; task object is **top-level** (no wrapper); `subtasks` array only when requested |
| Update | `PUT /task/{task_id}` — partial body; custom-field values must go through 3.7 |
| Delete | `DELETE /task/{task_id}` — **204**, empty body |
| Filtered team tasks | `GET /team/{team_id}/task` — see §4 pagination; filters: `statuses[]`, `assignees[]`, `tags[]`, `space_ids[]`, `project_ids[]`, `list_ids[]`, `parent`, `subtasks`, `include_closed`, `order_by`, `reverse`, `due_date_gt/lt`, `date_created_gt/lt`, `date_updated_gt/lt`, `date_done_gt/lt`, `custom_fields` (JSON string), `custom_items[]` |

Subtask coverage: `include_subtasks` on Get, `subtasks`/`parent` filters on team tasks, and
`parent` on create. `custom_task_ids=true` requires `team_id` on task endpoints that accept it.

### 3.6 Comments ([gettaskcomments], [createtaskcomment], [updatecomment], [deletecomment], docs/task-comments-pagination)
| Operation | Endpoint |
|---|---|
| List task comments | `GET /task/{task_id}/comment` — newest first, 25/page; cursor `start` (date ms) **+** `start_id` (comment id); → `{comments: [...]}` |
| Create task comment | `POST /task/{task_id}/comment` — required `comment_text`, `notify_all` → `{id, hist_id, date}` |
| Update comment | `PUT /comment/{comment_id}` — body `comment_text`, `assignee`, `resolved` |
| Delete comment | `DELETE /comment/{comment_id}` → `{}` |

(List/chat-view comment endpoints are out of scope; §6.)

### 3.7 Custom Fields ([getaccessiblecustomfields], [setcustomfieldvalue], [removecustomfieldvalue])
| Operation | Endpoint |
|---|---|
| Accessible fields on a list | `GET /list/{list_id}/field` → `{fields: [...]}` |
| Set value on task | `POST /task/{task_id}/field/{field_id}` — body `{value: ...}` (shape per field type) → `{}` |
| Clear value on task | `DELETE /task/{task_id}/field/{field_id}` → `{}` (clears data, not the option) |

`value` typing (per docs): string (URL/email/phone/text/dropdown-UUID), number (number/money),
integer (emoji/date-ms), boolean (button), `[UUID]` (labels), `{add, rem}` (relationship/people),
`{current: n}` (manual progress), `{location, formatted_address}` (location), `null` clears.

### 3.8 Members ([gettaskmembers], [getlistmembers])
| Operation | Endpoint |
|---|---|
| Task members (explicit access) | `GET /task/{task_id}/member` → `{members: [...]}` |
| List members (explicit access) | `GET /list/{list_id}/member` → `{members: [...]}` |

### 3.9 Tags ([getspacetags], [createspacetag], [editspacetag], [addtagtotask])
| Operation | Endpoint |
|---|---|
| List space tags | `GET /space/{space_id}/tag` → `{tags: [{name, tag_fg, tag_bg}]}` |
| Create space tag | `POST /space/{space_id}/tag` — body `{tag: {name, tag_fg, tag_bg}}` → `{}` |
| Rename/recolor | `PUT /space/{space_id}/tag/{tag_name}` — body `{tag: {...}}`. **Doc inconsistency:** schema says `fg_color`/`bg_color`, examples show `tag_fg`/`tag_bg`. Client passes the body through unchanged; callers choose keys. |
| Delete space tag | `DELETE /space/{space_id}/tag/{tag_name}` |
| Add tag to task | `POST /task/{task_id}/tag/{tag_name}` → `{}` |
| Remove tag from task | `DELETE /task/{task_id}/tag/{tag_name}` |

### 3.10 Time Tracking ([gettimeentrieswithinadaterange], [createatimeentry], [getsingulartimeentry], [updateatimeentry], [deleteatimeentry], [startatimeentry], [stopatimeentry])
| Operation | Endpoint |
|---|---|
| Entries in date range | `GET /team/{team_id}/time_entries` — `start_date`/`end_date` (unix ms), `assignee`, `include_task_tags`, `include_location_names`, single location filter (`space_id`/`folder_id`/`list_id`/`task_id`), `is_billable`; → `{data: [...]}`. **No pagination.** Default window: last 30 days, current user. |
| Create entry | `POST /team/{team_id}/time_entries` — required `start` (ms) + `duration` (ms); flat response (no `data` wrapper) |
| Get single entry | `GET /team/{team_id}/time_entries/{timer_id}` → `{data: {...}}` |
| Update entry | `PUT /team/{team_id}/time_entries/{timer_id}` — `tags` (required), `tag_action` (`replace`/`add`/`remove`), `start`+`end` together, `billable`, `tid` |
| Delete entry | `DELETE /team/{team_id}/time_entries/{timer_id}` → `{data: {...}}` |
| Start timer | `POST /team/{team_id}/time_entries/start` → `{data: {...}}` |
| Stop timer | `POST /team/{team_id}/time_entries/stop` → `{data: {...}}` |

Negative `duration` = timer currently running. `custom_task_ids`+`team_id` accepted as query.

### 3.11 Webhooks ([getwebhooks], [createwebhook], [updatewebhook], [deletewebhook], docs/webhooksignature)
| Operation | Endpoint |
|---|---|
| List (created by current user) | `GET /team/{team_id}/webhook` → `{webhooks: [...]}` (each has `secret`, `health: {status, fail_count}`) |
| Create | `POST /team/{team_id}/webhook` — required `endpoint`, `events` (`"*"` or event names); one location (`space_id`/`folder_id`/`list_id`/`task_id`) → `{id, webhook: {...secret...}}` |
| Update | `PUT /webhook/{webhook_id}` — `endpoint`, `events`, `status` → `{id, webhook}` |
| Delete | `DELETE /webhook/{webhook_id}` → `{}` |

**Signature verification (contract):** ClickUp sends header `X-Signature` =
**lowercase hex of HMAC-SHA256(webhook.secret, raw_request_body)** (no `t=...` prefix scheme —
the whole hex digest). `Noizu.ClickUp.Webhook.verify_signature/3` recomputes the digest over the
**raw, unparsed** body and compares constant-time (`:crypto.hash_equals/2`); length mismatch →
`false`. Always verify against raw bytes, not re-serialized JSON.

## 4. Pagination

| Surface | Model | End-of-data |
|---|---|---|
| Filtered team tasks | `page` integer **starting at 0**, ≤ 100 tasks/page ([getfilteredteamtasks]) | Response carries `last_page` boolean (documented by ClickUp's task guide; the OpenAPI schema only *requires* `tasks`). Client treats `last_page == true` **or** an empty `tasks` page as the end. |
| Task comments | Cursor pair: `start` = `date` (ms) of last comment, `start_id` = its `id`; newest→oldest, 25/page default ([docs/task-comments-pagination]) | Empty `comments` page. The API has no `last_page` on comments. |
| Spaces, folders, lists, members, tags, webhooks, time entries | None — full array in one response | n/a |

Client surface: every paginated call returns `{:ok, page_map}` (the raw envelope);
`Noizu.ClickUp.Task.stream_team_tasks/3` and `Noizu.ClickUp.Comment.stream_task_comments/2`
return a lazy `Stream` of individual tasks/comments. **Streams raise `%Noizu.ClickUp.Error{}`
on request failure** (a `Stream` cannot return `{:error, _}` per element); use the paginated
functions for tuple semantics.

Query-array encoding: list params (`statuses`, `assignees`, `tags`, `space_ids`, `project_ids`,
`list_ids`, `custom_items`) are sent as `statuses[]=a&statuses[]=b` (ClickUp's documented form);
`custom_fields` is a caller-supplied JSON string.

## 5. Errors and rate limits

**Error body** (confirmed by [setcustomfieldvalue]; catalog at [docs/common_errors]):

```json
{"err": "Token invalid", "ECODE": "OAUTH_019", "message": "..."}
```

Decoded to `{:error, %Noizu.ClickUp.Error{status, code, message}}`:
- `status` — HTTP status (integer), or `nil` for transport failures (connection refused, timeout)
- `code` — ClickUp `ECODE` string when present (`OAUTH_017` missing auth header, `OAUTH_019`/
  `OAUTH_021`/`OAUTH_025`/`OAUTH_077` revoked token, `OAUTH_023`/`026`/`027`/`029`–`045`
  unauthorized workspace, `OAUTH_010` bad client, `OAUTH_171` duplicate webhook config), else `nil`
- `message` — `err`/`message` text, falling back to the decoded body or a generic phrase

**Rate limits** ([docs/rate-limits]): per token, per minute, by workspace plan —
100 (Free/Unlimited/Business), 1,000 (Business Plus), 10,000 (Enterprise+).
Exceeding → **HTTP 429** with headers:

| Header | Meaning |
|---|---|
| `X-RateLimit-Limit` | current limit for the token |
| `X-RateLimit-Remaining` | requests left in window |
| `X-RateLimit-Reset` | window reset, **Unix timestamp** |

**Retry policy (client):** on 429 the client sleeps until `X-RateLimit-Reset` (clamped to
`retry_cap_ms`, default 15 s; missing header → 1 s), then retries; at most `max_retries`
(default 2) retries before returning the 429 as an error. Req's built-in retry is disabled so
this is the single retry layer. Retries are idempotency-safe in practice for ClickUp reads;
mutations retried only on 429, never on 5xx/timeouts.

## 6. Intentionally NOT covered

- Attachments, checklists, task dependencies/links, task moving between lists, merge tasks
- Goals/OKRs, Key Results, Portfolios, Views, Dashboards
- Docs 3.0 (v3 API), Chat, Whiteboards, ClickApps admin, custom task types admin
- Templates (list/folder/task), bulk time-in-status, `Get tracked time` on tasks
- List-comment and chat-view-comment endpoints (task comments only)
- Webhook payload parsing helpers (receiving/verification is `verify_signature/3`; payload
  schemas are the consumer's concern)
- OAuth token refresh (none exists — tokens don't expire)

## 7. Client conventions

- Every public function: `(client, ...path_ids..., payload?, opts \\ [])` →
  `{:ok, map} | {:error, %Noizu.ClickUp.Error{}}`.
- Responses returned as decoded JSON maps with **string keys**, unmodified.
- 2xx with empty body (204, `{}`) → `{:ok, %{})`.
- No global state; `Client.new/0` reads app env only as an optional default.
- Tests: `Req.Test` plug stubs only — no live network, no real tokens.

[getauthorizeduser]: https://developer.clickup.com/reference/getauthorizeduser
[getauthorizedteams]: https://developer.clickup.com/reference/getauthorizedteams
[getspaces]: https://developer.clickup.com/reference/getspaces
[createspace]: https://developer.clickup.com/reference/createspace
[updatespace]: https://developer.clickup.com/reference/updatespace
[deletespace]: https://developer.clickup.com/reference/deletespace
[getfolders]: https://developer.clickup.com/reference/getfolders
[createfolder]: https://developer.clickup.com/reference/createfolder
[updatefolder]: https://developer.clickup.com/reference/updatefolder
[deletefolder]: https://developer.clickup.com/reference/deletefolder
[getlists]: https://developer.clickup.com/reference/getlists
[getfolderlesslists]: https://developer.clickup.com/reference/getfolderlesslists
[createlist]: https://developer.clickup.com/reference/createlist
[updatelist]: https://developer.clickup.com/reference/updatelist
[deletelist]: https://developer.clickup.com/reference/deletelist
[createtask]: https://developer.clickup.com/reference/createtask
[gettask]: https://developer.clickup.com/reference/gettask
[updatetask]: https://developer.clickup.com/reference/updatetask
[deletetask]: https://developer.clickup.com/reference/deletetask
[getfilteredteamtasks]: https://developer.clickup.com/reference/getfilteredteamtasks
[gettaskcomments]: https://developer.clickup.com/reference/gettaskcomments
[createtaskcomment]: https://developer.clickup.com/reference/createtaskcomment
[updatecomment]: https://developer.clickup.com/reference/updatecomment
[deletecomment]: https://developer.clickup.com/reference/deletecomment
[getaccessiblecustomfields]: https://developer.clickup.com/reference/getaccessiblecustomfields
[setcustomfieldvalue]: https://developer.clickup.com/reference/setcustomfieldvalue
[removecustomfieldvalue]: https://developer.clickup.com/reference/removecustomfieldvalue
[gettaskmembers]: https://developer.clickup.com/reference/gettaskmembers
[getlistmembers]: https://developer.clickup.com/reference/getlistmembers
[getspacetags]: https://developer.clickup.com/reference/getspacetags
[createspacetag]: https://developer.clickup.com/reference/createspacetag
[editspacetag]: https://developer.clickup.com/reference/editspacetag
[addtagtotask]: https://developer.clickup.com/reference/addtagtotask
[gettimeentrieswithinadaterange]: https://developer.clickup.com/reference/gettimeentrieswithinadaterange
[createatimeentry]: https://developer.clickup.com/reference/createatimeentry
[getsingulartimeentry]: https://developer.clickup.com/reference/getsingulartimeentry
[updateatimeentry]: https://developer.clickup.com/reference/updateatimeentry
[deleteatimeentry]: https://developer.clickup.com/reference/deleteatimeentry
[startatimeentry]: https://developer.clickup.com/reference/startatimeentry
[stopatimeentry]: https://developer.clickup.com/reference/stopatimeentry
[getwebhooks]: https://developer.clickup.com/reference/getwebhooks
[createwebhook]: https://developer.clickup.com/reference/createwebhook
[updatewebhook]: https://developer.clickup.com/reference/updatewebhook
[deletewebhook]: https://developer.clickup.com/reference/deletewebhook
[docs/common_errors]: https://developer.clickup.com/docs/common_errors
[docs/rate-limits]: https://developer.clickup.com/docs/rate-limits
[docs/task-comments-pagination]: https://developer.clickup.com/docs/task-comments-pagination
