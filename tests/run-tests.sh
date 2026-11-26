#!/usr/bin/env bash
# Ejecuta todas las pruebas del directorio tests/.
#
#   ./tests/run-tests.sh          # todas excepto las que necesitan GUI
#   ./tests/run-tests.sh --todo   # incluye autoarranque (lanza Handy real)
#
# Requisitos: bash, python3 (y, para el lint, shellcheck).
set -Euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODOS="${1:-}"

# Las pruebas que usan el `handy` real o una sesión gráfica no van en CI.
PRUEBAS_GUI=(autoarranque-test.sh)

fallaron=()
omitidas=()
pasaron=()

for prueba in "${ROOT}"/*-test.sh; do
    nombre="$(basename "${prueba}")"
    [[ -x "${prueba}" ]] || chmod +x "${prueba}"

    omitir=no
    for gui in "${PRUEBAS_GUI[@]}"; do
        [[ "${nombre}" == "${gui}" && "${TODOS}" != "--todo" ]] && omitir=si
    done
    if [[ "${omitir}" == "si" ]]; then
        omitidas+=("${nombre}")
        continue
    fi

    echo "──────── ${nombre} ────────"
    if "${prueba}" >/tmp/"${nombre}".log 2>&1; then
        tail -3 /tmp/"${nombre}".log
        pasaron+=("${nombre}")
    else
        cat /tmp/"${nombre}".log
        fallaron+=("${nombre}")
    fi
    echo ""
done

echo "════════════════════════════════════════"
echo "Pasaron:  ${#pasaron[@]}  (${pasaron[*]:-ninguna})"
echo "Fallaron: ${#fallaron[@]}  (${fallaron[*]:-ninguna})"
if [[ ${#omitidas[@]} -gt 0 ]]; then
    echo "Omitidas: ${#omitidas[@]}  (${omitidas[*]}) — requieren GUI/Handy real"
fi

[[ ${#fallaron[@]} -eq 0 ]]
