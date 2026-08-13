# CRM Core API Reference

**Audience:** mobile app developers building a client against the CRM backend.
**Scope:** the *core* CRM surface — auth, dashboard, contacts, companies, deals, activities/tasks, search, users, departments, config dropdowns, and file uploads.

Modules deliberately left out of this document (they are not needed to build the core app): `hub`, `assistant`, `imports`, `sequences`, `meeting-schedulers`, `email-templates`, `email-assets`, `email-tracking`, `documents`, `deal-automation-rules`. Ask if you need those later.

---

## 1. Basics

### Base URL

```
{HOST}/api
```

Local dev default: `http://localhost:5000/api` (backend `PORT` defaults to `5000`).

### Content type

All request bodies are JSON (`Content-Type: application/json`) except file uploads and CSV imports, which use `multipart/form-data`.

Body size limit: **50 MB** for JSON/urlencoded. File uploads via `/api/uploads` are capped at **20 MB**.

### CORS

The server allows any origin listed in `ALLOWED_ORIGINS`, **and** any request with no `Origin` header. Native mobile clients (iOS/Android HTTP stacks) send no `Origin`, so they are allowed by default. No CORS work is needed for a native app. A React Native/Expo web build *would* need its origin added to `ALLOWED_ORIGINS`.

### Caching

Every `/api/*` response (except `/api/email-assets`) is sent with:

```
Cache-Control: no-store, no-cache, must-revalidate, proxy-revalidate
Pragma: no-cache
Expires: 0
```

Do your own client-side caching (e.g. React Query / SWR persistence) if you want offline reads.

### Health check

```http
GET /api/health
→ 200 { "success": true, "message": "Server is running" }
```

---

## 2. Response envelopes — READ THIS FIRST

⚠️ **The envelope is not uniform across modules.** This is the single biggest gotcha when writing a client. Do not write one generic `unwrap(response)` helper and assume it works everywhere. The table below is authoritative.

| Module | List | Get one | Create | Update | Delete |
|---|---|---|---|---|---|
| **Contacts** | `{ success, data[], meta }` | `{ success, data }` | `201 { success, data }` | `{ success, data }` | `{ success, message, data }` |
| **Companies** | `{ data[], meta }` | *raw object* + `contacts[]` | `201` *raw object* | *raw object* | `204 No Content` |
| **Deals** | `{ data[], meta }` | *raw object* | `201` *raw object* | *raw object* | `204 No Content` |
| **Activities** | `{ data[], meta }` | *raw object* | `201` *raw object* | *raw object* | `204 No Content` |
| **Auth** | — | `{ success, data }` | — | — | — |
| **Users** | `{ data[] }` | — | `201 { data }` | `{ success, message }` | `{ success, message }` |
| **Departments** | `{ data[] }` | — | `201 { success, data }` | `{ success, data }` | `{ success, message }` |
| **Master dropdowns** | `{ success, data }` | `{ success, data }` | `201 { success, data }` | `{ success, data }` | `{ success, message }` |
| **Search** | `{ success, data }` | — | — | — | — |
| **Reports / Dashboards** | `{ data }` | *raw object* | `201 { data }` | `{ data }` | `{ message }` |
| **Lifecycle stages / Deal stages / MSP options** | *raw array* | — | `201` *raw object* | *raw object* | *raw object* |

### Pagination `meta`

Contacts / Companies / Activities:

```json
{ "page": 1, "limit": 20, "total": 137 }
```

Deals adds aggregate totals across the **whole filtered set** (not just the page) — useful for pipeline headers:

```json
{
  "page": 1,
  "limit": 20,
  "total": 137,
  "totalPages": 7,
  "totalAmount": 4520000,
  "totalWeightedAmount": 1830500
}
```

### Errors

Two shapes exist, depending on the module:

```jsonc
// Shape A — auth, contacts, search, master-dropdowns, departments
{ "success": false, "message": "Contact not found" }

// Shape B — companies, deals, activities, users, reports
{ "error": "Deal not found" }
```

Validation failures (Zod):

```jsonc
// Shape A
{ "success": false, "message": "Validation failed", "errors": [ /* zod issues */ ] }
// Shape B
{ "error": "Validation failed", "details": [ /* zod issues */ ] }
```

**Recommended client helper:**

```ts
const errorMessage = (body: any, fallback = 'Something went wrong') =>
  body?.message ?? body?.error ?? fallback;
```

### Status codes

| Code | Meaning |
|---|---|
| `200` | OK |
| `201` | Created |
| `204` | Deleted (no body) — companies, deals, activities |
| `400` | Validation error / missing required field |
| `401` | Missing, invalid, or expired access token |
| `403` | Role/department not permitted, or operating department archived |
| `404` | Not found (also returned for unknown routes: `{ success: false, message: "API route not found" }`) |
| `409` | Duplicate (contact email / company domain already exists) |
| `429` | Rate limit exceeded |
| `500` | Server error |

---

## 3. Authentication

### 3.1 Model

- **Access token** — a JWT sent as `Authorization: Bearer <token>`. Default lifetime **7 days** (`JWT_ACCESS_EXPIRES_IN`).
- **Refresh token** — an opaque 80-char hex string stored server-side in the `sessions` table. Valid **7 days** from issue. Sent in the JSON body, *not* a header.

The decoded access token payload is:

```json
{
  "user_id": "uuid",
  "organization_id": "uuid",
  "role": "super_admin | admin | normal_user",
  "department_id": "uuid"
}
```

**The department is baked into the token.** Almost every list endpoint is silo'd by `department_id`. To change department the client must call `/api/auth/switch-department` and swap in the new access token — there is no per-request department override.

### 3.2 Login flow

```
POST /api/auth/email-details   (optional, pre-login: fetch departments for the email)
        ↓
POST /api/auth/login           (email + password [+ departmentId])
        ↓  store access_token + refresh_token securely
GET  /api/auth/me              (full profile + permissions + departments)
```

---

### `POST /api/auth/email-details`

Public. Used by the login screen to decide whether to show a department picker before the password step.

**Request**

