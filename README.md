# install-caelestia-confpropia

Script de instalación de la configuración personal de Hyprland + Caelestia para Arch / CachyOS / Manjaro.

## Requisitos previos

- **Caelestia** (requisito previo que el script verifica):
  ```bash
  yay -S caelestia-cli
  caelestia install
  ```
- AUR helper (`yay` o `paru`)
- `pacman` (Arch / CachyOS / Manjaro)
- No ejecutar el script directamente como root (pide sudo cuando hace falta)

## Qué hace el script

1. Verifica distro y herramientas necesarias (git, curl, yay/paru).
2. Instala dependencias del sistema (pacman + AUR; incluye `python-pywal16`).
3. Verifica/instala Caelestia (`caelestia-cli` desde AUR) y ejecuta `caelestia install`.
4. Verifica quickshell: si `caelestia install` instaló el de nocatalia, lo elimina e instala el oficial.
5. Aplica dotfiles personales (clona el repo, respalda y rsync).
6. Configura layout de teclado y sensibilidad del mouse.
7. Crea `~/Pictures/wallpapers/1080p`.
8. Habilita/(re)inicia servicios del sistema (con confirmación visible para red/SSH).
9. Configura sincronización automática SDDM (wallpaper + colores).

## Uso

```bash
chmod +x install.sh && ./install.sh
```

## Variables de entorno

- `DOTS_REPO`: repo de dotfiles a clonar/aplicar. Default: `https://github.com/JoshuaCidbit/cachyos-hyprland-config.git`

## Backups

- Antes de aplicar dotfiles se crea un backup completo en `~/.config.bak`.
- Si hay configs previas, se conservan en `~/.config-backup-YYYYMMDD_HHMMSS`.

## Notas

- El script pide confirmación antes de instalar paquetes, clonar/aplicar dotfiles, configurar red/firewall y de todo lo demás.
- Tras la instalación recomendada: inicializar pywal (`wal -i ~/Pictures/wallpapers/1080p/<tu-imagen>`), agregar wallpapers y reiniciar sesión.
