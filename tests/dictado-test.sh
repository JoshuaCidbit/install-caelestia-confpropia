#!/usr/bin/env bash
# Prueba principal de configure_dictation() sobre un HOME falso.
# No toca el HOME real: ni ~/.local/share/com.pais.handy ni ~/.config/hypr.
set -Eeuo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

FAKE="${WORK_ROOT}/home-dictado"

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
  "app_language": "en-US",
  "selected_language": "en",
  "spoken_languages": ["en"],
  "paste_method": "shift_shift",
  "clipboard_handling": "dont_modify",
  "paste_delay_after_ms": 300,
  "filler_word_removal_enabled": false,
  "custom_filler_words": ["um", "uh"],
  "custom_words": ["zzz"],
  "post_process_enabled": true,
  "post_process_api_keys": {"custom": "MARCADOR-QUE-NO-DEBE-CAMBIAR"},
  "post_process_models": {"custom": "modelo-viejo"},
  "post_process_prompts": [{"id": "otro", "name": "Otro", "prompt": "no tocar"}],
  "post_process_providers": [{"id": "custom", "label": "Custom", "base_url": "https://viejo.example/v1"}],
  "post_process_provider_id": "openrouter",
  "post_process_selected_prompt_id": "otro",
  "autostart_enabled": false,
  "append_trailing_space": false,
  "start_hidden": false,
  "overlay_style": "none",
  "onboarding_completed": false,
  "shortcut_activation": "hold_or_toggle",
  "history_limit": 5,
  "experimental_enabled": false,
  "bindings": {"transcribe": {"current_binding": "ctrl+alt+space"}}
}'

configure_dictation
info "configure_dictation terminó"

python3 - "${FAKE}" "${SRC_DIR}" "${FAKE_HANDY_DIR}" <<'PY'
import glob, json, os, re, sys

home, src, subdir = sys.argv[1:4]
fallas = []


def chk(cond, msg):
    print(("  OK    " if cond else "  FALLA ") + msg)
    if not cond:
        fallas.append(msg)


md = open(src + "/dictado.md", encoding="utf-8").read()
# Referencia "viva": si existe el hook/prompt canónicos en esta máquina,
# se comparan; si no, se omite (la prueba sigue siendo válida y portable).
home_real = os.path.expanduser("~")
hook_vivo = None
ruta_hook_vivo = home_real + "/" + subdir + "/hooks/transcription"
if os.path.isfile(ruta_hook_vivo):
    hook_vivo = open(ruta_hook_vivo, encoding="utf-8").read()
p_ref = None
ruta_p_ref = "/home/joshua/pruebas_opencode/dictado/prompt-final.txt"
if os.path.isfile(ruta_p_ref):
    p_ref = open(ruta_p_ref, encoding="utf-8").read()


def bloque(tag):
    patron = r"<!-- handy:%s:begin -->\s*```[a-zA-Z]*\n(.*?)\n```\s*<!-- handy:%s:end -->" % (tag, tag)
    m = re.search(patron, md, re.S)
    return m.group(1).rstrip("\n") + "\n" if m else None


p_md = bloque("prompt")
h_md = bloque("hook")

st_path = home + "/" + subdir + "/settings_store.json"
st = json.load(open(st_path))
s = st["settings"]

pid = "es_limpieza_dictado"
prompts = {p["id"]: p["prompt"] for p in s["post_process_prompts"]}

chk(p_md is not None, "bloque de prompt localizado en dictado.md")
chk(prompts.get(pid) == p_md, "prompt aplicado == bloque de dictado.md")
if p_ref is not None:
    chk(prompts.get(pid) == p_ref, "prompt aplicado == copia canónica del repo de docs")
else:
    print("  --    copia canónica de prompt ausente; se omite la comparación")