```json
{ "email": "user@example.com" }
```

**Response `200`**

```json
{
  "success": true,
  "data": {
    "isAdmin": true,
    "departments": [{ "id": "uuid", "name": "Sales" }]
  }
}
```

`isAdmin` is `true` only for `super_admin`. For everyone else, `departments` lists only the departments the user is explicitly assigned to. If the email is unknown, returns `{ isAdmin: false, departments: [] }` — **it does not 404**, so you cannot use this to enumerate accounts.

---

### `POST /api/auth/login`

Public. Rate limits do not apply here.

**Request**

```json
{
  "email": "user@example.com",
  "password": "secret123",
  "departmentId": "uuid"
}
```

- `password` — min 6 chars.
- `departmentId` — optional. Rules:
  - `admin` → **ignored**; always locked to their single primary department.
  - `super_admin` → may pass any department in the org; if omitted, defaults to the alphabetically first active department.
  - `normal_user` → must be a department they're assigned to; if omitted, their oldest assignment is used.

**Response `200`**

```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOi...",
    "refresh_token": "a1b2c3...",
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "first_name": "Jane",
      "last_name": "Doe",
      "role": "normal_user",
      "organization_id": "uuid",
      "department_id": "uuid",
      "department_name": "Sales"
    }
  }
}
```

**Errors `401`** — `{ "success": false, "message": "..." }` with one of:
`Invalid email or password`, `User has no active organization membership`, `Access denied: Selected department is archived.`, `Access denied: You do not have permission to access this department.`

---

### `POST /api/auth/refresh`

Public.

**Request** `{ "refresh_token": "a1b2c3..." }`
**Response `200`** `{ "success": true, "data": { "access_token": "..." } }`
**Error `401`** `{ "success": false, "message": "Invalid or expired refresh token" }`

⚠️ Refresh tokens are **not rotated** — the same refresh token stays valid until it expires (7 days) or logout. The refreshed access token carries the user's **primary membership department**, not whatever department they had switched to. If the user was in a switched department, re-issue with `/switch-department` after refreshing.

**Client pattern:** on any `401`, try refresh once, retry the original request, and if refresh also fails, clear tokens and route to login.

---

### `POST /api/auth/logout`

No auth middleware — it just deletes the session row.

**Request** `{ "refresh_token": "a1b2c3..." }`
**Response `200`** `{ "success": true, "message": "Logged out successfully" }`

Always clear local tokens client-side regardless of the response.

---

### `GET /api/auth/me` 🔒

The main bootstrap call. Fetch on app launch and after every department switch.

**Response `200`**

```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "firstName": "Jane",
      "lastName": "Doe",
      "avatarUrl": "https://.../api/uploads/download?key=uploads/...",
      "organization_id": "uuid",
      "role": "normal_user",
      "position": "Account Executive",
      "phone": "+1 555 0100",
      "departmentId": "uuid",
      "departmentName": "Sales",
      "departments": [{ "id": "uuid", "name": "Sales" }],
      "permissions": {
        "companies":    { "view": true, "edit": true, "delete": true },
        "contacts":     { "view": true, "edit": true, "delete": true },
        "deals":        { "view": true, "edit": true, "delete": true },
        "tasks":        { "view": true, "edit": true, "delete": true },
        "meetings":     { "view": true, "edit": true, "delete": true },
        "calls":        { "view": true, "edit": true, "delete": true },
        "exports":      { "view": true, "edit": true, "delete": true },
        "reports":      { "view": false, "edit": false, "delete": false },
        "calendar":     { "view": true, "edit": true, "delete": true },
        "quarter-view": { "view": true, "edit": true, "delete": true }
      }
    }
  }
}
```

Notes:
- Field casing here is **camelCase**, unlike the `user` object returned by `/login` (snake_case). Normalize on the client.
- All 10 permission modules default to `{true,true,true}` and are then overridden by DB rows. `reports` is force-disabled for anyone who isn't `admin`/`super_admin`.
- `departments` = every active department in the org for `super_admin`; only assigned departments for everyone else.
- **Use `permissions` to drive UI gating** (hide edit/delete buttons). The backend still enforces its own rules — don't rely on the client alone.

---

### `GET /api/auth/team` 🔒

Members of the caller's department — use this to populate owner/assignee pickers.

**Response `200`**

```json
{
  "success": true,
  "data": [
    { "id": "uuid", "email": "...", "first_name": "Jane", "last_name": "Doe", "avatar_url": null, "role": "normal_user" }
  ]
}
```

(snake_case here. `GET /api/users` returns the same people in camelCase with more fields — prefer that one for anything richer than a picker.)

---

### `POST /api/auth/switch-department` 🔒

**Request** `{ "departmentId": "uuid" }`
**Response `200`** `{ "success": true, "data": { "access_token": "..." } }`

Replace the stored access token with the returned one, then re-fetch `/api/auth/me` and invalidate every cached list.

| Role | Behaviour |
|---|---|
| `super_admin` | May switch to any department in the org |
| `admin` | **`403` always** — hard-locked to one department |
| `normal_user` | Only to departments in their `user_departments` assignments, else `403` |

Errors: `404` department not in org · `403` not permitted.

---

### 3.3 Roles

| Role | Scope |
|---|---|
| `super_admin` | Full cross-department access; can switch departments freely; sees all departments; passes `requireAdmin` |
| `admin` | Locked to one department; cannot switch; passes `requireAdmin` (so can manage users, reports, master dropdowns) |
| `normal_user` | Scoped to assigned departments; can switch among them; `reports` module force-disabled |

Endpoints marked **🔑 admin** below require `admin` or `super_admin`. Endpoints marked **🔑 super_admin** require `super_admin` only.

If the department encoded in the token has since been archived, **every** protected endpoint returns:

```json
{ "success": false, "message": "Access Denied: The department you are operating in has been archived." }
```
with status `403`. Handle this globally — force a department re-pick or logout.

---

## 4. Dashboard

There is no single `/dashboard` endpoint. The dashboard home screen is composed from these calls.

