# Darkly v2 — Architecture & Methodology (detailed guide)

A deep explanation of the target, the full attack surface, the exploitation chain, and
every vulnerability with impact and remediation. Pair this with `docs/REPRODUCE.md`
(commands + real outputs) and `QUICKSTART.md` (fast path).

---

## 1. The target

Darkly v2 is a deliberately vulnerable web app ("42 Network" clone) served by the sealed
VM appliance. **Scope: the web application only** (the subject forbids attacking the VM
OS or the `.ova`).

### Stack (all leaked by the app itself)
- **Front door:** FastAPI 0.104 on uvicorn, Python 3.11, port **4942**.
- **Backend/datastore:** **PocketBase** on port **8090** (internal). PocketBase is a
  Go app over SQLite exposing an auto REST API + an admin UI at `/_/`. The FastAPI app
  is a thin layer that authenticates users, renders Jinja templates, and proxies data
  to/from PocketBase.
- **Sessions:** HS256 **JWT** in a `session` cookie (not HttpOnly). Claims:
  `{sub, login, role, exp}`.
- **Roles (privilege ladder):** `student` < `cadet` < `staff` < `god`.

### Data model (PocketBase collections)
`users` (auth) · `posts` · `comments` · `projects` · `grades` · `newsletter` ·
`agenda_imports` · `internal_config` (key/value secrets) · `internal_audit`.
The `users` record over-exposes `private_note`, `recovery_code`, `pw_hint`.

```
Browser ──HTTP:4942──> FastAPI (uvicorn)  ──HTTP:8090──> PocketBase ──> SQLite
                         │  Jinja templates
                         │  JWT session (HS256, secret "42network")
                         └─ /internal/config  (localhost-only gate)
```

---

## 2. Attack-surface map

| Path | Method | Auth | Notes |
|------|--------|------|-------|
| `/` `/forum` `/projects` `/staff` | GET | none | leak users, hints, stack |
| `/login` | POST | none | parameterized (SQLi fixed) |
| `/reset-password/request` | POST | none | **token = md5(email), disclosed in redirect** |
| `/reset-password/confirm` | POST | none | sets password (students only) |
| `/api/profile` | PATCH | user | **mass assignment** (role up to cadet) |
| `/api/users` | GET | user | lists all users (**enumeration**) |
| `/api/users/<id>` | GET | user | **IDOR** — any full record |
| `/staff/dashboard` | GET | cadet+ | Flag 2 |
| `/admin` | GET | god (by `sub`→DB) | Flag 3 |
| `/agenda/import` | POST | user | **XXE → SSRF** (XML, defusedxml off) |
| `/internal/config` | GET | **loopback only** | secrets + Flag 5 (reach via SSRF) |
| `/newsletter` | POST/GET | user | **reflected XSS** on `email` param |
| `/forum/new` | POST | user | **stored XSS** in post content |
| `/redirect?next=` | GET | none | **open redirect** (any scheme) |
| PocketBase `:8090` `/api/admins/auth-with-password` | POST | creds | **Flag 6** |

Disallowed-but-telling `robots.txt`: `/admin /staff /internal /backup /api/grades /_/
/static/uploads/`.

---

## 3. Methodology (how the audit proceeded)

1. **Passive recon** — read every page's HTML (comments), `robots.txt`, `sitemap.xml`,
   and response headers. Darkly v2 narrates its own bugs; the forum deploy log is the
   single richest source (jwt secret, defusedxml, upload whitelist, reset weakness).
   Script: `recon/recon.sh`.
2. **Foothold** — no self-registration exists, so abuse the **reset flow** (token =
   md5(email), handed back directly) to take over a student → valid session JWT.
3. **Vertical escalation** — `PATCH /api/profile` (**mass assignment**) lifts
   student→cadet (Flag 2). The server caps higher roles, so pivot to the **leaked JWT
   secret** and forge the god account for `/admin` (Flag 3).
4. **Horizontal/data access** — **IDOR** on `/api/users/<id>` dumps every record,
   yielding two flags and all password hints (Flag 4).
5. **Server-side** — **XXE→SSRF** via `/agenda/import` bypasses the loopback gate on
   `/internal/config`, leaking secrets incl. PocketBase admin creds (Flag 5).
