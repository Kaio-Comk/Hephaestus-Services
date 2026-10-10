import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PS = shutil.which("pwsh") or shutil.which("powershell")
pytestmark = pytest.mark.skipif(PS is None, reason="PowerShell not installed")


def _ps(command: str) -> subprocess.CompletedProcess:
    return subprocess.run([PS, "-NoProfile", "-NonInteractive", "-Command", command],
                          capture_output=True, text=True, timeout=60)


@pytest.mark.parametrize("script", ["install-services.ps1", "manage-services.ps1"])
def test_script_sintaxe_valida(script):
    path = str(ROOT / "scripts" / script).replace("'", "''")
    r = _ps("$e=$null;$t=$null;"
            f"[System.Management.Automation.Language.Parser]::ParseFile('{path}',[ref]$t,[ref]$e)|Out-Null;"
            "if($e.Count){$e|ForEach-Object{$_.Message};exit 1}")
    assert r.returncode == 0, r.stdout + r.stderr


def test_exemplo_de_config_e_json_valido():
    cfg = json.loads((ROOT / "services.example.json").read_text(encoding="utf-8"))
    assert cfg["python"] and {s["name"] for s in cfg["services"]} == {"bot", "api"}


def test_dry_run_nao_exige_admin_nem_nssm():
    script = str(ROOT / "scripts" / "install-services.ps1").replace("'", "''")
    conf = str(ROOT / "services.example.json").replace("'", "''")
    r = _ps(f"& '{script}' -Config '{conf}' -DryRun")
    assert r.returncode == 0, r.stdout + r.stderr
    assert "would install myapp-bot" in r.stdout and "would install myapp-api" in r.stdout


def test_manage_sem_admin_falha_alto_em_vez_de_calado():
    script = str(ROOT / "scripts" / "manage-services.ps1").replace("'", "''")
    r = _ps("$id=[Security.Principal.WindowsIdentity]::GetCurrent();"
            "$a=(New-Object Security.Principal.WindowsPrincipal $id).IsInRole("
            "[Security.Principal.WindowsBuiltInRole]::Administrator);"
            "if($a){Write-Output 'ELEVATED'; exit 0};"
            f"& '{script}' -Action restart -Services nao-existe")
    if "ELEVATED" in r.stdout:
        pytest.skip("test needs a non-elevated shell")
    assert r.returncode != 0 and "elevated" in (r.stdout + r.stderr).lower()
