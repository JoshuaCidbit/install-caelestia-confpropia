#!/usr/bin/env bash
# Utilidades compartidas por las pruebas de configure_dictation().
#
# Idea: se hace `source` de install.sh con `main "$@"` neutralizado, se
# sustituyen los comandos que tocan el sistema real (pacman, lspci, pkill…)
# por stubs y se apunta REAL_HOME a un directorio temporal. Así las pruebas
# no tocan ni ~/.local/share/com.pais.handy ni ~/.config/hypr reales.
set -Eeuo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="${SRC_DIR}/tests/fixtures"
WORK_ROOT="${WORK_ROOT:-${TMPDIR:-/tmp}/install-caelestia-tests}"

# Ruta del HOME falso, relativa a él.
FAKE_HANDY_DIR=".local/share/com.pais.handy"

die() { echo "ABORTA: $*" >&2; exit 1; }

# Carga install.sh sin ejecutar main().
cargar_installer() {
    mkdir -p "${WORK_ROOT}"
    local copia="${WORK_ROOT}/installer-sourceable.sh"
    sed 's|^main "\$@"|: # main neutralizado por tests/lib.sh|' \
        "${SRC_DIR}/install.sh" > "${copia}"
    # shellcheck disable=SC1090
    source "${copia}"
    # Lo consume configure_dictation() en install.sh.
    # shellcheck disable=SC2034
    SCRIPT_DIR="${SRC_DIR}"
}

# Stubs de todo lo que tocaría el sistema real.
# `pacman -Q` siempre éxito => nunca pide instalar paquetes (ni sudo).
instalar_stubs() {
    ask()     { return 0; }
    pacman()  { return 0; }
    sudo()    { return 0; }
    hyprctl() { return 0; }
    lspci()   { echo "01:00.0 VGA compatible controller: NVIDIA Corporation"; }
    export HYPRLAND_INSTANCE_SIGNATURE="prueba-tests"
}

# `command -v handy` controlable sin depender del PATH real:
# HANDY_DISPONIBLE=1 lo finge instalado, 0 lo finge ausente.
instalar_stub_command() {
    HANDY_DISPONIBLE="${HANDY_DISPONIBLE:-0}"
    command() {
        if [[ "${1:-}" == "-v" && "${2:-}" == "handy" ]]; then
            [[ "${HANDY_DISPONIBLE}" == "1" ]] && return 0
            return 1
        fi
        builtin command "$@"
    }
}

# Finge que Handy no está corriendo: no mata procesos reales.
stub_handy_apagado() {
    pgrep() { return 1; }
    pkill() { return 0; }
}

# Crea $1 como HOME falso con los dotfiles de fixtures (sin kbDictado).
preparar_home() {
    local home="$1"
    rm -rf "${home}"
    mkdir -p "${home}/.config/hypr/hyprland" "${home}/${FAKE_HANDY_DIR}/hooks"
    [[ -f "${FIXTURES}/variables.lua" ]] || die "falta ${FIXTURES}/variables.lua"
    [[ -f "${FIXTURES}/keybinds.lua" ]]  || die "falta ${FIXTURES}/keybinds.lua"
    cp "${FIXTURES}/variables.lua" "${home}/.config/hypr/variables.lua"
    cp "${FIXTURES}/keybinds.lua"  "${home}/.config/hypr/hyprland/keybinds.lua"
}

# Escribe un settings_store.json desde un objeto JSON.
# Uso: escribir_settings "$HOME_FALSO" '{"clave": "valor"}'
escribir_settings() {
    local home="$1" json="$2"
    python3 - "${home}/${FAKE_HANDY_DIR}/settings_store.json" "${json}" <<'PY'
import json, sys
ruta, json_txt = sys.argv[1:3]
json.dump({"settings": json.loads(json_txt)}, open(ruta, "w"), ensure_ascii=False, indent=2)
PY
}
