# Breach 05 — XXE leading to SSRF and secret disclosure

**Class:** XML External Entity (XXE) + Server-Side Request Forgery (SSRF)
**Flag:** `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`

## How it works
`POST /agenda/import` parses the uploaded XML with the stdlib parser and **entity
resolution enabled** (the forum/`/staff` notes admit defusedxml was disabled). The
imported `<title>` is reflected back in the import result table.

Local `file://` entities are not returned, but an **HTTP external entity is fetched by
the server itself**:

```xml
<!DOCTYPE a [ <!ENTITY x SYSTEM "http://localhost:4942/internal/config"> ]>
<agenda><event><title>&x;</title><date>2042-01-01</date></event></agenda>
```

`/internal/config` is gated to **loopback only** (the client IP check can't be spoofed
with `X-Forwarded-For` etc.). But the XXE fetch originates **from the server on
localhost**, so the gate is bypassed (SSRF) and the endpoint's body is embedded into
the reflected title. It leaks:

- `darkly_flag` → the flag,
- `jwt_secret: 42network` (confirms breach 03),
- `pb_admin_email` / `pb_admin_password` (PocketBase superuser creds — see NEXT-STEPS).

The same primitive reaches the internal PocketBase on `:8090` (its `/api/health`
responds), i.e. a general SSRF into the internal network.

## Impact
Read access to internal-only endpoints and their secrets; SSRF to other internal
services. One of the most serious findings.

## Remediation
- Parse untrusted XML with `defusedxml`; disable DTDs/external entities.
- Validate uploads (content type, schema) and don't reflect parsed values.
- Don't trust "localhost-only" as a security boundary reachable via app-driven requests;
  require authentication/authorization on `/internal/*` and keep secrets out of
  readable config endpoints.
