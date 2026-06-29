---
name: webapp-advpls-compile
description: 'Compila fontes AdvPL/TLPP (Protheus) de forma headless pela linha de comando com "advpls cli <script.ini>" (TDS Language Server), sem abrir o VS Code e sem depender de atalho de teclado. Cobre o wrapper Windows (PowerShell) e macOS/Linux (bash), o template de script .ini (secoes [authentication]/[compile]/[authorization]), descoberta automatica do binario advpls na extensao TOTVS.tds-vscode, e o tratamento da senha (fica no .ini do usuario, nunca lida nem ecoada pelo agente). Use quando o usuario quer "compilar headless", "compilar sem VS Code", "compilar via CLI/terminal", "advpls cli", "tds-cli", "build automatizado/CI", ou quando um agente precisa enviar fontes ao RPO sem UI. Para compilar DENTRO do VS Code com a extensao TDS, use a skill advpl-tlpp-compile.'
license: MIT
metadata:
  domain: Protheus
  maintainer: Customizacoes ADVPL/TLPP
  author: Vinicius Barbosa
  version: '1.0.0'
  category: Build and Compilation
  source: 'TOTVS tds-ls (advpls cli script): https://github.com/totvs/tds-ls/blob/master/TDS-cli-script.md'
---

# AdvPL/TLPP Compile Headless (advpls cli)

## Overview

Compila AdvPL/TLPP **sem VS Code e sem teclado**, rodando o binario `advpls` (TDS Language Server, que ja vem dentro da extensao `TOTVS.tds-vscode`) no modo `cli`, que executa um **script `.ini`** descrevendo conexao + compilacao. Isso da a um agente (ou a um CI) uma forma real de enviar fontes ao RPO por terminal.

Esta skill e a variante **headless/CLI** da `advpl-tlpp-compile` (que compila pela UI da extensao no VS Code). Quando o agente nao consegue disparar comandos do VS Code nem usar atalho (ex.: rodando fora do VS Code, ou tier "IDE" do computer-use bloqueando tecla), use esta.

## CRITICO

1. **NAO usar o modo legado `tds-cli` / `tdscli.bat` / `--tdsCliArguments=`.** Em `advpls` 2.0.16 esse argumento virou flag-sem-valor e toda chamada falha com `ERROR: Unexpected value after '--tdsCliArguments'`. O formato plano `key=value` (`compile @arquivo.txt`) **nao funciona** nessa versao. Use sempre `advpls cli <script.ini>`.
2. **NUNCA pedir a senha no chat, ler, ecoar, gravar em log/memoria nem transmitir.** Transcript e memoria persistem em texto puro e passam pelo contexto do agente — sao os PIORES lugares para um segredo. A senha vem do **cofre do SO** (DPAPI no Windows via `set-secret.ps1`; Keychain/libsecret no macOS/Linux via `set-secret.sh`), e quem a digita e o usuario, no proprio terminal. O wrapper injeta a senha num `.ini` **transiente** (temp do SO, apagado apos compilar) e o agente nunca ve o valor. O modo legado `-Ini`/`compile.ini` (senha em arquivo gitignorado) so como fallback.
3. **Nunca compilar sem OK explicito do usuario** (regra do CLAUDE.md do backend). Gere o `.ini`, peca confirmacao, so entao rode.
4. **Pre-requisitos do compilador:** acesso **exclusivo ao RPO**; fontes em **CP-1252** (UTF-8 compila com mojibake — ver skill `utf8-to-cp1252-conversion`); **chave `.aut`** somente se o fonte tiver `Function`/`Main Function` (secao `[authorization]`).
5. **Ler o resultado antes de declarar sucesso.** Conferir `[SUCCESS] ... compiled successfully` / `All files compiled successfully` e `EXIT CODE: 0`. Exit != 0 ou ausencia de `[SUCCESS]` = falha.

## Onde gravar os artefatos (perguntar SEMPRE)

Os wrappers usam uma **pasta de trabalho** (`WorkDir`) que guarda: o perfil `compile.profile.ini` (sem senha), os logs por-run e — no Windows — o blob de senha cifrado `<nome>.psw`. **Antes de configurar, PERGUNTE ao usuario onde criar essa pasta.** Ofereca opcoes:

