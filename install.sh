#!/usr/bin/env bash
# =============================================================================
#  install.sh — Hyprland / Caelestia + dotfiles personales
#  Compatible con: Arch / CachyOS / Manjaro
#
#  Qué hace este script, en orden:
#    1. Verifica distro y herramientas necesarias (git, curl, yay/paru)
#    2. Instala dependencias del sistema (pacman + AUR)
#    3. Instala Caelestia vía AUR (caelestia-cli) + `caelestia install`
#    4. Aplica dotfiles personales encima de Caelestia con rsync
#    5. Configura layout de teclado y sensibilidad en hypr/modules/input.lua
#    6. Crea ~/Pictures/wallpapers/1080p para evitar errores de wal
#    7. Habilita servicios del sistema (sddm, bluetooth, NetworkManager, ufw)
#
#  Uso:
#    chmod +x install.sh && ./install.sh
# =============================================================================

set -euo pipefail

# ── Colores ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helpers de output ─────────────────────────────────────────────────────────
info()  { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
ok()    { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
warn()  { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error() { echo -e "${RED}${BOLD}[ERR ]${RESET}  $*" >&2; }
die()   { error "$*"; exit 1; }

ask() {
    echo -en "${BOLD}$1 [s/N]: ${RESET}"
    read -r reply
    [[ "${reply,,}" == "s" || "${reply,,}" == "si" || "${reply,,}" == "sí" ]]
}

# ── Limpieza en caso de interrupción ─────────────────────────────────────────
DOTS_TMP=""
BACKUP_DIR=""
cleanup() {
    if [[ -n "${DOTS_TMP}" && -d "${DOTS_TMP}" ]]; then
        warn "Limpiando archivos temporales..."
        rm -rf "${DOTS_TMP}"
    fi
}
trap cleanup EXIT INT TERM

# ── 0. Verificaciones previas ─────────────────────────────────────────────────

check_not_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        die "No corras el script como root. Usa tu usuario normal; el script pedirá sudo cuando sea necesario."
    fi
}

check_distro() {
    info "Verificando distribución..."
    command -v pacman &>/dev/null || die "Este script requiere pacman (Arch / CachyOS / Manjaro)."
    ok "Distribución compatible detectada."
}

detect_aur_helper() {
    info "Detectando AUR helper..."
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    else
        die "No se encontró yay ni paru. Instala uno antes de continuar."
    fi
    ok "AUR helper detectado: ${AUR_HELPER}"
}

check_script_deps() {
    info "Verificando dependencias del script (git, curl)..."
    local missing=()
    for cmd in git curl; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Faltan: ${missing[*]}"
        ask "¿Instalarlos con pacman ahora?" || die "Abortado por el usuario."
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    fi
    ok "Dependencias del script presentes."
}

# ── Resolución de usuario real ────────────────────────────────────────────────
# Soporta tanto `sudo ./install.sh` (SUDO_USER disponible)
# como `./install.sh` con sudo interno (SUDO_USER vacío, usamos $USER).
resolve_real_user() {
    REAL_USER="${SUDO_USER:-${USER}}"
    if [[ -z "${REAL_USER}" || "${REAL_USER}" == "root" ]]; then
        die "No se pudo determinar el usuario real. Corre el script como tu usuario normal."
    fi
    REAL_HOME="$(getent passwd "${REAL_USER}" | cut -d: -f6)"
    ok "Usuario real detectado: ${REAL_USER}"
}

check_caelestia() {
    info "Verificando Caelestia..."
    if command -v caelestia &>/dev/null; then
        ok "Caelestia detectado: $(command -v caelestia)"
    else
        die "Caelestia no está instalado (requisito previo).\n  Instalalo con:\n    ${AUR_HELPER:-yay} -S caelestia-cli\n    caelestia install\n  Luego vuelve a ejecutar este script."
    fi
}

# ── 1. Dependencias del sistema ───────────────────────────────────────────────
install_deps() {
    info "Instalando dependencias del sistema..."

    local pacman_pkgs=(

        # Quickshell
        quickshell
        
        # Terminal
        kitty
        alacritty

        # Fuentes
        ttf-meslo-nerd
        ttf-opensans
        awesome-terminal-fonts
        noto-fonts
        noto-fonts-emoji
        noto-fonts-cjk

        # Audio / Media
        cava
        playerctl
        pavucontrol
        pipewire
        pipewire-alsa
        pipewire-pulse
        wireplumber
        ffnvcodec-headers

        # Wayland / Display
        rofi
        xdg-desktop-portal-hyprland

        # Utilidades sistema
        duf
        ripgrep
        aria2
        rsync
        neovim
        btop
        socat
        jq
        libnotify

        # Multimedia
        ffmpegthumbnailer

        # Bluetooth
        bluez
        bluez-utils

        # Red
        networkmanager
        ufw

        # Display manager
        sddm

        # Misc
        uwsm
        wl-clipboard
        qpwgraph

        # Gamemode
        gamemode

        # Requeridos por hypr/modules/auto-start.lua
        gnome-keyring
        geoclue
        gammastep
        trash-cli
        adw-gtk-theme
        papirus-icon-theme
        hyprpicker

        # Requeridos por hypr/hyprland.lua (binds)
        nautilus
        firefox
        qt6ct
    )

    local aur_pkgs=(
        awww
        mpvpaper
        polkit-gnome
        cliphist
        bibata-cursor-theme
        grimblast-git
        pixie-sddm-git
        python-pywal16
    )

    info "  [pacman] Instalando paquetes oficiales..."
    sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"

    info "  [${AUR_HELPER}] Instalando paquetes AUR..."
    "${AUR_HELPER}" -S --needed --noconfirm "${aur_pkgs[@]}"

    ok "Dependencias instaladas."
}

# ── 2. Caelestia ─────────────────────────────────────────────────────────────
# Instala Caelestia desde el paquete estable de AUR (caelestia-cli, ya no hace
# falta la version -git) y ejecuta `caelestia install`. Luego verifica quickshell:
# Caelestia puede instalarlo desde su repo propio (p.ej. nocatalia), en cuyo caso
# se elimina y se instala el quickshell oficial.

configure_quickshell() {
    info "Verificando quickshell (versión oficial)..."

    if pacman -Q quickshell &>/dev/null; then
        ok "  quickshell ya está instalado."

        # Caelestia suele instalar quickshell desde su repo propio (p.ej. nocatalia).
        local qs_repo="core"
        local installer_file="/var/lib/pacman/local/quickshell/INSTALLER"
        if [[ -f "${installer_file}" ]]; then
            qs_repo="$(<"${installer_file}")"
        fi

        local qs_repo_clean="${qs_repo,,}"
        if [[ "${qs_repo_clean}" != "core" && "${qs_repo_clean}" != "extra" && "${qs_repo_clean}" != "multilib" ]]; then
            warn "  quickshell proviene del repo '${qs_repo}' (instalación de Caelestia probable)."
            info "  Eliminando quickshell de '${qs_repo}' e instalando la versión oficial..."
            sudo pacman -Rns --noconfirm quickshell
            sudo pacman -S --needed --noconfirm quickshell
        fi
        ok "  Quickshell en versión oficial."

    else
        info "  quickshell no estaba instalado; instalándolo..."
        sudo pacman -S --needed --noconfirm quickshell
    fi
}

configure_caelestia() {
    info "Instalando Caelestia..."

    if ! command -v caelestia &>/dev/null; then
        info "  [${AUR_HELPER}] Instalando Caelestia (caelestia-cli)..."
        "${AUR_HELPER}" -S --needed --noconfirm caelestia-cli
        ok "  Caelestia CLI instalado."
    fi

    info "  Ejecutando 'caelestia install'..."
    caelestia install

    ok "  Caelestia instalado correctamente."

    configure_quickshell
}

# ── 3. Dotfiles personales ────────────────────────────────────────────────────
DOTS_REPO="${DOTS_REPO:-https://github.com/JoshuaCidbit/cachyos-hyprland-config.git}"
CONFIG_DIR="${HOME}/.config"

apply_dotfiles() {
    BACKUP_DIR="${HOME}/.config-backup-$(date +%Y%m%d_%H%M%S)"
    DOTS_TMP="$(mktemp -d /tmp/joshua-dots-XXXXXX)"

    # Respaldo completo previo antes de reemplazar cualquier config
    if [[ -d "${HOME}/.config" && ! -e "${HOME}/.config.bak" ]]; then
        info "Creando backup completo de ~/.config → ~/.config.bak..."
        cp -a "${HOME}/.config" "${HOME}/.config.bak"
        ok "  Backup completo creado en ${HOME}/.config.bak"
    fi

    info "Repo de dotfiles configurables: ${DOTS_REPO}"

    if ! ask "¿Clonar y aplicar el repo de dotfiles '${DOTS_REPO}'?"; then
        info "Aplicación de dotfiles omitida por el usuario."
        return 0
    fi

    info "Clonando dotfiles personales..."
    git clone --depth=1 "${DOTS_REPO}" "${DOTS_TMP}"

    local managed_folders=()
    for d in "${DOTS_TMP}"/*/; do
        [[ -d "${d}" ]] || continue
        managed_folders+=("$(basename "${d}")")
    done

    if [[ ${#managed_folders[@]} -eq 0 ]]; then
        die "No se encontraron carpetas en el repo de dotfiles, abortando."
    fi

    info "Respaldando y vaciando configs existentes antes de sincronizar..."
    mkdir -p "${BACKUP_DIR}"
    for folder in "${managed_folders[@]}"; do
        local dst="${CONFIG_DIR}/${folder}"

        if [[ -L "${dst}" ]]; then
            local real_target
            real_target="$(readlink -f "${dst}")"

            if [[ -d "${real_target}" ]]; then
                local bk="${BACKUP_DIR}/${folder}"
                mkdir -p "$(dirname "${bk}")"
                if cp -a "${real_target}/." "${bk}/" 2>/dev/null; then
                    info "  Backup: ${dst} (→ ${real_target}) → ${bk}"
                else
                    warn "  No se pudo respaldar ${real_target}, continuando."
                fi
                find "${real_target}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
                ok "  Symlink conservado: ${dst} → ${real_target} (vaciado)"
            else
                warn "  Symlink roto en ${dst}, lo recreo como carpeta normal."
                rm -f "${dst}"
                mkdir -p "${dst}"
            fi

        elif [[ -e "${dst}" ]]; then
            local bk="${BACKUP_DIR}/${folder}"
            mkdir -p "$(dirname "${bk}")"
            if cp -a "${dst}" "${bk}" 2>/dev/null; then
                info "  Backup: ${dst} → ${bk}"
            else
                warn "  No se pudo respaldar ${dst}, continuando."
            fi
            rm -rf "${dst}"
        fi
    done

    info "Aplicando dotfiles (reemplazo total, carpeta por carpeta)..."
    for folder in "${managed_folders[@]}"; do
        mkdir -p "${CONFIG_DIR}/${folder}"
        rsync -a --delete "${DOTS_TMP}/${folder}/" "${CONFIG_DIR}/${folder}/"
        ok "  Reemplazado: ${CONFIG_DIR}/${folder}"
    done

    info "Aplicando permisos de ejecución a scripts de wal/..."
    chmod +x "${CONFIG_DIR}/wal/bin/"*.sh     2>/dev/null || true
    chmod +x "${CONFIG_DIR}/wal/lib/"*.sh     2>/dev/null || true
    chmod +x "${CONFIG_DIR}/wal/scripts/"*.py 2>/dev/null || true

    # Si el backup quedó vacío (instalación limpia), no lo dejamos
    if [[ -z "$(ls -A "${BACKUP_DIR}" 2>/dev/null)" ]]; then
        rm -rf "${BACKUP_DIR}"
        BACKUP_DIR=""
    else
        warn "Backups de configs anteriores guardados en: ${BACKUP_DIR}"
    fi

    ok "Dotfiles aplicados."
}

# ── 4. Configuración de input (teclado + sensibilidad) ───────────────────────
configure_input() {
    info "Configurando hypr/hyprland/input.lua..."

    local input_file="${CONFIG_DIR}/hypr/hyprland/input.lua"
    if [[ ! -f "${input_file}" ]]; then
        warn "No se encontró ${input_file}, saltando configuración de input."
        return 0
    fi

    local kb_layout="us"
    echo ""
    echo -e "${BOLD}¿Qué layout de teclado quieres usar?${RESET}"
    echo "  [1] Inglés        (us)"
    echo "  [2] Español/Latam (latam)"
    echo -en "${BOLD}Selecciona [1/2]: ${RESET}"
    read -r layout_choice
    case "${layout_choice}" in
        2) kb_layout="latam" ;;
        *) kb_layout="us" ;;
    esac

    # kb_layout: reemplaza el valor entre comillas
    sed -i -E \
        's/(kb_layout[[:space:]]*=[[:space:]]*)"[^"]*"/\1"'"${kb_layout}"'"/' \
        "${input_file}"

    # sensitivity: reemplaza el valor numérico (positivo, negativo o cero) antes de la coma
    sed -i -E \
        's/(sensitivity[[:space:]]*=[[:space:]]*)-?[0-9]+(\.[0-9]+)?([[:space:]]*,)/\10\3/' \
        "${input_file}"

    if grep -qE "kb_layout[[:space:]]*=[[:space:]]*\"${kb_layout}\"" "${input_file}"; then
        ok "  kb_layout   → ${kb_layout}"
    else
        warn "  No se encontró ni actualizó kb_layout en ${input_file}. Revisa el archivo manualmente."
    fi

    if grep -qE "sensitivity[[:space:]]*=[[:space:]]*-?[0-9]+(\.[0-9]+)?" "${input_file}"; then
        ok "  sensitivity → 0"
    else
        warn "  No se encontró ni actualizó sensitivity en ${input_file}. Revisa el archivo manualmente."
    fi
}

# ── 5. Carpeta de wallpapers ──────────────────────────────────────────────────
ensure_wallpaper_dir() {
    info "Creando carpeta de wallpapers (si no existe)..."
    mkdir -p "${HOME}/Pictures/wallpapers/1080p"
    ok "  ${HOME}/Pictures/wallpapers/1080p lista."
}

# ── 6. Servicios del sistema ──────────────────────────────────────────────────
enable_services() {
    info "Habilitando servicios del sistema..."

    local system_services=(
        bluetooth
        NetworkManager
        ufw
    )

    # Advertencia visible y confirmación separada antes de tocar red / firewall
    echo ""
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${YELLOW}${BOLD}║        ADVERTENCIA: RED / SSH / FIREWALL     ║${RESET}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
    echo -e "  - Se habilitará NetworkManager."
    echo -e "  - Se configurará UFW con política default DENY incoming."
    echo -e "  - Si estás conectado por SSH, el firewall podría cortarte el acceso."
    echo ""
    local red_ok=false
    if ask "¿Continuar con la configuración de red / firewall (NetworkManager / UFW / SSH)?"; then
        red_ok=true
    fi

    for svc in "${system_services[@]}"; do
        # NetworkManager: solo habilitar, sin reiniciar (evita cortar la conexión activa, p.ej. SSH)
        if [[ "${svc}" == "NetworkManager" && "${red_ok}" != "true" ]]; then
            warn "  Saltando NetworkManager (no fue confirmado)."
            continue
        fi
        if sudo systemctl enable --now "${svc}" 2>/dev/null; then
            sudo systemctl restart "${svc}" 2>/dev/null || true
            ok "  Habilitado y (re)iniciado: ${svc}"
        else
            warn "  No se pudo habilitar/iniciar ${svc}."
        fi
    done

    if command -v ufw &>/dev/null; then
        if [[ "${red_ok}" == "true" ]]; then
            info "Configurando UFW..."
            sudo ufw default deny incoming
            sudo ufw default allow outgoing
            sudo ufw allow ssh
            sudo ufw --force enable
            ok "  UFW configurado."
        else
            warn "  Saltando configuración de UFW (no fue confirmado)."
        fi
    fi

    local user_services=(
        pipewire
        pipewire-pulse
        wireplumber
    )

    # Obtener UID del usuario real para construir XDG_RUNTIME_DIR
    local real_uid
    real_uid="$(id -u "${REAL_USER}")"
    local runtime_dir="/run/user/${real_uid}"

    info "Habilitando servicios de usuario para ${REAL_USER}..."
    for svc in "${user_services[@]}"; do
        # Usar machinectl si está disponible (más limpio con D-Bus completo)
        if command -v machinectl &>/dev/null && sudo machinectl shell \
            "${REAL_USER}@" /bin/systemctl --user enable "${svc}" &>/dev/null; then
            ok "  Habilitado (user, machinectl): ${svc}"

        # Fallback: exportar XDG_RUNTIME_DIR manualmente
        elif sudo -u "${REAL_USER}" \
            XDG_RUNTIME_DIR="${runtime_dir}" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=${runtime_dir}/bus" \
            systemctl --user enable "${svc}" 2>/dev/null; then
            ok "  Habilitado (user, sudo): ${svc}"

        # Último recurso: habilitar vía systemctl system-level preset
        else
            warn "  No se pudo habilitar ${svc} en vivo."
            warn "  Forzando enable con symlink directo..."
            local unit_path
            unit_path="$(sudo -u "${REAL_USER}" systemctl --user show -p FragmentPath "${svc}" \
                2>/dev/null | cut -d= -f2)"
            if [[ -n "${unit_path}" ]]; then
                local wants_dir="${REAL_HOME}/.config/systemd/user/default.target.wants"
                sudo -u "${REAL_USER}" mkdir -p "${wants_dir}"
                sudo -u "${REAL_USER}" ln -sf "${unit_path}" "${wants_dir}/${svc}.service" 2>/dev/null \
                    && ok "  Symlink creado: ${wants_dir}/${svc}.service" \
                    || warn "  Falló el symlink también — habilita ${svc} manualmente tras login."
            else
                warn "  No se encontró unit ${svc} — revisa manualmente tras login."
            fi
        fi
    done

    loginctl enable-linger "${REAL_USER}"
    ok "  Linger habilitado para ${REAL_USER}."
    
    # SDDM
    info "Configurando SDDM como display manager..."
    
    # Deshabilitar cualquier otro DM que pudiera estar activo
    for dm in gdm lightdm ly greetd lxdm; do
        if systemctl is-enabled "$dm" &>/dev/null; then
            warn "  Deshabilitando $dm (conflicto con SDDM)..."
            sudo systemctl disable --now "$dm" 2>/dev/null || true
        fi
    done
    
    # Habilitar
    if sudo systemctl enable sddm 2>/dev/null; then
        ok "  SDDM habilitado (arrancará en el próximo boot)."
    else
        warn "  No se pudo habilitar SDDM."
    fi
    
    # Iniciar ahora (sesión actual)
    if sudo systemctl start sddm.service 2>/dev/null; then
        ok "  SDDM iniciado."
    else
        warn "  No se pudo iniciar SDDM ahora — pero quedó habilitado para el próximo boot."
        warn "  Si estás en TTY puedes correr: sudo systemctl start sddm"
    fi
}

# ── 7. Sincronización de wallpaper/colores con SDDM (theme pixie) ────────────
SDDM_THEME_NAME="pixie"

configure_sddm_sync() {
    info "Configurando sincronización automática de SDDM (theme: ${SDDM_THEME_NAME})..."

    local theme_path="/usr/share/sddm/themes/${SDDM_THEME_NAME}"
    local sync_bin="/usr/local/bin/sddm-${SDDM_THEME_NAME}-sync.sh"
    local sudoers_file="/etc/sudoers.d/sddm-${SDDM_THEME_NAME}-sync"
    local theme_conf_dir="/etc/sddm.conf.d"
    local theme_conf_file="${theme_conf_dir}/theme.conf"

    if [[ ! -d "${theme_path}" ]]; then
        warn "  No se encontró ${theme_path}. ¿Está instalado el theme '${SDDM_THEME_NAME}'? Saltando."
        return 0
    fi

    info "  Estableciendo '${SDDM_THEME_NAME}' como theme activo de SDDM..."
    sudo mkdir -p "${theme_conf_dir}"
    sudo tee "${theme_conf_file}" > /dev/null <<EOF
[Theme]
Current=${SDDM_THEME_NAME}
EOF
    ok "  Theme activo configurado en ${theme_conf_file}."

    info "  Instalando wrapper en ${sync_bin}..."
    sudo tee "${sync_bin}" > /dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
SRC="${REAL_HOME}/.cache/wal"
DEST="${theme_path}"

cp -f "\$SRC/sddm_background.jpg" "\$DEST/assets/background.jpg"
cp -f "\$SRC/sddm_theme.conf" "\$DEST/theme.conf"
EOF
    sudo chmod 755 "${sync_bin}"
    ok "  Wrapper instalado."

    info "  Configurando sudoers (NOPASSWD restringido a ese script exacto)..."
    echo "${REAL_USER} ALL=(root) NOPASSWD: ${sync_bin}" | sudo tee "${sudoers_file}" > /dev/null
    sudo chmod 440 "${sudoers_file}"
    if sudo visudo -cf "${sudoers_file}" &>/dev/null; then
        ok "  Sudoers válido y aplicado."
    else
        error "  El archivo sudoers generado es inválido, eliminando por seguridad."
        sudo rm -f "${sudoers_file}"
        return 1
    fi

    local tpl_file="${CONFIG_DIR}/wal/templates/sddm_theme.conf.tpl"
    if [[ ! -f "${tpl_file}" ]]; then
        warn "  No se encontró ${tpl_file} en los dotfiles. Generándolo desde el theme.conf actual..."
        mkdir -p "$(dirname "${tpl_file}")"
        cp "${theme_path}/theme.conf" "${tpl_file}"
        warn "  ⚠ Edita ${tpl_file} y reemplaza colores con %PRIMARY% %ACCENT% %BACKGROUND% %TEXT%"
    fi

    ok "  Sincronización SDDM lista (sin password) para el theme '${SDDM_THEME_NAME}'."
}

# ── Pantalla de bienvenida ────────────────────────────────────────────────────
print_summary() {
    local aur_label="${AUR_HELPER:-yay/paru}"
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     Hyprland · Caelestia · Dotfiles          ║${RESET}"
    echo -e "${BOLD}${CYAN}║     Instalador personal — CachyOS / Arch     ║${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  AUR helper : ${BOLD}${aur_label}${RESET}"
    echo -e "  Usuario    : ${BOLD}${USER}${RESET}"
    echo -e "  Config dir : ${BOLD}${HOME}/.config${RESET}"
    echo ""
    echo "  Pasos que se ejecutarán:"
    echo "    1. Instalar dependencias (pacman + ${aur_label})"
    echo "    2. Instalar Caelestia (caelestia-cli + caelestia install, luego quickshell oficial)"
    echo "    3. Aplicar dotfiles personales (reemplazo total, conservando symlinks)"
    echo "    4. Configurar layout de teclado y sensibilidad del mouse"
    echo "    5. Crear ~/Pictures/wallpapers/1080p"
    echo "    6. Habilitar/(re)iniciar servicios del sistema"
    echo "    7. Configurar sincronización automática SDDM (wallpaper + colores)"
    echo ""
    echo -e "${YELLOW}  AVISO: Se instalarán paquetes y se modificará ~/.config${RESET}"
    echo -e "${YELLOW}  RECUERDA: Tener Caelestia instalado (caelestia-cli + caelestia install)${RESET}"
    echo -e "  yay -S caelestia-cli y despues caelestia install"
    echo ""
}

# ── Mensaje de cierre ─────────────────────────────────────────────────────────
print_done() {
    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}║          ¡Instalación completada!            ║${RESET}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "  Pasos recomendados antes de reiniciar:"
    echo ""
    echo -e "  ${BOLD}1. Inicializar pywal${RESET} (genera colores y symlinks en ~/.cache/wal/):"
    echo "     wal -i ~/Pictures/wallpapers/1080p/<tu-imagen>"
    echo ""
    echo -e "  ${BOLD}2. Agregar wallpapers${RESET} para el launcher de Caelestia:"
    echo "     ~/Pictures/wallpapers/1080p/"
    echo ""
    echo -e "  ${BOLD}3. Reiniciar sesión${RESET} (logout o reboot) para cargar Hyprland con SDDM."
    echo ""
    if [[ -n "${BACKUP_DIR}" && -d "${BACKUP_DIR}" ]]; then
        echo -e "  ${YELLOW}Tus configs anteriores están en: ${BACKUP_DIR}${RESET}"
        echo ""
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    check_not_root
    check_distro
    detect_aur_helper
    resolve_real_user
    check_caelestia

    print_summary
    ask "¿Deseas continuar con la instalación?" || { info "Instalación cancelada."; exit 0; }
    echo ""

    check_script_deps

    install_deps
    configure_caelestia
    apply_dotfiles
    configure_input
    ensure_wallpaper_dir
    enable_services
    configure_sddm_sync

    print_done
}

main "$@"
