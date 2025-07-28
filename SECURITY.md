# 🔒 Security Policy

This is a **private and personal project**. While not open to public contribution, the project follows basic security hygiene for long-term maintainability.

---

## 🔧 Supported Versions

Only the **latest main branch** is maintained. Older versions may contain unpatched vulnerabilities and should not be used.

---

## 📣 Reporting Security Issues

If you ever notice a potential security issue (even in private use), please report it via the GitHub [Security tab](../../security/advisories). This ensures the issue is tracked and handled privately.

If the Security tab is unavailable, direct communication is also acceptable (e.g., through Issues or your preferred contact method).

---

## ⚙️ Internal Security Practices

This project follows lightweight but effective security practices:

- Secrets are **never committed** and managed via `.env` (gitignored)
- GitHub **2FA is enabled**
- **Dependabot** is active for dependency alerts
- **Code Scanning** is enabled (GitHub CodeQL default workflow)
- Commits are **signed** where possible (optional)
- Local audits via `npm audit`, `cargo audit`, or similar as needed

---

## ⏱️ Incident Handling

This is a personal project with no SLA. However:
- Issues marked "security" will be reviewed as time allows.
- Critical issues will be patched **as soon as realistically possible**.

---

_Last updated: 2025-07-28_