### 4.1 `GET /api/activities/stats` 🔒 — the KPI tiles

The primary dashboard call. Returns org-wide counters plus today's activity counts.

**Query**

| Param | Type | Notes |
|---|---|---|
| `ownerId` | uuid | Omit for "whole team" view; pass the current user's id for "my work" view |

**Response `200`** (raw object, no envelope)

```json
{
  "totalActivities": 1284,
  "calls": 210,
  "meetings": 96,
  "emails": 640,
  "tasks": 300,
  "notes": 38,
  "completed": 900,
  "pending": 384,
  "callsToday": 4,
  "meetingsToday": 2,
  "emailsToday": 11,
  "pendingTasks": 27,
  "totalContacts": 512,
  "totalCompanies": 143,
  "totalDeals": 88,
  "totalQuotations": 12
}
```

### 4.2 `GET /api/activities/dashboard-unified` 🔒 — the activity feed

A merged, chronological feed of everything that happened (calls, meetings, emails, tasks, notes) across contacts/companies/deals. This is what the web dashboard's "Today / Yesterday / Custom range" cards are built from.

**Query**

| Param | Type | Notes |
|---|---|---|
| `ownerId` | uuid | Filter to one user |
| `startDate` | ISO datetime | e.g. `2026-07-31T00:00:00.000Z` |
| `endDate` | ISO datetime | |
| `page` | int | default `1` |
| `limit` | int | default `20` |

**Response `200`** `{ "data": [...], "meta": { page, limit, total } }`

⚠️ `meta.total` here is the length of the returned page, not the full result count. Don't build a page-count UI on it — use infinite scroll and stop when `data.length < limit`.

### 4.3 Other dashboard sources

| Purpose | Endpoint |
|---|---|
| Pipeline totals (deal count, value, won/lost) | `GET /api/deals/stats` |
| Revenue forecast + per-stage breakdown | `GET /api/deals/forecast?ownerId=` |
| Kanban board grouped by stage | `GET /api/deals/board` |
| Deals needing attention | `GET /api/deals/stale?days=30` |
| Deals to follow up today | `GET /api/deals/followups/today` |
| Stage-to-stage conversion rates | `GET /api/deals/conversion` |
| Tasks due today | `GET /api/activities/today` |
| Overdue tasks | `GET /api/activities/overdue` |
| Upcoming reminders | `GET /api/activities/reminders?hours=24` |
| Notification bell | `GET /api/activities/notifications` |
| Contact totals by lifecycle | `GET /api/contacts/stats` |
| Company totals by industry/size | `GET /api/companies/stats` |
| Custom widget dashboards (**🔑 admin**) | `GET /api/reports/dashboards/default` |

**Suggested mobile dashboard load:** fire `activities/stats`, `deals/stats`, `activities/dashboard-unified` (limit 20), and `activities/notifications` in parallel on mount.

---

## 5. Contacts

Base: `/api/contacts` — all routes 🔒.

### `GET /api/contacts`

**Query**

| Param | Type | Notes |
|---|---|---|
| `page` | numeric string | default `1` |
| `limit` | numeric string | default `20` |
| `search` | string | matches name / email / phone / company |
| `sort` | string | `created_at`, `first_name`, `email`, `updated_at`, … |
| `order` | `asc`\|`desc`\|`ASC`\|`DESC` | |
| `ownerId` | uuid | |
| `leadStatus` | string | |
| `lifecycleStage` | string | |
| `createdDateRange` | string | e.g. `2026-01-01,2026-06-30` |
| `ids` | string | comma-separated ids, for batch fetch |
| `ignorePermissions` | `"true"` | bypass owner-scoping where allowed |

⚠️ `page` and `limit` are validated as **strings matching `^\d+$`**. Sending `?page=1&limit=20` from a query-string builder is fine; sending a JSON number is not applicable here. Sending `?page=` (empty) will fail validation with `400`.

**Response `200`**

```json
{ "success": true, "data": [ /* Contact[] */ ], "meta": { "page": 1, "limit": 20, "total": 512 } }
```

### `GET /api/contacts/:id`

**Response `200`** `{ "success": true, "data": { ...contact } }` · **`404`** if not found.

The single-contact payload is richer than the list rows:

```jsonc
{
  "id": "uuid",
  "organizationId": "uuid",
  "ownerId": "uuid",
  "firstName": "Jane",
  "lastName": "Doe",
  "email": "jane@acme.com",
  "phone": "+15550100",
  "jobTitle": "VP Engineering",
  "companyId": "uuid",
  "lifecycleStage": "lead",
  "leadStatus": "new",
  "status": null,
  "industry": "technology",
  "msp": null,
  "avatarUrl": null,
  "leadSource": "website",
  "linkedinUrl": "https://linkedin.com/in/...",
  "departmentId": "uuid",
  "createdAt": "2026-01-04T09:12:00.000Z",
  "updatedAt": "2026-07-20T14:03:00.000Z",

  "ownerName": "Sam Rivera",
  "ownerAvatar": null,
  "companyName": "Acme Corp",
  "companyAvatar": null,
  "companyIndustry": "technology",
  "companyDomain": "acme.com",

  "associatedCompanies": [{ "id": "uuid", "name": "Acme Corp", "domain": "acme.com", "industry": "technology", "isPrimary": true }],
  "deals":               [{ "id": "uuid", "title": "Acme Q3", "amount": 50000, "stage": "RFI", "expectedCloseDate": "2026-09-30", "isPrimary": true }],
  "assignees":           [{ "id": "uuid", "firstName": "Sam", "lastName": "Rivera", "email": "sam@..." }]
}
```

### `POST /api/contacts`

Rate limited: **50 creates per minute per IP**.

**Body**

| Field | Type | Required |
|---|---|---|
| `firstName` | string | ✅ |
| `lastName` | string | |
| `email` | string (email) or `""` | |
| `phone` | string | |
| `jobTitle` | string | |
| `ownerId` | uuid | |
| `leadStatus` | string | |
| `status` | string | |
| `industry` | string | |
| `companyId` | uuid | |
| `leadSource` | string | |
| `linkedinUrl` | string | |
| `msp` | string \| null | |
| `avatarUrl` | string \| null | |

