#!/usr/bin/env bash
# Idempotencia: ejecutar configure_dictation() dos veces no duplica nada
# y no toca la API key.
set -Eeuo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

FAKE="${WORK_ROOT}/home-idem"

cargar_installer
instalar_stubs
instalar_stub_command
stub_handy_apagado

# REAL_USER/REAL_HOME los consume configure_dictation(); ver lib.sh.
# shellcheck disable=SC2034
REAL_USER="$(id -un)"
# shellcheck disable=SC2034
REAL_HOME="${FAKE}"

preparar_home "${FAKE}"
escribir_settings "${FAKE}" '{
  "settings_schema_version": 1,
  "post_process_api_keys": {"custom": "NO-TOCAR"},
  "post_process_prompts": [{"id": "es_limpieza_dictado", "name": "x", "prompt": "viejo"}],
  "post_process_providers": [{"id": "custom"}],
  "post_process_models": {"custom": "x"}
}'

configure_dictation >/dev/null 2>&1
configure_dictation >/dev/null 2>&1

python3 - "${FAKE}" "${FAKE_HANDY_DIR}" <<'PY'
import json, sys

home, subdir = sys.argv[1:3]
base = home + "/" + subdir + "/"
s = json.load(open(base + "settings_store.json"))["settings"]
v = open(home + "/.config/hypr/variables.lua").read()
k = open(home + "/.config/hypr/hyprland/keybinds.lua").read()
fallas = []


def chk(cond, msg):
    print(("  OK    " if cond else "  FALLA ") + msg)
    if not cond:
        fallas.append(msg)


chk(len(s["post_process_prompts"]) == 1, "prompt no duplicado tras 2 ejecuciones")
chk(v.count("kbDictadoCrudo") == 1, "kbDictadoCrudo no duplicado")
chk(k.count("kbDictado") == 2, "binds no duplicados")
chk(s["post_process_api_keys"]["custom"] == "NO-TOCAR", "API key intacta")

print("\nIDEMPOTENCIA: %d fallas" % len(fallas))
sys.exit(1 if fallas else 0)
PY
