# Breach 06 — Stored XSS (forum post body)

**Class:** Stored Cross-Site Scripting
**Flag:** none (vulnerability to explain)

## How it works
`POST /forum/new` stores a post. The **title** is HTML-escaped on render, but the
**content** is output raw on the post detail page `/forum/<id>`:

```bash
curl -b "session=$J" -X POST http://localhost:4942/forum/new \
  --data-urlencode 'title=t' \
  --data-urlencode 'content=x<script>alert(document.cookie)</script>'
# then open the returned /forum/<id> — the <script> is present unescaped
```

Because the session cookie is **not HttpOnly** (confirmed on `/staff`:
"Session cookie httponly=false"), script can read `document.cookie` and exfiltrate the
JWT → full account takeover of any viewer (e.g. staff reading the forum).

## Impact
Session theft / actions in the victim's context. Chains with the non-HttpOnly cookie.

## Remediation
Context-aware output encoding (escape on render), a strict CSP, and set the session
cookie `HttpOnly; Secure; SameSite=Lax`.
