# Breach 03 — Weak / leaked JWT signing secret

**Class:** Broken authentication (forgeable session) / sensitive data exposure
**Flag:** `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` (on `/admin`)

## How it works
The session cookie is an **HS256 JWT**. The forum deploy log leaks the history:
*"jwt secret was '42'. wil changed it to '42network'."* With the secret known, we can
**forge any token**. The signature *is* verified (a tampered sig or `alg:none` is
rejected), so the only thing protecting it is the secret — which is public.

`/admin` requires the god role. It resolves the user from the token's `sub` claim and
checks the **database** role (so merely claiming `role:god` for our own `sub` fails —
see the note in breach 02). We therefore forge a token for the real god account
**sophie** (`sub=enplwhu8jfo56oi`, id obtained via breach 04) and read `/admin`.

## Impact
Complete authentication bypass and impersonation of the highest-privileged user.

## Remediation
- Use a long, random, secret kept out of source/logs; rotate it (which invalidates all
  tokens). Prefer per-environment secrets from a secret manager.
- Consider short token lifetimes + server-side session validation so a leaked secret is
  not game-over on its own.
