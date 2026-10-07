# Breach 01 — Predictable & disclosed password-reset token

**Class:** Broken authentication / insecure password recovery
**Flag:** `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` (read from the account record, breach 04)

## How it works
`POST /reset-password/request` generates a reset token equal to **`md5(email)`** and
then **redirects the browser straight to the reset link with the token in the URL** —
no email is ever sent. Two independent failures:

1. **Disclosure** — the token is handed to the unauthenticated requester in the
   `Location` header, so anyone can reset anyone's password.
2. **Predictability** — even without requesting, the token is `md5(lowercase email)`,
   a value an attacker already knows.

`POST /reset-password/confirm` with `email`, `token=md5(email)`, `new_password` then
sets the password. (Staff/god accounts are excluded — "use 42 SSO" — so we target a
student, `benjamin@student.42.tech`.)

## Impact
Full account takeover of any non-SSO account without any prior access. This is the
initial foothold for the whole audit.

## Proof
`./exploit.sh` → resets benjamin and logs in.

## Remediation
- Generate reset tokens from a CSPRNG (e.g. `secrets.token_urlsafe(32)`), store a hash
  of them server-side with a short expiry, and bind them to one user + one use.
- Deliver the link **out of band** (email); never return it in the HTTP response.
- Don't derive security tokens from known data (email) or with a non-keyed digest (md5).
