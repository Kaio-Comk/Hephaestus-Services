<div align="center">

# ⚙️ nssm-service-kit
### Production-Hardened Windows Services Automation with NSSM & PowerShell

[![PowerShell: 5.1 | 7+](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell&logoColor=white)](https://microsoft.com/powershell)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows&logoColor=white)](https://microsoft.com/windows)
[![Engine: NSSM](https://img.shields.io/badge/Engine-NSSM%20(Non--Sucking%20Service%20Manager)-orange.svg)](https://nssm.cc)
[![Logs: Online Rotation](https://img.shields.io/badge/Logs-Online%20Rotation%20%40%2010MB-green.svg)](https://github.com/Kaio-Comk/nssm-service-kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Declarative JSON-driven Windows service orchestration for Python, Node.js, and background daemons.**  
*Strict elevation verification, online log rotation, batch prefix management, and zero silent failures.*

[Why This Kit](#-why-fail-loudly) • [Architecture](#-architecture) • [JSON Configuration](#-configuration-schema) • [Operations Cheatsheet](#-operations-cheatsheet) • [Best Practices](#-production-lessons-baked-in)

</div>

---

## ⚡ Why "Fail Loudly"?

On Windows, standard management scripts frequently hide catastrophic errors:
* Running `Restart-Service -ErrorAction SilentlyContinue` without elevated Admin rights exits with code `0`, giving a false sense of success while the service **continues running old, broken code**.
* `nssm-service-kit` strictly enforces:
  1. **Pre-flight Elevation Check:** Immediately halts execution if not running in an elevated Administrator session.
  2. **Non-Zero Exit Codes:** Every failed step throws an actionable, visible error.
  3. **Dry-Run Mode (`-DryRun`):** Allows inspecting what would be configured without administrator privileges.

---

## 🏗️ Architecture

```mermaid
flowchart TD
    Config["📄 services.json (Declarative Config)"] --> Script["🛡️ install-services.ps1"]
    Script --> Elev{"Elevated Admin?"}
    Elev -->|No| Fail["🛑 Abort immediately (Exit 1)"]
    Elev -->|Yes| NSSM["⚙️ NSSM Wrapper Execution"]
    
    subgraph ServiceRegistry ["Windows Service Control Manager (SCM)"]
        NSSM --> Reg["Register Service: prefix-name"]
        NSSM --> Env["Set Environment: PYTHONUTF8=1"]
        NSSM --> Log["Configure Online Log Rotation (10MB Cap)"]
        NSSM --> Auto["Set Startup: Automatic (Delayed / Immediate)"]
    end
    
    ServiceRegistry --> Manage["🎮 manage-services.ps1 (start | stop | restart | status)"]
```

---

## 📋 Configuration Schema

Describe all your system services in a clean, version-controllable JSON file (`services.json`):

```json
{
  "prefix": "myapp",
  "python": "C:\\myapp\\.venv\\Scripts\\python.exe",
  "logsDir": "C:\\myapp\\logs",
  "services": [
    {
      "name": "worker",
      "script": "C:\\myapp\\workers\\queue_worker.py",
      "description": "MyApp Background Job Worker"
    },
    {
      "name": "api",
      "script": "C:\\myapp\\api\\server.py",
      "description": "MyApp FastAPI Gateway"
    }
  ]
}
```

> **Prefix Isolation:** Services are automatically registered as `<prefix>-<name>` (e.g., `myapp-worker`, `myapp-api`). Multiple deployments or environments (staging, production) can run side-by-side on the same Windows machine without collision.

---

## 💻 Operations Cheatsheet

### 1. Install or Update Services (Elevated PowerShell)
```powershell
# Validate configuration safely first (Dry-Run)
.\scripts\install-services.ps1 -Config .\services.json -DryRun

# Apply and register with Windows Service Control Manager
.\scripts\install-services.ps1 -Config .\services.json
```

### 2. Batch Lifecycle Management
Manage all services matching a prefix at once:
```powershell
# Check live status across all prefix services
.\scripts\manage-services.ps1 -Action status -Prefix myapp

# Gracefully restart all services
.\scripts\manage-services.ps1 -Action restart -Prefix myapp

# Stop all services
.\scripts\manage-services.ps1 -Action stop -Prefix myapp
```

---

## 🛡️ Production Lessons Baked In

* **Online Log Rotation:** Never truncate a file a running Windows process holds open. The installer configures NSSM's native log rotator (`AppRotateFiles 1`, `AppRotateBytes 10485760`) to rotate files cleanly while active.
* **UTF-8 on Windows:** Automatically injects `PYTHONUTF8=1` into the service environment to eliminate Windows `cp1252` encoding exceptions on emojis and unicode text.
* **LocalSystem Isolation:** Services running under `LocalSystem` share `%TEMP%`. The kit enforces unique working directories and log paths per service to prevent session collision.

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for details.

<div align="center">
  <sub>Built with ❤️ by Kaio Lima. If nssm-service-kit simplified your Windows DevOps, please give it a ⭐!</sub>
</div>