**Response `201`** `{ "success": true, "data": { ...contact } }`
**`409`** if a contact with that email already exists in the department.

Server-side behaviour worth knowing: email is lowercased, phone is normalized, and if `companyId` is omitted the server attempts to auto-link a company by matching the email domain.

### `PATCH /api/contacts/:id`

Same fields as create, all optional, plus:

| Field | Type | Notes |
|---|---|---|
| `lifecycleStage` | string | Forward-only transitions are validated → `400` on illegal jumps |
| `companyId` | uuid \| uuid[] | Accepts one or many |
| `replacePrimary` | boolean | |
| `replaceCompanyIds` | uuid[] | Replaces the whole association set |
| `associatedContactIds` | uuid[] | |
| `ownerId` | uuid \| null | |

**Response `200`** `{ "success": true, "data": {...} }`

### Other contact endpoints

| Method | Path | Notes |
|---|---|---|
| `DELETE` | `/api/contacts/:id` | Soft delete → `{ success, message, data }` |
| `PATCH` | `/api/contacts/:id/owner` | Body `{ "ownerId": "uuid" }` (required, uuid) |
| `GET` | `/api/contacts/:id/tags` | |
| `POST` | `/api/contacts/:id/tags` | Body `{ "tag": "string" }` (1–50 chars) |
| `GET` | `/api/contacts/:id/notes` | |
| `POST` | `/api/contacts/:id/notes` | Body `{ "content": "string" }` |
| `GET` | `/api/contacts/:id/timeline` | Activity history for this contact |
| `GET` | `/api/contacts/:id/deals` | Deals linked to this contact (raw array) |
| `GET` | `/api/contacts/stats` | `{ success, data: { totalContacts, lifecycleStats } }` |
| `GET` | `/api/contacts/duplicates` | `{ success, data }` |
| `POST` | `/api/contacts/merge` | Body `{ "primaryId", "secondaryId" }` |
| `GET` | `/api/contacts/export` | Returns **CSV** (`text/csv`), not JSON. Accepts the same filters as list. |
| `POST` | `/api/contacts/import` | `multipart/form-data`, field `file`, CSV |

### Lifecycle stage values

`added` · `subscriber` · `lead` · `marketing_qualified` · `sales_qualified` · `opportunity` · `customer` · `evangelist` · `""`

Transitions are validated forward-only. Fetch the org's display labels from `GET /api/lifecycle-stages?entityType=contact`.

---

## 6. Companies

Base: `/api/companies` — all routes 🔒. Note the envelope differences vs contacts.

### `GET /api/companies`

Query params: `page`, `limit`, `search`, `sort`, `order`, `ownerId`, `leadStatus`, `lifecycleStage`, `createdDateRange`, `ignorePermissions`.

Unlike contacts, these are **not** Zod-validated — `page`/`limit` are coerced with `Number()`, so a bad value silently becomes `NaN`. Always send clean integers.

**Response `200`** `{ "data": [...], "meta": { page, limit, total } }` — **no `success` key.**

### `GET /api/companies/:id`

**Response `200`** — a raw company object with a `contacts` array merged in:

```jsonc
{
  "id": "uuid",
  "organizationId": "uuid",
  "ownerId": "uuid",
  "name": "Acme Corp",
  "domain": "acme.com",
  "website": "https://acme.com",
  "industry": "technology",
  "companySize": "51-200",
  "phone": "+15550100",
  "address": "1 Main St", "city": "Austin", "state": "TX",
  "country": "USA", "postalCode": "78701",
  "numberOfEmployees": 126,
  "annualRevenue": 25000000,
  "description": "...",
  "leadStatus": "new",
  "linkedinUrl": "https://linkedin.com/company/acme",
  "lifecycleStage": "lead",
  "type": "prospect",
  "timezone": "America/Chicago",
  "quarter": "Q3-2026",
  "msp": null,
  "avatarUrl": null,
  "primaryContactId": "uuid",
  "createdAt": "...", "updatedAt": "...",
  "contactCount": 7,
  "deals":     [{ "id", "title", "amount", "stage", "expectedCloseDate", "isPrimary" }],
  "assignees": [{ "id", "firstName", "lastName", "email" }],
  "contacts":  [ /* full contact rows */ ]
}
```

**`404`** → `{ "error": "Company not found" }`

### `POST /api/companies`

Rate limited: **50 creates per minute per IP**.

Required: `name`. Optional: `domain`, `website` (must be a valid URL or `""`), `industry`, `companySize`, `phone` (regex `^\+?[0-9\s()-.]{7,20}$` or `""`), `address`, `city`, `state`, `country`, `postalCode`, `numberOfEmployees` (int), `annualRevenue` (number), `description`, `linkedinUrl` (valid URL or `""`), `ownerId`, `leadStatus`, `lifecycleStage`, `type`, `timezone`, `contactId`, `quarter`, `msp`, `avatarUrl`, `primaryContactId`.

**Response `201`** — raw company object. **`409`** if the domain already exists in the department.

### `PATCH /api/companies/:id`

Same fields, all optional. **`200`** raw object.

### Other company endpoints

| Method | Path | Notes |
|---|---|---|
| `DELETE` | `/api/companies/:id` | **`204 No Content`** — no body |
| `PATCH` | `/api/companies/:id/owner` | Body `{ "ownerId": "uuid" }` |
| `GET` / `POST` | `/api/companies/:id/tags` | POST body `{ "tag" }` → `201 { success: true }` |
| `GET` / `POST` | `/api/companies/:id/notes` | POST body `{ "content" }` → `201` |
| `GET` | `/api/companies/:id/activities` | |
| `GET` | `/api/companies/:id/timeline` | |
| `GET` | `/api/companies/:id/contacts` | |
| `GET` | `/api/companies/:id/deals` | |
| `GET` | `/api/companies/stats` | `{ totalCompanies, newThisMonth, industries, sizeDistribution, topCompanies }` |
| `GET` | `/api/companies/duplicates` | `{ success, data }` |
| `POST` | `/api/companies/merge` | Body `{ "primaryId", "secondaryId" }` |
| `GET` | `/api/companies/export` | **CSV** |
| `POST` | `/api/companies/import` | Body is a **JSON array** of companies (not multipart) |
| `POST` | `/api/companies/enrich` | Body `{ "domain": "acme.com" }` — scrapes + AI-normalizes company data. **Slow (up to 45 s)**; use a long timeout and a loading state, or skip in v1. |

