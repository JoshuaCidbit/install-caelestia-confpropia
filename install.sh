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
    "${AUR_HELPER}" -S --needed --noconfirm caelestia-cli-git

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

    # Detectamos dinámicamente las carpetas de nivel superior del repo
    # (hypr, kitty, fish, btop, cava, wal, ...). Así no hace falta mantener
    # una lista hardcodeada ni excluir README/LICENSE/install.sh: esos son
    # archivos sueltos en la raíz del repo, no carpetas, y el glob */ los
    # ignora automáticamente.
    local managed_folders=()
    for d in "${DOTS_TMP}"/*/; do
        [[ -d "${d}" ]] || continue
        managed_folders+=("$(basename "${d}")")
    done

    if [[ ${#managed_folders[@]} -eq 0 ]]; then
        die "No se encontraron carpetas en el repo de dotfiles, abortando."
    fi

    # Caelestia deja varias carpetas (hypr, kitty, fish, btop) como symlinks
    # hacia ~/.local/share/caelestia/. Queremos CONSERVAR esos symlinks (para
    # no romper la integración con Caelestia), pero vaciar por completo el
    # contenido real al que apuntan, para que la sincronización posterior sea
    # un reemplazo total y no un merge. Las carpetas que no son symlinks
    # (directorios normales) sí se borran y se recrean vacías.
    info "Respaldando y vaciando configs existentes antes de sincronizar..."
    mkdir -p "${BACKUP_DIR}"
    for folder in "${managed_folders[@]}"; do
        local dst="${CONFIG_DIR}/${folder}"

        if [[ -L "${dst}" ]]; then
            # Es un symlink (caso Caelestia): respaldamos el contenido real
            # y vaciamos el directorio destino, SIN tocar el enlace.
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
                # Vacía el contenido real (incluye archivos ocultos) pero
                # conserva el symlink ${dst} -> ${real_target} intacto.
                find "${real_target}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
                ok "  Symlink conservado: ${dst} → ${real_target} (vaciado)"
            else
                warn "  Symlink roto en ${dst}, lo recreo como carpeta normal."
                rm -f "${dst}"
                mkdir -p "${dst}"
            fi

        elif [[ -e "${dst}" ]]; then
            # Directorio (u otro archivo) normal, sin symlink que conservar.
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

# ── 5. Configuración de monitores ─────────────────────────────────────────────
reset_monitors_config() {
    info "Limpiando hypr/modules/monitors.lua..."

    local monitors_file="${CONFIG_DIR}/hypr/modules/monitors.lua"
    mkdir -p "$(dirname "${monitors_file}")"

    cat > "${monitors_file}" <<'EOF'
-- ============================================================
--  modules/monitors.lua
-- ============================================================
-- Este archivo se dejó intencionalmente vacío de configuración.
--
-- La configuración de monitores (resolución, posición, refresco,
-- escalado) depende de CADA equipo. Un valor "de fábrica" aquí
-- puede causar problemas como: el launcher de Caelestia sin
-- contenido, colores de wallpaper que no se generan, o texto
-- que no se renderiza bien en Firefox/apps (por escalado mal
-- aplicado).
--
-- Antes de configurar tus monitores, ejecuta en una terminal:
--
--     hyprctl monitors
--
-- Eso te dará el nombre, resolución, tasa de refresco y posición
-- de cada monitor conectado. Con esos datos, agrega tu propio
-- bloque hl.config({ monitor = { ... } }) en este archivo según
-- la documentación de Hyprland 0.55 (Lua config / hl.config).

hl.config({})
EOF

    ok "  monitors.lua reseteado. Ejecuta 'hyprctl monitors' y configura el tuyo manualmente."
}

# ── 6. Carpeta de wallpapers ──────────────────────────────────────────────────
ensure_wallpaper_dir() {
    info "Creando carpeta de wallpapers (si no existe)..."
    mkdir -p "${HOME}/Pictures/wallpapers/1080p"
    ok "  ${HOME}/Pictures/wallpapers/1080p lista."
}

# ── 7. Servicios del sistema ──────────────────────────────────────────────────
enable_services() {
    info "Habilitando servicios del sistema..."

    # Servicios a nivel sistema (requieren sudo). En vez de pre-filtrar con
    # `systemctl list-unit-files | grep`, intentamos habilitar/iniciar
    # directamente: ese grep era frágil (formato de columnas, unidades vía
    # socket-activation, alias, etc.) y terminaba saltándose servicios que
    # sí existían. Si ya estaba activo, lo reiniciamos para asegurar que
    # tome la configuración recién aplicada.
    local system_services=(
        sddm            # Display manager (login gráfico)
        bluetooth       # Bluetooth
        NetworkManager  # Gestión de red
        ufw             # Firewall
    )

    for svc in "${system_services[@]}"; do
        if sudo systemctl enable --now "${svc}" 2>/dev/null; then
            sudo systemctl restart "${svc}" 2>/dev/null || true
            ok "  Habilitado y (re)iniciado: ${svc}"
        else
            warn "  No se pudo habilitar/iniciar ${svc} (revisa si el paquete lo instaló)."
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

    # Servicios a nivel usuario (sin sudo, corren en la sesión). Mismo
    # criterio: intentar directamente en vez de pre-filtrar con grep.
    local user_services=(
        pipewire        # Servidor de audio principal
        pipewire-pulse  # Compatibilidad con PulseAudio
        wireplumber     # Session manager de PipeWire
    )

    info "Habilitando servicios de usuario..."
    for svc in "${user_services[@]}"; do
        if systemctl --user enable --now "${svc}" 2>/dev/null; then
            systemctl --user restart "${svc}" 2>/dev/null || true
            ok "  Habilitado y (re)iniciado (user): ${svc}"
        else
            warn "  No se pudo habilitar/iniciar (user) ${svc} (puede usar activación por socket, revisa manualmente)."
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
    echo "    3. Aplicar dotfiles personales (reemplazo total, conservando symlinks)"
    echo "    4. Configurar layout de teclado y sensibilidad del mouse"
    echo "    5. Resetear hypr/modules/monitors.lua (configúralo tú con hyprctl monitors)"
    echo "    6. Crear ~/Pictures/wallpapers/1080p"
    echo "    7. Habilitar/(re)iniciar servicios del sistema"
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
    echo -e "  ${BOLD}3. Configurar tus monitores${RESET} (se dejó vacío a propósito):"
    echo "     hyprctl monitors"
    echo "     → edita ~/.config/hypr/modules/monitors.lua con esos datos"
    echo ""
    echo -e "  ${BOLD}4. Reiniciar sesión${RESET} (logout o reboot) para cargar Hyprland con SDDM."
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
    reset_monitors_config
    ensure_wallpaper_dir
    enable_services

    print_done
}

main "$@"
