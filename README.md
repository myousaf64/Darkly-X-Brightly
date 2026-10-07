# Darkly-X-Brightly

Security audit of the **Darkly v2** 42 project (deliberately vulnerable web app).
Authorized testing against the provided sealed VM appliance only.

- **Start here:** [`walkthrough.md`](walkthrough.md) — full audit, flag table, privesc chain.
- **Setup:** [`SETUP.md`](SETUP.md) — running the appliance under QEMU on Apple Silicon.
- **Recon:** [`recon/recon.sh`](recon/recon.sh).
- **Breaches:** one folder per vulnerability (`01-…` … `10-…`), each with
  `exploit.sh`, `explanation.md`, and a `flag` file where one is recovered.

No binaries are committed (subject rule); the `.ova`/disk images are git-ignored.