### `GET /api/msp-options` 🔒

Returns a plain string array for the MSP dropdown: `["Magnit", "Beeline", "agileOne", ...custom]`.
`POST /api/msp-options` with `{ "name": "..." }` adds one → `201 { "name": "..." }`.

---

## 7. Deals

Base: `/api/deals` — all routes 🔒.

### `GET /api/deals`

**Query:** `page`, `limit`, `search`, `sort`, `order`, `stage`, `companyId`, `contactId`, `ownerId`, `createdDateRange`, `staleDays`.

Allowed `sort` values: `created_at`, `title`, `amount`, `expected_close_date`, `stage`, `probability`, `updated_at`. Anything else silently falls back to `created_at`.

**Response `200`** `{ "data": [...], "meta": { total, totalAmount, totalWeightedAmount, page, limit, totalPages } }`

Each row includes joined display fields you'll want on a list cell — `companyName`, `contactFirstName`, `contactLastName`, `ownerName`, `ownerIsActive`, `associatedCompanies[]`, `assignees[]`, `contactIds[]`, `companyIds[]`, `latestNoteCreatedAt`.

### `GET /api/deals/:id`

**Response `200`** — raw deal object. **`404`** → `{ "error": "Deal not found" }`.

```jsonc
{
  "id": "uuid", "organizationId": "uuid", "ownerId": "uuid",
  "companyId": "uuid", "contactId": "uuid",
  "title": "Acme Q3 Renewal",
  "description": "...",
  "amount": 50000,
  "amountInBaseCurrency": 50000,
  "currency": "USD",
  "stage": "RFI",
  "pipelineId": "uuid",
  "probability": 45,
  "expectedCloseDate": "2026-09-30T00:00:00.000Z",
  "lossReason": null,
  "priority": "high",
  "dealType": "new_business",
  "probabilityOverride": false,
  "nextFollowupDate": "2026-08-05T00:00:00.000Z",
  "salesCycleDays": 62,
  "quarter": "Q3-2026",
  "lastContacted": "2026-07-28T00:00:00.000Z",
  "recordSource": "manual",
  "forecastProbability": 50,
  "comments": "...",
  "apidelRevenue": 12000,
  "clientType": "enterprise",
  "createdAt": "...", "updatedAt": "...", "archivedAt": null
}
```

### `POST /api/deals`

Required: `title`. Optional: `description`, `companyId`, `contactId`, `amount` (≥0), `currency` (≤10 chars), `stage`, `pipelineId`, `probability` (0–100), `expectedCloseDate` (parseable date string), `ownerId`, `dealType`, `priority`, `contactIds[]`, `companyIds[]`, `quarter`, `lastContacted`, `recordSource`, `forecastProbability` (0–100), `comments`, `apidelRevenue` (≥0), `clientType`.

**Response `201`** — raw deal. Creating a deal with the same title on the same company while another is open returns `500` with `Duplicate deal detected: ...`.

Pass `pipelineId: "default"` or omit it and the server resolves the org's pipeline automatically.

### `PATCH /api/deals/:id`

Same fields, all optional. **`200`** raw deal.

### Stage handling

| Method | Path | Body | Notes |
|---|---|---|---|
| `GET` | `/api/deals/stages` | — | Raw array `[{ id, name, probability, position, pipelineId }]`, ordered by `position`. **Auto-seeds defaults** on first call. |
| `POST` | `/api/deals/stages` | `{ "name", "probability" }` | `201` |
| `PUT` | `/api/deals/stages/reorder` | `{ "stageIds": ["uuid", ...] }` | Full ordered list |
| `PATCH` | `/api/deals/stages/:id` | `{ "name"?, "probability"? }` | |
| `DELETE` | `/api/deals/stages/:id` | — | |
| `PATCH` | `/api/deals/:id/stage` | `{ "stage": "RFI" }` | Move a deal. Transitions are validated — illegal jumps error. |
| `PATCH` | `/api/deals/:id/loss` | `{ "lossReason": "..." }` | Shortcut: sets stage to `Closed Lost` |

**Default stages and probabilities**

| Stage | Probability |
|---|---|
| Prospect | 10 |
| Capability Statement | 25 |
| RFI | 45 |
| RFP/RFQ | 65 |
| MSA | 85 |
| Closed Won | 100 |
| Closed Lost | 0 |

Stage names are **strings, not enums, and are org-editable** — always render from `GET /api/deals/stages` rather than hardcoding.

### Deal analytics & actions

| Method | Path | Returns |
|---|---|---|
| `GET` | `/api/deals/board` | `{ "Prospect": [deals], "RFI": [deals], ... }` — keyed by stage name, ready for Kanban |
| `GET` | `/api/deals/stats` | `{ totalDeals, pipelineValue, closedWon, closedLost }` |
| `GET` | `/api/deals/forecast?ownerId=` | `{ expectedRevenue, weightedRevenue, byStage: [...] }` |
| `GET` | `/api/deals/stale?days=30` | Raw array of deals untouched for N days (excludes closed) |
| `GET` | `/api/deals/conversion` | Raw array of stage conversion rates |
| `GET` | `/api/deals/followups/today` | Raw array |
| `GET` | `/api/deals/duplicates` | `{ success, data }` |
| `GET` | `/api/deals/:id/activities` | Raw array |
| `GET` | `/api/deals/:id/timeline` | Raw array |
| `POST` | `/api/deals/:id/archive` | |
| `POST` | `/api/deals/:id/notes` | `{ "content" }` |
| `POST` | `/api/deals/:id/tags` | `{ "tag" }` |
| `POST` | `/api/deals/:id/attachments` | `{ "fileUrl", "fileName" }` — upload via `/api/uploads` first |
| `PATCH` | `/api/deals/:id/owner` | `{ "ownerId" }` |
| `DELETE` | `/api/deals/:id` | **`204`** |

