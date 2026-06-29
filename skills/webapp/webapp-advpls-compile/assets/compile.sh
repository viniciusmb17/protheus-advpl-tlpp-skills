#!/usr/bin/env bash
# webapp-advpls-compile - wrapper macOS/Linux. Compila headless via "advpls cli".
#
# Dois modos:
#   - secret store (recomendado, default): --profile aponta um .ini SEM senha
#     (linha "psw=__PSW__"). A senha vem do Keychain (mac) / libsecret (Linux),
#     ver set-secret.sh. Gera um .ini TRANSIENTE (mktemp), roda e apaga (trap).
#   - arquivo direto (legado): --ini aponta um .ini COMPLETO (com psw).
# Em ambos, descobre o binario advpls na extensao TOTVS.tds-vscode mais recente.
#
# Opcoes:
#   --workdir <dir>   pasta de trabalho (perfil + logs). Default: <repo>/tmp/advpls
#   --profile <ini>   perfil .ini sem senha. Default: <workdir>/compile.profile.ini
#   --secret <nome>   nome do segredo no Keychain/libsecret. Default: default
#   --ini <ini>       modo legado: .ini COMPLETO com psw
#
# Uso:
#   ./compile.sh
#   ./compile.sh --secret mistral-demo --workdir "$HOME/.advpls/portal"
#   ./compile.sh --ini /abs/compile.ini
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

WORKDIR="" ; PROFILE="" ; SECRET="default" ; INI=""
while [ $# -gt 0 ]; do
  case "$1" in
    --workdir) WORKDIR="${2:-}"; shift 2 ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --secret)  SECRET="${2:-}";  shift 2 ;;
    --ini)     INI="${2:-}";     shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "arg desconhecido: $1" >&2; exit 2 ;;
  esac
done
[ -n "$WORKDIR" ] || WORKDIR="$REPO_ROOT/tmp/advpls"

# --- descobrir o binario advpls ---
EXT_ROOT="$HOME/.vscode/extensions"
EXT_DIR="$(ls -d "$EXT_ROOT"/totvs.tds-vscode-* 2>/dev/null | sort | tail -n1 || true)"
[ -n "${EXT_DIR:-}" ] || { echo "Extensao TOTVS.tds-vscode nao encontrada em $EXT_ROOT" >&2; exit 1; }
OS="$(uname -s)"
case "$OS" in
  Darwin) BIN="$EXT_DIR/node_modules/@totvs/tds-ls/bin/mac/advpls" ;;
  Linux)  BIN="$EXT_DIR/node_modules/@totvs/tds-ls/bin/linux/advpls" ;;
  *) echo "SO nao suportado: $OS (.sh e para macOS/Linux; no Windows use compile.ps1)" >&2; exit 1 ;;
esac
[ -f "$BIN" ] || { echo "advpls nao encontrado: $BIN" >&2; exit 1; }
[ -x "$BIN" ] || chmod +x "$BIN" 2>/dev/null || true
if [ "$OS" = "Darwin" ]; then xattr -d com.apple.quarantine "$BIN" 2>/dev/null || true; fi

CLEAN=""
cleanup() { [ -n "$CLEAN" ] && rm -f "$CLEAN" 2>/dev/null || true; }
trap cleanup EXIT

if [ -n "$INI" ]; then
  [ -f "$INI" ] || { echo ".ini nao encontrado: $INI" >&2; exit 1; }
  RUNINI="$INI"
  MODO="arquivo (.ini completo)"
else
  [ -n "$PROFILE" ] || PROFILE="$WORKDIR/compile.profile.ini"
  [ -f "$PROFILE" ] || { echo "perfil nao encontrado: $PROFILE (copie compile.profile.ini.template)" >&2; exit 1; }

  case "$OS" in
    Darwin) PSW="$(security find-generic-password -w -s tds-advpls -a "$SECRET" 2>/dev/null || true)" ;;
    Linux)  PSW="$(secret-tool lookup service tds-advpls account "$SECRET" 2>/dev/null || true)" ;;
  esac
  [ -n "${PSW:-}" ] || { echo "segredo '$SECRET' nao encontrado. Rode: ./set-secret.sh $SECRET" >&2; exit 1; }

  RUNINI="$(mktemp -t tdscli.XXXXXX)"
  CLEAN="$RUNINI"
  content="$(cat "$PROFILE")"
  printf '%s' "${content//__PSW__/$PSW}" > "$RUNINI"
  PSW=""
  MODO="secret store -> .ini transiente"
fi

# log com horario: arquivo por-run em <workdir>/logs/compile_<ts>.log (nao sobrescreve)
LOGDIR="$WORKDIR/logs"
mkdir -p "$LOGDIR"
RUNLOG="$LOGDIR/compile_$(date +%Y%m%d_%H%M%S).log"
log_ts(){ printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$RUNLOG"; }

log_ts "modo: $MODO"
log_ts "advpls: $BIN"
log_ts "----- advpls cli -----"
set +e
"$BIN" cli "$RUNINI" 2>&1 | while IFS= read -r line; do
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line" | tee -a "$RUNLOG"
done
code=${PIPESTATUS[0]}
set -e
log_ts "EXIT CODE: $code"
[ "$code" -eq 0 ] && log_ts "OK - compilado." || log_ts "FALHA - veja a saida/log acima."
echo "log: $RUNLOG"
exit "$code"
