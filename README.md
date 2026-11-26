# Darkly-X-Brightly

## What it is

A security audit of **Darkly v2**, the 42 project's deliberately vulnerable web app
(FastAPI + uvicorn on `:4942`, backed by an internal PocketBase on `:8090`). It recovers
the 6 mandatory flags and documents 11 breaches, each in its own folder with a written
explanation, and an exploit script and recovered `flag` file where one applies.

**Authorized testing against the provided sealed VM appliance only.** Every script is our
own; no `sqlmap`.

## Demo

<!-- TODO: screenshot or GIF -->
![Audit run](docs/demo.png)

## Stack

- `bash` + `curl` for every exploit. No automated scanners.
- `python3` for the JWT forgery.
- The target runs as a VirtualBox OVA, booted under QEMU (x86_64) on Apple Silicon.

## Quickstart

1. Boot the appliance and forward the ports. See [`SETUP.md`](SETUP.md).
2. Run the fast path in [`QUICKSTART.md`](QUICKSTART.md): all 6 flags, copy-paste, top to
   bottom.
3. For step-by-step output, read [`docs/REPRODUCE.md`](docs/REPRODUCE.md).

```bash
B=http://localhost:4942
PB=http://localhost:8090
recon/recon.sh
```

## Results

Six mandatory flags, recovered through a chained attack (each bug feeds the next):

| # | Breach | Vulnerability |
|---|--------|---------------|
| 1 | 01 | Predictable and disclosed reset token (`md5(email)`) |
| 2 | 02 | Mass assignment privilege escalation |
| 3 | 03 | Weak / leaked JWT secret |
| 4 | 04 | IDOR on user records |
| 5 | 05 | XXE to SSRF to secret disclosure |
| 6 | 11 | PocketBase superuser via credential reuse |

Five more breaches are documented without a flag of their own: stored XSS (06), reflected
XSS (07), open redirect (08), information disclosure (09) and weak password hashing (10).

Full write-ups:

- [`walkthrough.md`](walkthrough.md) - the combined narrative audit.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) - methodology.
- One folder per breach (`01-…` through `11-…`) with `explanation.md`, plus `exploit.sh`
  and a `flag` file where recovered.

No binaries or disk images are committed; the `.ova` and disk files are git-ignored.

## License

MIT. See [`LICENSE`](LICENSE).