---

## 8. Activities (tasks, calls, meetings, emails, notes)

Base: `/api/activities` — all routes 🔒. One table backs all five types, discriminated by `type`.

- `type`: `call` · `meeting` · `email` · `task` · `note`
- `status`: `pending` · `completed` · `cancelled` · `reopened`
- `priority`: `none` · `low` · `medium` · `high`
- `visibility`: `private` · `team` · `organization` (default `organization`)

### `GET /api/activities`

**Query:** `page`, `limit`, `search`, `type`, `status`, `contactId`, `companyId`, `dealId`, `ownerId`, `startDate`, `endDate`, `sort`, `order`, `createdDateRange`, `priority`.

**Response `200`** `{ "data": [...], "meta": { page, limit, total } }`

To build a **Tasks screen**, call `GET /api/activities?type=task&status=pending&limit=20`.

### `POST /api/activities`

**Body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `type` | enum | ✅ | one of the 5 above |
| `title` | string ≤255 | | |
| `description` | string | | |
| `contactId` / `companyId` / `dealId` | uuid \| null | | primary links |
| `scheduledAt` | ISO date string | | |
| `outcome` | string \| null | | |
| `durationMinutes` | positive int | | |
| `visibility` | enum | | defaults to `organization` |
| `priority` | enum | | |
| `ownerId` | uuid \| null | | |
| `queue` | string \| null | | |
| `recurrenceType` | `daily`\|`weekly`\|`monthly`\|`yearly` | | |
| `recurrenceInterval` | positive int | | |
| `recurrenceEndDate` | ISO date string | | |
| `reminderType` | string | | |
| `customReminderAt` | ISO date string | | |
| `cc` / `bcc` | string \| null | | |
| `associations` | `[{ objectId, objectType }]` | | `objectType` ∈ `contact`\|`company`\|`deal` — use for **multi-record** linking |

**Response `201`** — raw activity object. Creating an activity also fires an org notification.

### `PATCH /api/activities/:id`

Same fields (all optional) plus `status` and `completedAt`.

### Actions & queues

| Method | Path | Notes |
|---|---|---|
| `PATCH` | `/api/activities/:id/complete` | Marks completed |
| `DELETE` | `/api/activities/:id` | **`204`** |
| `GET` | `/api/activities/:id` | Raw object; `404` → `{ error: "Activity not found" }` |
| `GET` | `/api/activities/today` | Follow-ups due today |
| `GET` | `/api/activities/overdue` | |
| `GET` | `/api/activities/reminders?hours=24` | Upcoming reminders |
| `GET` | `/api/activities/stats?ownerId=` | The KPI object from §4.1 |
| `GET` | `/api/activities/timeline?limit=` | Recent org activity |
| `GET` | `/api/activities/unified-timeline` | Query: `contactId`, `companyId`, `dealId`, `page`, `limit` — merged record timeline |
| `GET` | `/api/activities/dashboard-unified` | See §4.2 |
| `GET` | `/api/activities/engagement/:contactId` | Engagement score for a contact |
| `POST` | `/api/activities/bulk` | Body `{ "activities": [...] }` → `201` |
| `POST` | `/api/activities/from-template` | Body `{ "templateId", "overrides" }` |
| `POST` | `/api/activities/:id/assignees` | `{ "userId", "role" }` — role ∈ `owner`\|`participant`\|`observer` |
| `POST` | `/api/activities/:id/tags` | `{ "tag" }` |
| `POST` | `/api/activities/:id/attachments` | `{ "fileUrl", "fileName" }` |
| `GET` | `/api/activities/duplicates?type=task` | `type` is **required** → `400` without it |