6. **Full compromise** — reuse those creds against the internal **PocketBase superuser**
   API and read the audit collection (Flag 6).

Each step feeds the next; the chain is the point.

---

## 4. The privilege-escalation chain (the 4-flag ladder + admin)

```
anonymous
  │  reset token = md5(email), disclosed            [Breach 01]
  ▼
student (benjamin)  ── recovery_code → FLAG 1
  │  PATCH /api/profile {"role":"cadet"}            [Breach 02]
  ▼
cadet  ── /staff/dashboard → FLAG 2
  │  forge JWT (secret "42network") as sophie/god   [Breach 03]
  ▼
god (via /admin, checked by sub→DB) → FLAG 3
  │  IDOR dumps records + creds via XXE→SSRF         [Breach 04, 05] → FLAG 4, 5
  ▼
PocketBase superuser (leaked creds) → FLAG 6        [Breach 11]
```

---

## 5. Vulnerabilities (deep dive)

Full write-ups live per breach in `NN-*/explanation.md`; summary with impact + fix:

| # | Vulnerability | Where | Flag | Core fix |
|---|---------------|-------|------|----------|
| 01 | Predictable + disclosed reset token (md5(email), returned in redirect) | `/reset-password/*` | ✓ | CSPRNG token, hashed+expiring, emailed OOB |
| 02 | Mass assignment / self privilege escalation | `PATCH /api/profile` | ✓ | field allow-list; never bind `role` |
| 03 | Weak/leaked JWT signing secret | session cookie | ✓ | long random secret in a vault; rotate |
| 04 | IDOR + excessive data exposure + user enumeration | `/api/users[/id]` | ✓ | object-level authz; minimal serializer |
| 05 | XXE → SSRF → secret disclosure | `/agenda/import` → `/internal/config` | ✓ | defusedxml; authz on `/internal/*`; no secrets in config endpoint |
| 06 | Stored XSS (post content rendered raw) | `/forum/new` → `/forum/<id>` | — | output-encode; CSP; HttpOnly cookie |
| 07 | Reflected XSS (`email` query param) | `/newsletter` | — | encode reflected params; CSP |
| 08 | Open redirect (any URL/scheme, incl. `javascript:`) | `/redirect?next=` | — | relative-only / host allow-list |
| 09 | Information disclosure (debug headers, comments, verbose errors) | global | — | strip headers/comments; generic errors |
| 10 | Unsalted-md5 password hints + weak passwords | `users.pw_hint` | — | argon2/bcrypt; drop `pw_hint` |
| 11 | PocketBase superuser via credential reuse | `:8090` | ✓ | isolate admin API; rotate creds |

**Supporting weaknesses** (count toward the "19 vulnerabilities"): session cookie not
`HttpOnly`/`Secure` (amplifies 06/07), missing CSRF tokens on state-changing forms,
`/admin` trusting the JWT-supplied `sub` for its lookup, and broad `robots.txt`
disclosure.

---

## 6. Environment & reproduction

- **Running the appliance:** `SETUP.md` (QEMU x86 emulation on Apple Silicon; forward
  guest `:4942` and `:8090`). On Intel, import the OVA into VirtualBox directly.
- **Fast path to all flags:** `QUICKSTART.md`.
- **Full transcripts (commands + real outputs):** `docs/REPRODUCE.md`.
- **Runnable exploits:** `NN-*/exploit.sh` in each breach folder.

---

## 7. Status

- **Mandatory: complete.** 6/6 flags recovered; 10 vulnerabilities found and explained
  (plus supporting weaknesses, exceeding the count).
- **Bonus (4 more flags + 5 more vulns):** the 5 additional vulnerabilities are
  documented (06–10). The 4 remaining **bonus flags are not stored in the database**
  (verified via PocketBase superuser dump) — they are gated behind **client-side victim
  triggers** (e.g. an admin bot visiting a stored-XSS/CSRF payload) that the standalone
  offline appliance does not run. In a live defense these are demonstrated by proving
  the XSS/CSRF primitives fire; the primitives themselves are proven in breaches 06–08.