| Opcao | Caminho sugerido | `.gitignore` |
|---|---|---|
| Efemera no repo (default) | `<repo>/tmp/advpls` | ja coberto por `tmp/` |
| Fixa no repo | `<repo>/.advpls` (ou outro nome) | **adicionar a pasta ao `.gitignore`** |
| Fora do repo | `~/.advpls/<projeto>` (mac/Linux) · `%LOCALAPPDATA%\advpls\<projeto>` (Windows) | nao precisa (fora do git) |

**Apos o usuario aceitar uma opcao:**
1. Se a pasta ficar **dentro do repo e ainda nao estiver coberta** pelo `.gitignore`, **adicione-a** (ex.: uma linha `.advpls/`). Para `tmp/advpls` o `tmp/` ja cobre — nao editar. Isso e obrigatorio: a pasta pode conter o blob de senha (Windows) e logs.
2. Passe o caminho aos wrappers via `-WorkDir <dir>` (PowerShell) / `--workdir <dir>` (bash); a `set-secret.ps1` aceita o mesmo `-WorkDir`. Sem o parametro, o default e `<repo>/tmp/advpls`.

Nunca grave a pasta de trabalho num local versionado sem garantir o `.gitignore`.

## Quick start (cofre do SO — recomendado)

0. **Escolher onde gravar** — perguntar ao usuario (secao acima). `<WorkDir>` = caminho aceito; default `<repo>/tmp/advpls`. Se a pasta for nova dentro do repo, garantir que esta no `.gitignore`.
1. Copiar `assets/compile.profile.ini.template` para `<WorkDir>/compile.profile.ini` e ajustar `server`/`port`/`environment`/`user` (ver `servers.json`), `program=` (caminho ABSOLUTO, `;` ou `,`) e `includes=`. **Sem senha** — a linha fica `psw=__PSW__`.
2. Guardar a senha **uma vez**, no proprio terminal (interativo):
   - Windows: `assets/set-secret.ps1 [-SecretName default] [-WorkDir <dir>]`
   - macOS/Linux: `assets/set-secret.sh [default]`  (segredo vai pro Keychain/libsecret, nao depende de WorkDir)
3. Compilar (o wrapper puxa a senha do cofre, gera um `.ini` transiente, roda, apaga):
   - Windows: `assets/compile.ps1 [-SecretName default] [-WorkDir <dir>]`
   - macOS/Linux: `assets/compile.sh [--secret default] [--workdir <dir>]`
4. Conferir `EXIT CODE: 0` + `[SUCCESS]`.

Os wrappers **descobrem o binario** na extensao `TOTVS.tds-vscode-*` mais recente sozinhos (sobrevivem a upgrade).

**Fallback (arquivo direto):** um `.ini` COMPLETO com `psw=` (gitignorado) via `assets/compile.ini.template` -> `tmp/advpls/compile.ini`, rodando `compile.ps1 -Ini <...>` / `compile.sh --ini <...>`. Menos seguro (senha parada em disco) — preferir o cofre.

## Logs (com horario)

O log nativo do `advpls` (`logToFile` do perfil) **nao** carimba hora por linha. Os wrappers geram, em cada run, um log proprio com **timestamp por linha** (`[yyyy-MM-dd HH:mm:ss] ...`) em `<WorkDir>/logs/compile_<yyyyMMdd_HHmmss>.log` — nome por-run (nao sobrescreve, mantem historico). O exit code reportado e o do `advpls` (preservado via `$LASTEXITCODE`/`${PIPESTATUS[0]}`, nao o do filtro de timestamp). Garanta que `<WorkDir>` esteja no `.gitignore` (para `tmp/advpls`, `tmp/` ja cobre) para os logs nao irem ao git.

## Cross-platform

| SO | Binario (dentro da extensao TDS) | Wrapper |
|---|---|---|
| Windows | `node_modules/@totvs/tds-ls/bin/windows/advpls.exe` | `assets/compile.ps1` |
| macOS | `.../bin/mac/advpls` | `assets/compile.sh` |
| Linux | `.../bin/linux/advpls` | `assets/compile.sh` |