### Notifications (bell icon)

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/activities/notifications` | Query: `companyId`, `contactId`, `dealId`, `createdDateRange` |
| `PATCH` | `/api/activities/notifications/:id/read` | |
| `PATCH` | `/api/activities/notifications/mark-all-read` | |
| `DELETE` | `/api/activities/notifications/:id` | `404` if not yours |

Notification shape: `{ id, userId, type, message, entityType, entityId, readAt, createdAt, contactId, companyId, dealId, contactName, companyName, dealName }`.

There is **no push/websocket channel** — poll `/notifications` (e.g. every 60 s while foregrounded) or wire up your own push layer.

### `POST /api/activities/send-email` 🔒

⏱ **Rate limited: 10 emails per hour per user** (`EMAIL_RATE_LIMIT_MAX`). Exceeding it returns `429` with `{ success: false, error: "Email rate limit exceeded..." }`.

**Body**

```jsonc
{
  "from": "sender@example.com",              // optional
  "to": ["a@example.com"],                   // required, 1–100
  "cc": [], "bcc": [],                       // ≤100 each
  "subject": "Quarterly check-in",           // required, ≤255
  "bodyHtml": "<p>Hi…</p>",                  // required, <1 MB
  "bodyJson": "{...}",                       // required, editor state
  "attachments": [{ "key": "uploads/…", "name": "deck.pdf", "mimeType": "application/pdf" }],
  "associations": [{ "objectId": "uuid", "objectType": "contact" }],
  "createTodo": false,
  "todoDetails": { "type": "task", "scheduledAt": "…", "title": "…" },
  "deliveryMode": "CRM_SALES"                // or "GROUP"
}
```

Total recipients (`to` + `cc` + `bcc`) must be ≤ 100. Attachments must be uploaded via `/api/uploads` first — send the returned `key`.

Error mapping: `404` mailbox not found · `403` permission denied · `503` email not configured · `429` rate limited.

---

## 9. Global search

### `GET /api/search?q=acme` 🔒

**Response `200`**

```json
{
  "success": true,
  "data": {
    "companies": [ ... ],
    "contacts":  [ ... ],
    "deals":     [ ... ]
  }
}
```

An empty or missing `q` returns `200` with three empty arrays (not an error) — safe to call on every keystroke. Debounce ~300 ms anyway.

---

## 10. Users

Base: `/api/users` — all routes 🔒.

### `GET /api/users`

Any authenticated user. Department-silo'd (`super_admin` and `system` see everyone).

**Response `200`**

```json
{
  "data": [
    {
      "id": "uuid",
      "email": "jane@example.com",
      "firstName": "Jane",
      "lastName": "Doe",
      "avatarUrl": "https://…",
      "position": "AE",
      "phone": "+1…",
      "isActive": true,
      "role": "normal_user",
      "departmentId": "uuid",
      "departmentName": "Sales",
      "departments": [{ "id": "uuid", "name": "Sales" }]
    }
  ]
}
```

### `PUT /api/users/me`

Self-service profile update — **available to every authenticated user**. This is the one users endpoint a non-admin mobile user needs.

**Body** `{ "firstName", "lastName", "position", "phone", "avatarUrl" }` (all optional)
**Response `200`** `{ "success": true, "message": "Profile updated successfully" }`

For the avatar: `POST /api/uploads` → take `url` from the response → `PUT /api/users/me` with `{ "avatarUrl": url }`.

### Admin-only user management 🔑 admin

| Method | Path | Body | Notes |
|---|---|---|---|
| `POST` | `/api/users` | `{ email, password, firstName, lastName, position, phone, role, departmentId }` | `email` + `password` required; password ≥6 chars; `400` if email taken → `201 { data }` |
| `PUT` | `/api/users/:userId` | `{ firstName, lastName, position, phone, role, email, isActive, departmentId }` | |
| `PUT` | `/api/users/:userId/avatar` | `{ avatarUrl }` | |
| `PUT` | `/api/users/:userId/password` | `{ password }` | ≥6 chars |
| `PUT` | `/api/users/:userId/departments` | `{ departmentIds: [] }` | Must be an array |
| `DELETE` | `/api/users/:userId` | — | `400` if you try to delete yourself |
| `GET` | `/api/users/email-preferences` | — | Per-user notification toggles |
| `PUT` | `/api/users/email-preferences` | `{ preferences: [{ userId, preferences: {...} }] }` | Bulk save |

---

## 11. Departments

| Method | Path | Access | Notes |
|---|---|---|---|
| `GET` | `/api/departments?includeDeleted=true` | any authenticated | `{ data: [...] }` |
| `POST` | `/api/departments` | 🔑 super_admin | `{ name }` — slug auto-generated → `201 { success, data }` |
| `PUT` | `/api/departments/:id` | 🔑 super_admin | `{ name }` to rename, or `{ restore: true }` to un-archive |
| `DELETE` | `/api/departments/:id` | 🔑 super_admin | Soft delete |

`admin` gets `403` on the mutating routes — only `super_admin` passes.

---

## 12. Configuration / dropdowns

These drive picker UIs. Cache them at app start and refresh on pull-to-refresh.

### Lifecycle stages — `/api/lifecycle-stages` 🔒

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/lifecycle-stages?entityType=contact` | `entityType` is **required** and must be `contact` or `company`, else `400`. Auto-seeds 8 defaults on first call. Returns a **raw array**. |
| `POST` | `/api/lifecycle-stages` | `{ entityType, name }` → `201` |
| `PUT` | `/api/lifecycle-stages/reorder` | `{ stageIds: [] }` |
| `PATCH` | `/api/lifecycle-stages/:id` | `{ name }` |
| `DELETE` | `/api/lifecycle-stages/:id` | |

### Master dropdowns — `/api/master-dropdowns` 🔒

Generic key/value option sets (lead status, deal type, priority, industry, etc.).

| Method | Path | Access | Notes |
|---|---|---|---|
| `GET` | `/api/master-dropdowns?includeInactive=true` | any | `{ success, data }` |
| `GET` | `/api/master-dropdowns/key/:key` | any | `{ success, data }`; `404` if unknown key |
| `POST` | `/api/master-dropdowns` | 🔑 admin | `{ dropdownKey, displayName, options }` |
| `PATCH` | `/api/master-dropdowns/:id` | 🔑 admin | `{ displayName }` |
| `DELETE` | `/api/master-dropdowns/:id` | 🔑 admin | |
| `POST` | `/api/master-dropdowns/:dropdownId/options` | 🔑 admin | `{ label, value, color }` — `label` required |
| `PATCH` | `/api/master-dropdowns/:dropdownId/options/:optionId` | 🔑 admin | `{ label, value, color, isDefault, isActive }` |
| `DELETE` | `/api/master-dropdowns/:dropdownId/options/:optionId` | 🔑 admin | Deactivates rather than hard-deletes |
| `PUT` | `/api/master-dropdowns/:dropdownId/options/reorder` | 🔑 admin | `{ optionIds: [] }` |

**Bootstrap recommendation:** on login, fetch `GET /api/master-dropdowns`, `GET /api/deals/stages`, `GET /api/lifecycle-stages?entityType=contact`, `GET /api/lifecycle-stages?entityType=company`, `GET /api/msp-options`, and `GET /api/users` once, and cache them for the session.

---

## 13. File uploads

### `POST /api/uploads` 🔒

`multipart/form-data`, single field named **`file`**. Max **20 MB**.

**Response `200`**

```json
{
  "success": true,
  "key": "uploads/1712345678-deck.pdf",
  "url": "https://your-host/api/uploads/download?key=uploads%2F1712345678-deck.pdf"
}
```

Store the `key` when the API asks for a key (email attachments) and the `url` when it asks for a URL (`avatarUrl`, deal attachments).

### `GET /api/uploads/download?key=...`

⚠️ **No auth middleware.** The returned URL is directly loadable by an `<Image>` / Glide / Kingfisher without attaching a token. Keys must start with `uploads/` or you get `403`. `404` if the object is missing.

### `GET /api/uploads/presigned?key=...` 🔒

Returns `{ success: true, url }` — the same backend download URL. The underlying S3/Garage endpoint is never exposed.

---

