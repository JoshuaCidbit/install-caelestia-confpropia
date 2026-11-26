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
2. Instala dependencias del sistema (pacman + AUR; incluye `python-pywal16` y `handy-bin`).
3. Verifica/instala Caelestia (`caelestia-cli` desde AUR) y ejecuta `caelestia install`.
4. Verifica quickshell: si `caelestia install` instaló el de nocatalia, lo elimina e instala el oficial.
5. Aplica dotfiles personales (clona el repo, respalda y rsync).
6. Configura layout de teclado y sensibilidad del mouse.
7. Configura el dictado por voz (Handy): prompt de limpieza, hook de saneado, vocabulario ASR y atajos.
8. Crea `~/Pictures/wallpapers/1080p`.
9. Habilita/(re)inicia servicios del sistema (con confirmación visible para red/SSH).
10. Configura sincronización automática SDDM (wallpaper + colores).

## Uso
```bash
chmod +x install.sh && ./install.sh
./install.sh --solo-dictado    # reconfigura solo el dictado (Handy)
```

## Dictado (Handy)
- `dictado.md` (junto al script) es la guía completa: **el prompt y el hook
  exactos** que el instalador aplica, elección del modelo ASR según GPU/CPU,
  ajustes, atajos y prueba de humo.
- El script instala `handy-bin`, aplica el prompt y el hook, configura el
  vocabulario ASR, añade los atajos (`SUPER+SHIFT+D` limpio,
  `SUPER+SHIFT+ALT+D` crudo) y respalda `settings_store.json` antes de tocarlo.
- En una máquina nueva, si Handy nunca ha arrancado, el script lo abre una vez
  para que cree `settings_store.json` y marca `onboarding_completed`; entra
  directo en **Ajustes → Modelos** y descarga el ASR. Si algo no se aplicó,
  repite `./install.sh --solo-dictado`.

Quedan dos pasos manuales, ambos desde la GUI de Handy:

1. Pegar la **API key de OpenRouter** (o de un proveedor aceptado) en
   Ajustes → Post-Processing → proveedor **Custom**. Modelo sugerido:
   `nvidia/nemotron-3.5-lightning:free`.
2. Elegir y descargar el modelo de ASR: Whisper Large v3 Turbo si hay GPU
   NVIDIA; Parakeet Ultra o Canary 180M Flash en CPU.

La API key **nunca** se escribe en este directorio, en dotfiles ni en la
consola: vive solo en los ajustes de Handy.

## Pruebas
```bash
./tests/run-tests.sh            # todas (menos las que necesitan GUI)
./tests/run-tests.sh --todo     # incluye el primer arranque con Handy real
```
Corren `configure_dictation()` contra un `$HOME` falso con stubs de
`pacman`/`sudo`/`pgrep`, así que no tocan ni Handy ni `~/.config/hypr`.
Comprueban el prompt y el hook contra los bloques de `dictado.md`, los ajustes,
los atajos, el respaldo de `settings_store.json` y que la API key no se toca.
En CI además se pasa ShellCheck a `install.sh` y a los scripts de `tests/`.

## Variables de entorno
- `DOTS_REPO`: repo de dotfiles a clonar/aplicar. Default: `https://github.com/JoshuaCidbit/cachyos-hyprland-config.git`

## Backups
- Antes de aplicar dotfiles se crea un backup completo en `~/.config.bak`.
- Si hay configs previas, se conservan en `~/.config-backup-YYYYMMDD_HHMMSS`.
- Antes de tocar `settings_store.json` se guarda `settings_store.json.bak.<fecha>`.

## Notas
- El script pide confirmación antes de instalar paquetes, clonar/aplicar dotfiles, configurar red/firewall, configurar dictado y de todo lo demás.
- Tras la instalación recomendada: inicializar pywal (`wal -i ~/Pictures/wallpapers/1080p/<tu-imagen>`), agregar wallpapers y reiniciar sesión.
