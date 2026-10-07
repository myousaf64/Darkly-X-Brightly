# Darkly v2 — Audit Walkthrough

Target: the web application at **http://localhost:4942** (FastAPI + uvicorn, backed by
an internal PocketBase on `:8090`). All testing is against the provided sealed VM
appliance only. Scripts are our own (no sqlmap or similar).

## Environment

The appliance is a VirtualBox x86 OVA; the lab host is Apple Silicon, so we run it under
QEMU (x86_64 emulation) with guest `:4942` forwarded to host `:4942`. See
`SETUP.md`. Recon: `recon/recon.sh`.

## Flags recovered (6/6 mandatory target: 5 found + 1 in progress)

| # | Flag | Breach | Vuln class |
|---|------|--------|-----------|
| 1 | `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` | 01 / 04 | Predictable+disclosed reset token |
| 2 | `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` | 02 | Mass assignment (privesc) |
| 3 | `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` | 03 | Weak/leaked JWT secret |
| 4 | `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}` | 04 | IDOR on user records |
| 5 | `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}` | 05 | XXE → SSRF → secret disclosure |
| 6 | *in progress* | — | PocketBase superuser (creds leaked in breach 05) |

## Privilege-escalation ladder (student → application admin)

1. **Foothold** (breach 01): reset token is `md5(email)` and disclosed in the redirect →
   take over the student `benjamin@student.42.tech`, log in → session JWT with
   `role:student`.
2. **student → cadet** (breach 02): `PATCH /api/profile {"role":"cadet"}` (mass
   assignment). Re-login → cadet JWT → `/staff/dashboard` → **flag 2**.
3. **→ god/admin** (breach 03): the JWT secret `42network` is leaked in the forum. The
   cadet step is capped server-side, so we forge a JWT for the real god account
   **sophie** (her id comes from the IDOR). `/admin` → **flag 3**.
4. Each level reached corresponds to a flag, as the subject requires.

## The 10 vulnerabilities

Flag-bearing: **01** predictable/disclosed reset token · **02** mass assignment ·
**03** weak JWT secret · **04** IDOR · **05** XXE→SSRF.
Additional: **06** stored XSS (forum) · **07** reflected XSS (newsletter) ·
**08** open redirect · **09** information disclosure (debug headers/comments/robots) ·
**10** unsalted-MD5 password hints + weak passwords.

Each folder has `exploit.sh` (reproduces it), `explanation.md` (how/impact/fix) and a
`flag` file where one is yielded. Supporting weaknesses also observed: user enumeration
and excessive data exposure via `/api/users`, non-HttpOnly session cookie (amplifies 06
and 07), and `/admin` trusting the JWT `sub` for lookup.

## How to reproduce (quick)

```bash
# 1. foothold
./01-predictable-reset-token/exploit.sh
J=$(grep session /tmp/ben.jar | awk '{print $NF}')
# 2..5
./02-mass-assignment-privesc/exploit.sh http://localhost:4942 "$J"
./03-weak-jwt-secret/exploit.sh
./04-idor-user-records/exploit.sh http://localhost:4942 "$J"
./05-xxe-ssrf-internal-config/exploit.sh http://localhost:4942 "$J"
```

## Next steps (flag 6 + bonus)

Breach 05 leaked the **PocketBase superuser** credentials
(`admin@42network.local` / `Darkly42Admin!`) on the internal `:8090` service. Using them
against PocketBase (which the SSRF shows is reachable) is the path to the application's
true admin and the remaining flags. That service is not exposed to the host in the
current port-forward; completing it is the open task.
