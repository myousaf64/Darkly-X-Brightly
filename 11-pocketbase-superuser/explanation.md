# Breach 11 — PocketBase superuser takeover (credential chain)

**Class:** Broken access control / credential disclosure chain
**Flag:** `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`

## How it works
Breach 05 (XXE → SSRF → `/internal/config`) leaked the backend secrets, including the
**PocketBase superuser credentials** `admin@42network.local` / `Darkly42Admin!`. The
PocketBase instance (robots.txt disallows `/_/`, its admin UI) runs on the internal
`:8090`. Authenticating as superuser:

```
POST /api/admins/auth-with-password  {"identity":"admin@42network.local","password":"Darkly42Admin!"}
```

returns an admin token with full read/write over every collection. The
`internal_audit` collection holds the final flag (the flag name nods to the `/_/`
admin path leaked in robots.txt).

This is the true "administrator of the application": PocketBase superuser = the highest
privilege in the stack, reached entirely from a chain of web-app weaknesses
(info disclosure → XXE → SSRF → credential reuse).

## Impact
Total compromise of the application's datastore: read/modify all users, grades, config;
full game over.

## Remediation
- Never store plaintext admin credentials in a readable config endpoint/collection.
- Isolate the PocketBase admin API from app-reachable SSRF targets; bind it to a
  management network only.
- Rotate the leaked superuser credentials and the JWT secret.
