#!/usr/bin/env bash
# Modo --solo-dictado: configura Handy sin pasar por el resto del instalador.
set -Eeuo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

FAKE="${WORK_ROOT}/home-solo"
LOG="${WORK_ROOT}/solo.log"

cargar_installer
instalar_stubs
instalar_stub_command
stub_handy_apagado

# REAL_USER/REAL_HOME/AUR_HELPER los consume install.sh; ver lib.sh.
# shellcheck disable=SC2034
check_distro()        { :; }
# shellcheck disable=SC2034
detect_aur_helper()   { AUR_HELPER=yay; }
# shellcheck disable=SC2034
resolve_real_user()   { REAL_USER="$(id -un)"; REAL_HOME="${FAKE}"; }

preparar_home "${FAKE}"
escribir_settings "${FAKE}" '{
  "post_process_api_keys": {"custom": "NO-TOCAR"},
  "post_process_prompts": [],
  "post_process_providers": [],
  "post_process_models": {}
}'

fallas=0
chk() { if [[ "$1" == "0" ]]; then echo "  OK    $2"; else echo "  FALLA $2"; fallas=$((fallas + 1)); fi; }

( main --solo-dictado ) >"${LOG}" 2>&1
chk "$?" "main --solo-dictado termina sin error"

grep -q "Modo --solo-dictado" "${LOG}"
chk "$?" "anuncia el modo --solo-dictado"

[[ -x "${FAKE}/${FAKE_HANDY_DIR}/hooks/transcription" ]]
chk "$?" "hook instalado y ejecutable en modo solo"

grep -q "kbDictado" "${FAKE}/.config/hypr/variables.lua"
chk "$?" "atajos añadidos a variables.lua"

grep -q "install_deps\|Instalando paquetes del sistema" "${LOG}" && chk 1 "no instaló paquetes del sistema" \
    || chk 0 "no instaló paquetes del sistema"

echo ""
echo "SOLO-DICTADO: ${fallas} fallas"
[[ ${fallas} -eq 0 ]]
