# Breach 04 — IDOR on user records

**Class:** Broken object-level authorization (IDOR) / excessive data exposure
**Flags:** `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}`, `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`

## How it works
`GET /api/users/<id>` returns a user's **full** record to any authenticated caller,
with **no ownership check**. The record over-exposes sensitive fields:
`private_note`, `recovery_code` and `pw_hint`.

- Any account's `recovery_code` is `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}`.
- wil's `private_note` is `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`.
- Every `pw_hint` is an **unsalted md5 of the password** (see breach 10), e.g. jdoe's
  `e99a18c4…` = `md5("abc123")`.

User ids are enumerable from `/api/users` (the list endpoint itself over-discloses the
whole user table — emails, roles — enabling user enumeration).

## Impact
Reads any user's private data, password hashes and recovery material; combined with
breach 10 it yields plaintext passwords.

## Remediation
- Enforce object-level authorization: a user may read only their own record unless
  staff/god.
- Serialize a minimal field set; never return `recovery_code`, `pw_hint`,
  `private_note` over the API.
