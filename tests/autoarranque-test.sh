#!/usr/bin/env bash
# Primer arranque: cuando Handy todavía no creó settings_store.json,
# configure_dictation() debe lanzarlo (si handy está instalado), esperar y
# parchear. Usa el `handy` real y pgrep/pkill reales, así que se omite en
# CI y cuando Handy está corriendo.
set -Eeuo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

FAKE="${WORK_ROOT}/home-autoarranque"
LOG="${WORK_ROOT}/autoarranque.log"

# Solo en una sesión real, con el usuario real y Handy instalado.
if [[ "${REAL_USER_FORZADO:-}" != "$(id -un)" ]]; then
    REAL_USER_FORZADO="$(id -un)"
fi
if ! builtin command -v handy >/dev/null 2>&1; then
    echo "OMITE: handy no está instalado en esta máquina"
    exit 0
fi
if pgrep -x handy >/dev/null 2>&1; then
    echo "OMITE: Handy está en ejecución (ciérralo y vuelve a lanzar)"
    exit 0
fi
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo "OMITE: no hay sesión de Hyprland; Handy no puede arrancar con GUI"
    exit 0
fi

cargar_installer
instalar_stubs
instalar_stub_command
# Lo lee el stub `command -v handy` definido en lib.sh.
# shellcheck disable=SC2034
HANDY_DISPONIBLE=1
# Sin stub de pgrep/pkill: se prueban el cierre y la reapertura reales.
# shellcheck disable=SC2034
REAL_USER="$(id -un)"
# shellcheck disable=SC2034
REAL_HOME="${FAKE}"

preparar_home "${FAKE}"
# Sin settings_store.json: simula un arranque desde cero.
rm -f "${FAKE}/${FAKE_HANDY_DIR}/settings_store.json"

configure_dictation >"${LOG}" 2>&1
info "configure_dictation terminó"

fallas=0
chk() { if [[ "$1" == "0" ]]; then echo "  OK    $2"; else echo "  FALLA $2"; fallas=$((fallas + 1)); fi; }

grep -q "Primer arranque de Handy" "${LOG}"
chk "$?" "lanza Handy para crear la configuración"

[[ -f "${FAKE}/${FAKE_HANDY_DIR}/settings_store.json" ]]
chk "$?" "Handy creó settings_store.json"

grep -q "Cerrando Handy" "${LOG}"
chk "$?" "cierra Handy antes de parchear"

grep -q "Reabriendo Handy" "${LOG}"
chk "$?" "reabre Handy tras parchear"

python3 - "${FAKE}" "${FAKE_HANDY_DIR}" <<'PY'
import json, os, sys

home, subdir = sys.argv[1:3]
base = home + "/" + subdir + "/"
p = base + "settings_store.json"
fallas = []


def chk(cond, msg):
    print(("  OK    " if cond else "  FALLA ") + msg)
    if not cond:
        fallas.append(msg)


chk(os.path.exists(p), "existe settings_store.json")
if not os.path.exists(p):
    print("AUTOARRANQUE: %d fallas (sin settings)" % (len(fallas) + 1))
    sys.exit(1)

s = json.load(open(p))["settings"]
pid = "es_limpieza_dictado"
prompts = [x["prompt"] for x in s["post_process_prompts"] if x["id"] == pid]

chk(bool(prompts), "prompt %s aplicado" % pid)
chk(all(pr.count("${output}") == 1 for pr in prompts), "${output} exactamente una vez")
chk(s["post_process_enabled"] is True and s["onboarding_completed"] is True, "ajustes aplicados")
chk(s["post_process_provider_id"] == "custom", "proveedor custom")
chk(s["post_process_models"]["custom"] == "nvidia/nemotron-3.5-lightning:free", "modelo")

escritas = [v for v in s.get("post_process_api_keys", {}).values() if v]
chk(not escritas, "ninguna API key escrita")

chk(os.access(base + "hooks/transcription", os.X_OK), "hook ejecutable")
chk(open(home + "/.config/hypr/variables.lua").read().count("kbDictadoCrudo") == 1, "atajo insertado")

print("AUTOARRANQUE: %d fallas" % len(fallas))
sys.exit(1 if fallas else 0)
PY
