#!/usr/bin/env bash
# =============================================================================
#  install.sh — Hyprland / Caelestia + dotfiles personales
#  Compatible con: Arch / CachyOS / Manjaro
#
#  Qué hace este script, en orden:
#    1. Verifica distro y herramientas necesarias (git, curl, yay/paru)
#    2. Instala dependencias del sistema (pacman + AUR)
#    3. Instala Caelestia vía AUR (caelestia-cli-git) + `caelestia install`
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
    # Pregunta sí/no interactiva. Devuelve 0 (true) si el usuario responde s/si/sí.
    echo -en "${BOLD}$1 [s/N]: ${RESET}"
    read -r reply
    [[ "${reply,,}" == "s" || "${reply,,}" == "si" || "${reply,,}" == "sí" ]]
}

# ── Limpieza en caso de interrupción ─────────────────────────────────────────
DOTS_TMP=""
cleanup() {
    if [[ -n "${DOTS_TMP}" && -d "${DOTS_TMP}" ]]; then
        warn "Limpiando archivos temporales..."
        rm -rf "${DOTS_TMP}"
    fi
}
trap cleanup EXIT INT TERM

# ── 0. Verificaciones previas ─────────────────────────────────────────────────

check_not_root() {
    # El script debe correr como usuario normal; sudo se llama internamente
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

# ── 1. Dependencias del sistema ───────────────────────────────────────────────
install_deps() {
    info "Instalando dependencias del sistema..."

    # Paquetes de repositorios oficiales
    local pacman_pkgs=(

	# yay por si no lo tiene
	yay

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
        pipewire-alsa
        pipewire-pulse
        wireplumber
	ffnvcodec-headers

        # Wayland / Display
        rofi
        flameshot
        xdg-desktop-portal-hyprland

        # Theming
        python-pywal

        # Utilidades sistema
        duf
        ripgrep
        aria2
        rsync
        neovim
        btop
        socat
        jq
        libnotify        # provee notify-send para notificaciones

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
        gnome-keyring         # gnome-keyring-daemon (secrets para Firefox/NM)
        geoclue               # ubicación para gammastep
        gammastep              # night light
        trash-cli              # trash-empty
        adw-gtk-theme           # tema GTK adw-gtk3-dark
        papirus-icon-theme      # iconos Papirus-Dark
        hyprpicker              # color picker (SUPER+SHIFT+C)

        # Requeridos por hypr/hyprland.lua (binds)
        nautilus
        firefox
        qt6ct                 # QT_QPA_PLATFORMTHEME=qt6ct

    )

    # Paquetes AUR (no están en repos oficiales)
    local aur_pkgs=(
        awww             # Wallpaper daemon (animados estáticos)
	mpvpaper

        # Requeridos por hypr/modules/auto-start.lua
        polkit-gnome          # agente de autenticación polkit
        cliphist              # historial de clipboard
        bibata-cursor-theme   # cursor Bibata-Modern-Classic

        # Requerido por hypr/hyprland.lua (bind de screenshot)
        grimblast-git
    )

    info "  [pacman] Instalando paquetes oficiales..."
    sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"

    info "  [${AUR_HELPER}] Instalando paquetes AUR..."
    "${AUR_HELPER}" -S --needed --noconfirm "${aur_pkgs[@]}"

    ok "Dependencias instaladas."
}

# ── 2. Caelestia ─────────────────────────────────────────────────────────────
install_caelestia() {
    info "Instalando Caelestia (caelestia-cli-git)..."

    # Tiene que ser la versión -git: la versión estable del AUR todavía no
    # incluye el subcomando `caelestia install`.
    "${AUR_HELPER}" -S --needed caelestia-cli-git

    info "Ejecutando 'caelestia install'..."
    caelestia install

    ok "Caelestia instalado."
}

# ── 3. Dotfiles personales ────────────────────────────────────────────────────
DOTS_REPO="https://github.com/JoshuaCidbit/cachyos-hyprland-config.git"
CONFIG_DIR="${HOME}/.config"
BACKUP_DIR="${HOME}/.config-backup-$(date +%Y%m%d_%H%M%S)"

apply_dotfiles() {
    DOTS_TMP="$(mktemp -d /tmp/joshua-dots-XXXXXX)"

    info "Clonando dotfiles personales..."
    git clone --depth=1 "${DOTS_REPO}" "${DOTS_TMP}"

    # Caelestia deja varias carpetas (hypr, kitty, fish, btop) como symlinks
    # hacia ~/.local/share/caelestia/. Nuestra config es la versión completa
    # (no un parche), así que hacemos backup del contenido real
    # (dereferenciando symlinks) antes de que rsync escriba encima.
    info "Respaldando configs existentes antes de sincronizar..."
    mkdir -p "${BACKUP_DIR}"
    for folder in hypr kitty fish btop cava wal; do
        local dst="${CONFIG_DIR}/${folder}"
        if [[ -L "${dst}" || -e "${dst}" ]]; then
            local bk="${BACKUP_DIR}/${folder}"
            mkdir -p "$(dirname "${bk}")"
            if cp -aL "${dst}" "${bk}" 2>/dev/null; then
                info "  Backup: ${dst} → ${bk}"
            else
                warn "  No se pudo respaldar ${dst} (symlink roto o sin permisos), continuando."
            fi
            # Si era un symlink (caso Caelestia), lo quitamos para que rsync
            # no escriba a través de él hacia el directorio de Caelestia.
            [[ -L "${dst}" ]] && rm -f "${dst}"
        fi
    done

    info "Aplicando dotfiles con rsync sobre ${CONFIG_DIR}..."
    rsync -av \
        --exclude='.git' \
        --exclude='README*' \
        --exclude='install.sh' \
        --exclude='LICENSE*' \
        "${DOTS_TMP}/" "${CONFIG_DIR}/"

    # Permisos de ejecución para todos los scripts
    info "Aplicando permisos de ejecución a scripts de wal/..."
    chmod +x "${CONFIG_DIR}/wal/bin/"*.sh     2>/dev/null || true
    chmod +x "${CONFIG_DIR}/wal/lib/"*.sh     2>/dev/null || true
    chmod +x "${CONFIG_DIR}/wal/scripts/"*.py 2>/dev/null || true

    # Si el backup quedó vacío (instalación limpia), no lo dejamos
    if [[ -z "$(ls -A "${BACKUP_DIR}" 2>/dev/null)" ]]; then
        rm -rf "${BACKUP_DIR}"
    else
        warn "Backups de configs anteriores guardados en: ${BACKUP_DIR}"
    fi

    # El trap de EXIT limpia DOTS_TMP automáticamente
    ok "Dotfiles aplicados."
}

# ── 4. Configuración de input (teclado + sensibilidad) ───────────────────────
configure_input() {
    info "Configurando hypr/modules/input.lua..."

    local input_file="${CONFIG_DIR}/hypr/modules/input.lua"
    if [[ ! -f "${input_file}" ]]; then
        warn "No se encontró ${input_file}, saltando configuración de input."
        return 0
    fi

    local kb_layout="us"
    echo ""
    echo -e "${BOLD}¿Qué layout de teclado quieres usar?${RESET}"
    echo "  [1] Inglés      (us)"
    echo "  [2] Español/Latam (latam)"
    echo -en "${BOLD}Selecciona [1/2]: ${RESET}"
    read -r layout_choice
    case "${layout_choice}" in
        2) kb_layout="latam" ;;
        *) kb_layout="us" ;;
    esac

    sed -i \
        -e "s/kb_layout[[:space:]]*=[[:space:]]*\"[^\"]*\"/kb_layout         = \"${kb_layout}\"/" \
        -e "s/sensitivity[[:space:]]*=[[:space:]]*-\?[0-9.]\+/sensitivity = 0/" \
        "${input_file}"

    ok "  kb_layout   → ${kb_layout}"
    ok "  sensitivity → 0"
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

    # Servicios a nivel sistema (requieren sudo)
    local system_services=(
        sddm            # Display manager (login gráfico)
        bluetooth       # Bluetooth
        NetworkManager  # Gestión de red
        ufw             # Firewall
    )

    for svc in "${system_services[@]}"; do
        if systemctl list-unit-files --type=service | grep -q "^${svc}.service"; then
            sudo systemctl enable --now "${svc}"
            ok "  Habilitado: ${svc}"
        else
            warn "  Servicio no encontrado, saltando: ${svc}"
        fi
    done

    # UFW: política básica para workstation
    if command -v ufw &>/dev/null; then
        info "Configurando UFW..."
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw --force enable
        ok "  UFW configurado (deny incoming / allow outgoing)."
    fi

    # Servicios a nivel usuario (sin sudo, corren en la sesión)
    local user_services=(
        pipewire        # Servidor de audio principal
        pipewire-pulse  # Compatibilidad con PulseAudio
        wireplumber     # Session manager de PipeWire
    )

    info "Habilitando servicios de usuario..."
    for svc in "${user_services[@]}"; do
        if systemctl --user list-unit-files --type=service | grep -q "^${svc}.service"; then
            systemctl --user enable --now "${svc}"
            ok "  Habilitado (user): ${svc}"
        else
            warn "  Servicio de usuario no encontrado, saltando: ${svc}"
        fi
    done

    ok "Servicios configurados."
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
    echo "    2. Instalar Caelestia (caelestia-cli-git + caelestia install)"
    echo "    3. Aplicar dotfiles personales con rsync (con backup automático)"
    echo "    4. Configurar layout de teclado y sensibilidad del mouse"
    echo "    5. Crear ~/Pictures/wallpapers/1080p"
    echo "    6. Habilitar servicios del sistema"
    echo ""
    echo -e "${YELLOW}  AVISO: Se instalarán paquetes y se modificará ~/.config${RESET}"
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
    echo "     ~/Pictures/wallpapers/1080p/ (número impar de imágenes)"
    echo ""
    echo -e "  ${BOLD}3. Reiniciar sesión${RESET} (logout o reboot) para cargar Hyprland con SDDM."
    echo ""
    if [[ -d "${BACKUP_DIR:-}" ]]; then
        echo -e "  ${YELLOW}Tus configs anteriores están en: ${BACKUP_DIR}${RESET}"
        echo ""
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    check_not_root
    check_distro
    detect_aur_helper

    print_summary
    ask "¿Deseas continuar con la instalación?" || { info "Instalación cancelada."; exit 0; }
    echo ""

    check_script_deps

    install_deps
    install_caelestia
    apply_dotfiles
    configure_input
    ensure_wallpaper_dir
    enable_services

    print_done
}

main "$@"