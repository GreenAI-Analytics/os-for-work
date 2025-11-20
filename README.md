# OS‑for‑Work Script

## 📌 Overview
The **OS‑for‑Work Script** is a resilient, repo‑only installer designed for SME laptops running Debian or other Linux distributions. It automates the installation of essential productivity, communication, finance, creative, and security tools — all sourced from official repositories to ensure **security, simplicity, and compliance**.

This project empowers SMEs across Ireland and the EU with accessible, compliance‑ready technology that radically simplifies daily operations and regulatory obligations.

---

## ✨ Features
- 🔒 **Secure by design**: Installs only from trusted repositories (no external binaries).
- ⚡ **Fast setup**: One script to bootstrap a full SME workstation.
- 🛠️ **Modular categories**:
  - Productivity (office suites, note‑taking, task management)
  - Communication (email clients, messaging, video conferencing)
  - Finance (accounting, invoicing, budgeting tools)
  - Creative (graphics, media editing, publishing)
  - Security (password managers, encryption, VPN)
- 🧩 **Menu‑driven flexibility**: Users can choose categories or install everything.
- 🏢 **SME‑friendly**: Designed for non‑technical staff with minimal configuration.

---

## 📂 Project Structure
```
os-for-work/
├── install.sh        # Main installer script
├── modules/          # Category-specific install scripts
│   ├── productivity.sh
│   ├── communication.sh
│   ├── finance.sh
│   ├── creative.sh
│   └── security.sh
├── README.md         # Documentation
└── LICENSE           # License file
```

---

## 🚀 Installation
Clone the repository and run the installer:

```bash
git clone https://github.com/GreenAI-Analytics/os-for-work.git
cd os-for-work
chmod +x install.sh
./install.sh
```

During installation, you’ll be prompted to select categories or run a full setup.

---

## ⚙️ Usage
- Run `./install.sh` for guided setup.
- Use `./install.sh --all` to install everything.
- Use `./install.sh --category <name>` to install a specific category (e.g., `finance`).

---

## 🔧 Customization
- Add or remove packages in `modules/<category>.sh`.
- Adjust defaults in `install.sh` for organization‑wide policies.
- Extend with new categories (e.g., HR, compliance) by adding a new script under `modules/`.

---

## 🛡️ Security & Compliance
- All packages are sourced from official Debian/Ubuntu repositories.
- No external downloads or unverified binaries.
- Designed to meet SME compliance requirements across Ireland and the EU.

---

## 🤝 Contributing
Pull requests are welcome! Please ensure:
- Code is modular and repo‑only.
- Scripts are tested on Debian stable.
- Documentation is updated for any new features.

---

## 📜 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---
