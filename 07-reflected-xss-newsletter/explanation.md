# Breach 07 — Reflected XSS (newsletter email parameter)

**Class:** Reflected Cross-Site Scripting
**Flag:** none (vulnerability to explain)

## How it works
Subscribing (`POST /newsletter`, form field `email`, must be a valid address) redirects
to `/newsletter?email=<value>&msg=subscribed`, and the page reflects `email` **without
encoding**:

```bash
curl -b "session=$J" "http://localhost:4942/newsletter?email=<script>alert(7)</script>&msg=subscribed"
# the <script>…</script> is returned raw
```

A crafted link delivered to a victim executes script in their session.

## Impact
Script execution in a victim's browser via a malicious link (phishing, session theft,
combined with the non-HttpOnly cookie).

## Remediation
HTML-encode all reflected query parameters; add a CSP.
