# Darkly-X-Brightly

Security audit of the **Darkly v2** 42 project (deliberately vulnerable web app).
Authorized testing against the provided sealed VM appliance only.

- **Fast path:** [`QUICKSTART.md`](QUICKSTART.md) — all 6 flags, copy-paste.
- **Step-by-step with real outputs:** [`docs/REPRODUCE.md`](docs/REPRODUCE.md).
- **Architecture & methodology:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
- **Narrative audit:** [`walkthrough.md`](walkthrough.md) — required combined audit doc.
- **Setup:** [`SETUP.md`](SETUP.md) — running the appliance under QEMU on Apple Silicon.
- **Recon:** [`recon/recon.sh`](recon/recon.sh).
- **Breaches:** one folder per vulnerability (`01-…` … `11-…`), each with
  `exploit.sh`, `explanation.md`, and a `flag` file where one is recovered.

No binaries are committed (subject rule); the `.ova`/disk images are git-ignored.