## 14. Reports & custom dashboards 🔑 admin

Base: `/api/reports` — **every route requires `admin` or `super_admin`.** `normal_user` gets `403`, and `/api/auth/me` already reports `permissions.reports.view === false` for them, so gate the whole section on that flag.

### Tabular reports

| Path | Query |
|---|---|
| `GET /api/reports/contacts` | `page`, `limit`, `range`, `startDate`, `endDate`, `userId` |
| `GET /api/reports/companies` | same |
| `GET /api/reports/deals` | same |
| `GET /api/reports/users` | `page`, `limit` |
| `GET /api/reports/activities` | above + `type` (default `task`), `companyId`, `contactId` |
| `GET /api/reports/dashboard-analytics` | `range`, `startDate`, `endDate`, `userId` |

`page` defaults to `1`, `limit` to `20`.

### Custom dashboards

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/reports/dashboards` | `{ data: [...] }` |
| `GET` | `/api/reports/dashboards/default` | Query `bypass_cache=true`, `date_range=`. **Auto-creates a seeded default** if none exists. |
| `GET` | `/api/reports/dashboards/:id` | Same query params; returns dashboard + widget data |
| `POST` | `/api/reports/dashboards` | `{ name, description, isDefault, visibilityScope, autoRefreshInterval }` — `name` required |
| `PUT` | `/api/reports/dashboards/:id` | same fields |
| `DELETE` | `/api/reports/dashboards/:id` | `{ message: "Dashboard deleted" }` |

### Widgets

| Method | Path | Notes |
|---|---|---|
| `POST` | `/api/reports/dashboards/:id/widgets` | `{ title, chartType, dataSource, config, savedFilterId, positionX, positionY, width, height }` — first three required |
| `PUT` | `/api/reports/dashboards/widgets/:widgetId` | same fields |
| `DELETE` | `/api/reports/dashboards/widgets/:widgetId` | |
| `PUT` | `/api/reports/dashboards/:id/widget-positions` | `{ positions: [...] }` |
| `POST` | `/api/reports/dashboards/widgets/preview` | `{ chartType, dataSource, config }` — render without saving |
| `GET` | `/api/reports/dashboards/widgets/:widgetId/drilldown` | `dimensionValue` **required**, plus `page`, `limit` (default 20) |

Dashboard responses are cached server-side; pass `bypass_cache=true` on pull-to-refresh.

---

## 15. Rate limits

| Endpoint | Limit | Key |
|---|---|---|
| `POST /api/contacts` | 50 / minute | IP |
| `POST /api/companies` | 50 / minute | IP |
| `POST /api/activities/send-email` | 10 / hour | user id (falls back to IP) |

The email limiter returns standard `RateLimit-*` headers. Surface `429` to the user with the message from the body rather than retrying automatically.

---

## 16. Mobile integration checklist

1. **Token storage** — Keychain (iOS) / EncryptedSharedPreferences or Keystore (Android). Never `AsyncStorage`/`UserDefaults` in plaintext.
2. **HTTP interceptor** — attach `Authorization: Bearer <access_token>`; on `401`, refresh once, retry once, then log out. Guard against concurrent refresh storms with a single-flight lock.
3. **Department is in the token.** Any department change means: call `/switch-department`, replace the token, re-fetch `/me`, and clear every cached list.
4. **Handle the archived-department `403`** globally — it can hit any endpoint at any time.
5. **Normalize envelopes at the network layer**, not in your screens. Write per-module adapters using the table in §2 so the rest of the app sees one consistent shape.
6. **Casing is inconsistent between `/login` (snake_case user) and `/me` (camelCase user).** Pick one internal model and map at the boundary.
7. **Pagination** — contacts/companies/activities give you a real `total`; use it for page counts. `dashboard-unified` does not — use infinite scroll there.
8. **Don't hardcode stages or lifecycle values.** They're org-editable; read them from the config endpoints in §12.
9. **Gate UI on `/me` `permissions`**, and treat the backend's `403`s as the real authority.
10. **Avatars and attachments** load without auth via `/api/uploads/download` — no token plumbing needed for image views.
11. **Notifications are poll-only** today. Budget for a 60 s foreground poll, or plan a push layer as a backend addition.
12. **Skip `/api/companies/enrich` in v1** — it shells out to a scraper plus an LLM and can take 45 seconds.

---

## 17. Quick curl reference

```bash
HOST=http://localhost:5000

# 1. Login
curl -s -X POST $HOST/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com","password":"secret123"}'

TOKEN="<access_token from above>"

# 2. Bootstrap
curl -s $HOST/api/auth/me            -H "Authorization: Bearer $TOKEN"
curl -s $HOST/api/deals/stages       -H "Authorization: Bearer $TOKEN"
curl -s $HOST/api/master-dropdowns   -H "Authorization: Bearer $TOKEN"

# 3. Dashboard
curl -s $HOST/api/activities/stats                          -H "Authorization: Bearer $TOKEN"
curl -s $HOST/api/deals/stats                               -H "Authorization: Bearer $TOKEN"
curl -s "$HOST/api/activities/dashboard-unified?page=1&limit=20" -H "Authorization: Bearer $TOKEN"

# 4. Lists
curl -s "$HOST/api/contacts?page=1&limit=20&search=acme" -H "Authorization: Bearer $TOKEN"
curl -s "$HOST/api/deals?page=1&limit=20&stage=RFI"      -H "Authorization: Bearer $TOKEN"
curl -s "$HOST/api/search?q=acme"                        -H "Authorization: Bearer $TOKEN"

# 5. Create a contact
curl -s -X POST $HOST/api/contacts \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"firstName":"Jane","lastName":"Doe","email":"jane@acme.com","jobTitle":"VP Eng"}'

# 6. Upload a file
curl -s -X POST $HOST/api/uploads \
  -H "Authorization: Bearer $TOKEN" -F "file=@./avatar.png"

# 7. Refresh
curl -s -X POST $HOST/api/auth/refresh \
  -H 'Content-Type: application/json' -d '{"refresh_token":"<refresh_token>"}'
```