chk((prompts.get(pid) or "").count("${output}") == 1, "${output} exactamente una vez")
chk([p["id"] for p in s["post_process_prompts"]].count(pid) == 1, "no duplica el prompt")
chk(s["post_process_selected_prompt_id"] == pid, "prompt seleccionado")
chk([p["id"] for p in s["post_process_prompts"]] == ["otro", pid], "prompt ajeno conservado")

chk(s["post_process_provider_id"] == "custom", "proveedor custom")
prov = [p for p in s["post_process_providers"] if p.get("id") == "custom"][0]
chk(prov["base_url"] == "https://openrouter.ai/api/v1", "base_url")
chk(prov["api_format"] == "openai", "api_format")
chk(prov["supports_structured_output"] is False, "supports_structured_output false")
chk(s["post_process_models"]["custom"] == "nvidia/nemotron-3.5-lightning:free", "modelo")

chk(s["paste_method"] == "ctrl_v", "paste_method")
chk(s["clipboard_handling"] == "copy_to_clipboard", "clipboard_handling")
chk(s["paste_delay_after_ms"] == 150, "paste_delay_after_ms")
chk(s["filler_word_removal_enabled"] is True, "filler_word_removal_enabled")
chk(s["custom_filler_words"] is None, "custom_filler_words None")
chk(s["custom_words"] == ["Students", "AWS", "CI/CD", "GitHub", "SQLite", "AGENTS", "README"], "custom_words")
chk(s["post_process_enabled"] is True, "post_process_enabled")
chk(s["app_language"] == "es-ES", "app_language")
chk(s["selected_language"] == "auto", "selected_language")
chk(s["spoken_languages"] == ["es", "en"], "spoken_languages")
chk(s["autostart_enabled"] is True, "autostart_enabled")
chk(s["append_trailing_space"] is True, "append_trailing_space")
chk(s["start_hidden"] is True, "start_hidden")
chk(s["overlay_style"] == "minimal", "overlay_style")
chk(s["onboarding_completed"] is True, "onboarding_completed")
chk(s["shortcut_activation"] == "toggle", "shortcut_activation")
chk(s["history_limit"] == 20, "history_limit")
chk(s["experimental_enabled"] is True, "experimental_enabled")
chk(s["bindings"]["transcribe"]["current_binding"] == "ctrl+shift+d", "binding interno")

chk(s["post_process_api_keys"]["custom"] == "MARCADOR-QUE-NO-DEBE-CAMBIAR", "API key intacta")

hook_dest = home + "/" + subdir + "/hooks/transcription"
contenido = open(hook_dest, encoding="utf-8").read() if os.path.isfile(hook_dest) else ""
chk(os.path.isfile(hook_dest), "hook instalado")
chk(contenido == h_md, "hook == bloque de dictado.md")
if hook_vivo is not None:
    chk(contenido == hook_vivo, "hook == hook instalado en el HOME real")
else:
    print("  --    hook del HOME real ausente; se omite la comparación")
chk(os.access(hook_dest, os.X_OK), "hook ejecutable")

vars_txt = open(home + "/.config/hypr/variables.lua", encoding="utf-8").read()
kb_txt = open(home + "/.config/hypr/hyprland/keybinds.lua", encoding="utf-8").read()
chk("kbDictado" in vars_txt, "kbDictado en variables.lua")
chk(vars_txt.count("kbDictadoCrudo") == 1, "kbDictadoCrudo una vez")
chk(kb_txt.count("kbDictado") == 2, "dos binds de dictado")
chk("handy --toggle-post-process" in kb_txt and "handy --toggle-transcription" in kb_txt, "comandos de los binds")

baks = glob.glob(st_path + ".bak.*")
chk(len(baks) == 1, "un respaldo de settings")
if baks:
    old = json.load(open(baks[0]))["settings"]
    chk(old["paste_method"] == "shift_shift" and old["post_process_models"]["custom"] == "modelo-viejo",
        "respaldo conserva valores previos")

print("\nRESULTADO: %d fallas" % len(fallas))
sys.exit(1 if fallas else 0)
PY
