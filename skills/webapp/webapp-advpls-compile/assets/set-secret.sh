#!/usr/bin/env bash
# webapp-advpls-compile - guarda a senha do TDS no cofre do SO.
#   macOS -> Keychain (security)
#   Linux -> libsecret (secret-tool)
# Pede a senha interativamente (nao ecoa) e armazena. A senha so passa pelas
# suas maos - rode NO SEU TERMINAL (um agente nao-interativo nao consegue).
#
# Uso:
#   ./set-secret.sh             # nome 'default'
#   ./set-secret.sh mistral-demo
set -euo pipefail

NAME="${1:-default}"
OS="$(uname -s)"

printf "Senha TDS para '%s': " "$NAME" >&2
read -rs PSW
echo >&2
[ -n "$PSW" ] || { echo "Senha vazia - nada gravado." >&2; exit 1; }

case "$OS" in
  Darwin)
    security add-generic-password -U -s "tds-advpls" -a "$NAME" -w "$PSW"
    echo "OK - salvo no Keychain (service=tds-advpls account=$NAME)."
    ;;
  Linux)
    command -v secret-tool >/dev/null 2>&1 || { echo "secret-tool (libsecret) nao instalado." >&2; exit 1; }
    printf '%s' "$PSW" | secret-tool store --label="tds-advpls:$NAME" service tds-advpls account "$NAME"
    echo "OK - salvo no libsecret (service=tds-advpls account=$NAME)."
    ;;
  *)
    echo "SO nao suportado: $OS" >&2; exit 1 ;;
esac

unset PSW
