# Breach 02 — Mass assignment (self privilege escalation)

**Class:** Broken access control / mass assignment
**Flag:** `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` (on `/staff/dashboard`, cadet-gated)

## How it works
`PATCH /api/profile` updates the caller's own user record from a JSON body and
**does not restrict which fields** may be set. A logged-in student can send
`{"role":"cadet"}` (also `verified`, `level`, …) and the server writes them verbatim
to the PocketBase record. The `/staff` page even advertises it:
*"Cadet access required. Try PATCH /api/profile with the right fields."*

The role is also cached in the session JWT, so after escalating you re-login to get a
fresh token carrying `role:cadet`, which unlocks `/staff/dashboard` and its flag.

The server does validate the *higher* roles (`staff`/`god` → "role not assignable"),
so this vector only reaches `cadet`; the rest of the ladder is breach 03.

## Impact
Vertical privilege escalation from student to cadet, exposing staff-only resources.

## Remediation
- Use an explicit allow-list of client-editable fields (e.g. `first_name`, `avatar`);
  never bind `role`, `verified`, `level`, `id` from user input.
- Derive privileges server-side from the authoritative record, not from a JWT claim the
  user influenced.
