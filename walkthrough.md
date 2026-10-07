# Darkly v2 — Audit Walkthrough

Combined audit of the web app at **http://localhost:4942** (FastAPI + uvicorn, backed by
an internal PocketBase on `:8090`). Testing is against the provided sealed VM only;
all scripts are our own (no sqlmap).

## Flags (6/6 mandatory)

| # | Flag | Breach | Vulnerability |
|---|------|--------|---------------|
| 1 | `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` | 01 | Predictable + disclosed reset token |
| 2 | `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` | 02 | Mass assignment (privesc) |
| 3 | `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` | 03 | Weak / leaked JWT secret |
| 4 | `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}` | 04 | IDOR on user records |
| 5 | `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}` | 05 | XXE → SSRF → secret disclosure |
| 6 | `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}` | 11 | PocketBase superuser (cred reuse) |

## The chain (how one bug feeds the next)

```
anonymous ──reset token = md5(email)──▶ student ──PATCH role=cadet──▶ cadet
   ──forge JWT (secret "42network") as god──▶ /admin
   ──IDOR + XXE/SSRF leak creds──▶ PocketBase superuser
```

Each step unlocks the next; flags 1–5 are pure `:4942`, flag 6 reuses creds that the
`:4942` SSRF leaks to reach the internal PocketBase.

## Where to look

- **Run it fast:** `QUICKSTART.md`
- **Every step with real command output:** `docs/REPRODUCE.md`
- **How the app is built + methodology + per-vuln fixes:** `docs/ARCHITECTURE.md`
- **Each breach:** folders `01-…`–`11-…` (`exploit.sh` + `explanation.md` + `flag`)
- **Setup / how to run:** `SETUP.md`

## The 10 vulnerabilities

Flag-bearing: 01 reset token · 02 mass assignment · 03 weak JWT secret · 04 IDOR ·
05 XXE→SSRF (· 11 PocketBase cred reuse). Additional: 06 stored XSS · 07 reflected XSS ·
08 open redirect · 09 information disclosure · 10 unsalted-md5 password hints.
Details and fixes per folder and in `docs/ARCHITECTURE.md`.

## Status

Mandatory complete (6 flags, 10 vulns). Bonus: the 5 extra vulns are documented (06–10);
the 4 bonus flags are not in the datastore (confirmed via PocketBase superuser dump) —
they require a live victim/admin-bot to trigger XSS/CSRF, which the offline appliance
does not run.
