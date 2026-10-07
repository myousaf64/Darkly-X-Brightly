# Breach 08 — Open redirect

**Class:** Unvalidated redirect / forward
**Flag:** none (vulnerability to explain)

## How it works
`GET /redirect?next=<url>` issues a 307 to **any** target, with no allow-list:

```bash
curl -i "http://localhost:4942/redirect?next=https://evil.example/"   # -> Location: https://evil.example/
curl -i "http://localhost:4942/redirect?next=//evil.com"              # -> http://evil.com/
curl -i "http://localhost:4942/redirect?next=javascript:alert(1)"     # -> javascript:alert(1)
```

The `javascript:` case is especially dangerous if any client follows it.

## Impact
Phishing (trusted 42 domain bouncing to attacker sites), OAuth/redirect abuse, and a
building block for other attacks.

## Remediation
Allow only relative paths or an explicit host allow-list; reject absolute URLs,
protocol-relative `//`, and non-http(s) schemes.
