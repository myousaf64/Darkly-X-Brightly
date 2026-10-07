# Breach 10 — Unsalted MD5 password hints + weak passwords

**Class:** Cryptographic failure / broken authentication
**Flag:** none (vulnerability to explain)

## How it works
Each user record exposes a `pw_hint` that is an **unsalted MD5 of the password**
(obtained via the IDOR, breach 04). Unsalted MD5 is instantly reversible via rainbow
tables:

```
jdoe   pw_hint = e99a18c428cb38d5f260853678922e03 = md5("abc123")
```

Logging in confirms it:

```bash
curl -c /tmp/j.jar http://localhost:4942/login --data "identity=jdoe@student.42.tech&password=abc123"
# -> 302 to /  (authenticated)
```

## Impact
Trivial recovery of plaintext passwords for any user whose hint is exposed → account
takeover without even using the reset flow.

## Remediation
Never store or expose password-derived material. Hash passwords with a slow, salted KDF
(bcrypt/argon2); enforce password strength; remove the `pw_hint` field entirely.
