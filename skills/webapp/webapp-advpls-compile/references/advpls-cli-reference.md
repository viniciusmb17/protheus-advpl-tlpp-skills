# advpls cli — referencia detalhada

Material de apoio da skill `webapp-advpls-compile`. Carregar sob demanda.

Fonte oficial: [totvs/tds-ls — TDS-cli-script.md](https://github.com/totvs/tds-ls/blob/master/TDS-cli-script.md).

---

## Por que NAO o modo legado

O modo legado `advpls tds-cli --tdsCliArguments="compile @arquivo"` (e o wrapper `tdscli.bat`/`tdscli.sh`) era a forma antiga, com params planos `serverType=... server=... psw=... program=...`. Em `advpls` **2.0.16** o `--tdsCliArguments` passou a ser tratado como flag sem valor e qualquer chamada termina com:

```
ERROR: Unexpected value after '--tdsCliArguments'.
```

Confirmado tambem que o problema independe de aspas/escape do shell (testado via `tdscli.bat` oficial, short-path 8.3, `--%`). **A forma suportada e `advpls cli <script.ini>`.**

Modos do binario (`advpls.exe [options] <mode>`): `language-server | cli | appre | tds-cli`. Usar **`cli`** (executa um script). `tds-cli` e o legado quebrado.

---

## Esquema do script .ini

Arquivo **CP1252/ANSI**, extensao `.ini`. Comentarios: `;` ou `#`. Secoes: `[nome]`. Executa em ordem; `skip=true` numa secao a ignora.

### Cabecalho (chaves de topo, antes das secoes)

| Chave | Descricao |
|---|---|
| `logToFile` | Caminho do arquivo de log (absoluto recomendado) |
| `showConsoleOutput` | `true` para ecoar no console alem do log |

### `[user]` (opcional) — variaveis reutilizaveis

```ini
[user]
INCLUDE_DIR=D:/Totvs/include
```
Referenciar depois como `${INCLUDE_DIR}`.

### `[authentication]`

| Chave | Descricao | Exemplo |
|---|---|---|
| `action` | `authentication` | |
| `server` | IP/host do AppServer | `10.11.10.29` |
| `port` | porta TDS/LSP (nao a do SmartClient) | `5250` |
| `secure` | `0` padrao / `1` SSL | `0` |
| `build` | versao do build ou `AUTO` | `AUTO` |
| `environment` | ambiente | `ENVIRONMENT` |
| `user` | usuario Protheus | `admin` |
| `psw` | senha em texto puro | (segredo) |

### `[authorization]` (opcional — antes de `[compile]`)

So necessario para fontes com `Function`/`Main Function` (exigem chave de compilacao).

```ini
[authorization]
action=authorization
authtoken=<chave_de_compilacao>
```

### `[compile]`

| Chave | Descricao |
|---|---|
| `action` | `compile` |
| `program` | fontes separados por `;` ou `,` (caminho absoluto) |
| `recompile` | `T`/`True` forca recompilacao (rebuild) |
| `includes` | pastas de include `.ch`/`.th` (`;`/`,` se varias) |

---

## Binarios por SO

Dentro da extensao instalada (`~/.vscode/extensions/totvs.tds-vscode-<versao>/node_modules/@totvs/tds-ls/`):

| SO | Caminho relativo |
|---|---|
| Windows | `bin/windows/advpls.exe` |
| macOS | `bin/mac/advpls` |
| Linux | `bin/linux/advpls` |

Os tres aceitam `advpls cli <script.ini>`. Os wrappers da skill descobrem a pasta da extensao mais recente via glob `totvs.tds-vscode-*` ordenado — sobrevive a upgrade.

Tambem distribuido via npm: `npm i -g @totvs/tds-ls` (binarios portateis), ou Releases em https://github.com/totvs/tds-ls/releases. Preferir o que ja vem na extensao para casar a versao com o que o usuario usa no VS Code.

---

## Setup macOS (binario nao-assinado)

1. **Permissao de execucao:** `chmod +x .../bin/mac/advpls` (o wrapper `compile.sh` faz).
2. **Gatekeeper / quarentena:** binario baixado via npm/extensao costuma vir com o atributo `com.apple.quarantine`, que o macOS bloqueia ("cannot be opened because the developer cannot be verified"). Remover: `xattr -d com.apple.quarantine .../bin/mac/advpls` (o wrapper tenta automaticamente). Se persistir, autorizar em System Settings > Privacy & Security apos a primeira tentativa.
3. **Apple Silicon:** se o binario for x86_64, precisa do Rosetta 2 (`softwareupdate --install-rosetta`). Verificar arquitetura com `file .../bin/mac/advpls`.
4. Caminhos no `.ini` com `/` normais; `logToFile` absoluto (ex.: `$HOME/.../tmp/advpls/tds-compile.log`).

> Nao testado in loco a partir deste ambiente (sessao Windows). A viabilidade vem de o binario macOS acompanhar a mesma extensao e aceitar o mesmo modo `cli`. Validar a primeira execucao num Mac real.

---

## Servidores conhecidos (deste workspace, de `~/.totvsls/servers.json`)

| Nome | server:port | secure | build | environment | Status |
|---|---|---|---|---|---|
| MISTRAL DEMO | 177.170.0.103:6071 | 0 | 7.00.240223P | `ENVIRONMENT` | **alvo de compilacao; VERIFICADO exit 0 em 2026-06-25** |
| CCM - PORTAL DE COMPRAS COMPILACAO | 10.11.10.29:5250 | 0 | 7.00.240223P | `CCM_OFICIAL` | alternativo |

`includes` padrao do workspace: `D:/Totvs/include`. Ajustar conforme a maquina.

---

## Gestao de segredo (cofre do SO) — por que e como

**Nunca** colocar a senha em: transcript do chat, memoria do agente, ou commitada. Os dois primeiros persistem em texto puro e passam pelo contexto do agente (vao para a API/logs). O fluxo dos wrappers:

```
set-secret  (interativo, terminal do usuario)  ->  cofre cifrado do SO
compile     ->  le do cofre  ->  .ini TRANSIENTE no temp (psw injetada)  ->  advpls cli  ->  apaga o .ini
```

### Windows — DPAPI (sem dependencia)

```powershell
# guardar (uma vez, interativo):
ConvertFrom-SecureString -SecureString (Read-Host 'Senha' -AsSecureString) | Set-Content tmp/advpls/default.psw
# ler (runtime):
$psw = [System.Net.NetworkCredential]::new('', (ConvertTo-SecureString (Get-Content -Raw tmp/advpls/default.psw))).Password
```

`ConvertFrom-SecureString` sem `-Key` usa DPAPI (escopo CurrentUser): o blob so e decifravel pelo mesmo usuario/maquina. Preferido ao `Microsoft.PowerShell.SecretManagement`/`SecretStore` aqui porque o SecretStore exige senha de unlock (prompt interativo) que travaria o compile dirigido por agente; DPAPI le sem prompt.

### macOS — Keychain / Linux — libsecret

```bash
# macOS guardar / ler:
security add-generic-password -U -s tds-advpls -a default -w        # prompt
security find-generic-password -w -s tds-advpls -a default          # le
# Linux (libsecret):
secret-tool store --label='tds-advpls:default' service tds-advpls account default
secret-tool lookup service tds-advpls account default
```

No macOS, o primeiro acesso de um binario novo ao item do Keychain pode abrir um dialog "permitir acesso" — escolher *Always Allow* torna os proximos silenciosos.

### .ini transiente

O wrapper substitui o marcador literal `__PSW__` do perfil pela senha e grava um `.ini` em pasta temporaria do SO (nome aleatorio), executa, e apaga num `finally`/`trap`. A senha so existe: (a) cifrada no cofre e (b) por segundos no `.ini` transiente — nunca no perfil versionavel, nunca no transcript.

## Checklist de pre-requisitos

1. AppServer/ambiente acessivel na rede (VPN se remoto).
2. Usuario autenticavel.
3. Includes configurados (`.ch`/`.th`).
4. Acesso **exclusivo ao RPO** (sem outros users/JOBS travando).
5. Chave `.aut` apenas para `Function`/`Main Function`.
6. Fontes em **CP-1252**.
7. Evitar drives de nuvem (OneDrive/GDrive) — compilacao parcial.