O mesmo script `.ini` serve nos tres. No macOS o binario e nao-assinado: o wrapper faz `chmod +x` e remove a quarentena do Gatekeeper (`xattr -d com.apple.quarantine`). Caminhos no `.ini` usam `/` (funciona em todos). Ver setup macOS detalhado em [references/advpls-cli-reference.md](references/advpls-cli-reference.md).

## Formato do script .ini (resumo)

Encoding **CP1252/ANSI**; comentarios com `;` ou `#`; secoes `[...]`; executa as secoes em ordem.

```ini
logToFile=/caminho/abs/tds-compile.log
showConsoleOutput=true

[authentication]
action=authentication
server=10.11.10.29
port=5250
secure=0
build=AUTO
environment=NOME_ENV
user=USUARIO
psw=SENHA

[compile]
action=compile
program=/abs/fonte1.tlpp;/abs/fonte2.tlpp
recompile=T
includes=D:/Totvs/include
```

`secure`=0/1 (SSL). `build`=`AUTO` (detecta) ou a versao exata. `recompile=T` forca rebuild. `[authorization]` com `authtoken=<chave>` antes de `[compile]` so quando ha `Function`/`Main Function`. Esquema completo + tabela de campos em [references/advpls-cli-reference.md](references/advpls-cli-reference.md).

## Gestao da senha (cofre do SO)

- **Windows — DPAPI.** `set-secret.ps1` cifra a senha com a Data Protection API (`ConvertFrom-SecureString`, escopo CurrentUser) e grava o blob em `<WorkDir>/<nome>.psw` — so este usuario/maquina decifra. Escolha proposital sobre o `SecretManagement`/`SecretStore`: o SecretStore exige uma senha de unlock que **travaria** o compile dirigido por agente (tool nao-interativa); DPAPI le sem prompt.
- **macOS — Keychain** (`security`); **Linux — libsecret** (`secret-tool`). `set-secret.sh` grava; `compile.sh` le em runtime.
- Um segredo por servidor, se quiser: `set-secret.ps1 -SecretName mistral-demo` + `compile.ps1 -SecretName mistral-demo`.
- `set-secret.*` e **interativo** — roda no terminal do usuario; um agente nao-interativo nao consegue (e esse e o ponto: a senha so passa pelas maos do usuario).

## Assets

- **`assets/compile.profile.ini.template`** — PERFIL `.ini` SEM senha (`psw=__PSW__`); copiar para `tmp/advpls/compile.profile.ini` e ajustar.
- **`assets/set-secret.ps1`** — Windows; guarda a senha cifrada (DPAPI). Interativo.
- **`assets/set-secret.sh`** — macOS (Keychain) / Linux (libsecret); guarda a senha. Interativo.
- **`assets/compile.ps1`** — wrapper Windows; modo cofre (`-SecretName`, perfil -> `.ini` transiente apagado) ou legado (`-Ini`). Descobre `advpls.exe`. Nao imprime senha.
- **`assets/compile.sh`** — wrapper macOS/Linux; modo cofre (`--secret`/`--profile`) ou legado (`--ini`); `chmod +x`/`xattr` no mac.
- **`assets/compile.ini.template`** — (fallback) `.ini` COMPLETO com `psw=`; modo legado `-Ini`/`--ini`.

## Troubleshooting

| Sintoma | Causa | Fix |
|---|---|---|
| `Unexpected value after '--tdsCliArguments'` | usou o modo legado `tds-cli` | use `advpls cli <ini>` |
| `Unexpected value` lendo um `@arquivo.txt` | formato legado plano | converta para `.ini` (secoes) |
| Mojibake / sintaxe invalida pos-compile | fonte em UTF-8 | converter para CP-1252 e recompilar |
| `exclusive access to the objects repository` | outro user/JOB segura o RPO | desconectar, ou `BuildKillUsers` no appserver.ini |
| `Function`/`Main Function` rejeitado | sem chave de compilacao | secao `[authorization]` com `authtoken` |
| macOS: binario nao executa / "cannot be opened" | sem permissao / quarentena Gatekeeper | `chmod +x` + `xattr -d com.apple.quarantine` (o wrapper ja faz) |

Servidores conhecidos e mais detalhes em [references/advpls-cli-reference.md](references/advpls-cli-reference.md).
