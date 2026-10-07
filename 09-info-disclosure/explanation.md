# Breach 09 — Information disclosure (debug headers, comments, verbose errors)

**Class:** Security misconfiguration / sensitive data exposure
**Flag:** none (vulnerability to explain)

## How it works
The app leaks internals on every response and in page source:

- **Headers** on every response:
  `x-powered-by: Python/3.11 FastAPI/0.104`, `server: uvicorn/0.24.0 Linux`,
  `x-pocketbase: http://localhost:8090` (reveals the internal backend + port),
  `x-42-internal: campus=paris`.
- **HTML comments** across pages leak the whole challenge map: SQL-in-login history,
  non-HttpOnly cookie, `xml.etree` unsafe parser, and
  `NOTE: /internal/config restricted to localhost only. do not expose.`
- **`robots.txt`** discloses `/staff`, `/backup`, `/api/grades`, `/_/`.
- **Verbose errors**: pydantic 422 bodies expose the framework and field structure.

## Impact
Hands an attacker the tech stack, internal service locations and a roadmap of weak
points — accelerating every other attack in this report.

## Remediation
Strip `x-powered-by`/custom debug headers in production, remove revealing comments,
return generic error messages, and minimise `robots.txt`.
