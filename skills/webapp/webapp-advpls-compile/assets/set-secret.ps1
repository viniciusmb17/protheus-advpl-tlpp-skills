<#
.SYNOPSIS
  webapp-advpls-compile - guarda a senha do TDS no cofre DPAPI (Windows).
.DESCRIPTION
  Pede a senha de forma interativa (SecureString) e grava cifrada com DPAPI
  (Data Protection API): so este USUARIO nesta MAQUINA consegue decifrar.
  O blob fica em <WorkDir>/<SecretName>.psw. A senha nunca aparece em texto
  puro, nem no console, nem no git (desde que o WorkDir esteja gitignorado).

  IMPORTANTE: rode isto NO SEU TERMINAL (e interativo). Um agente nao consegue
  rodar (a tool e nao-interativa e o prompt travaria) - e esse e o ponto:
  a senha so passa pelas suas maos, nunca pelo contexto do agente.
.PARAMETER SecretName
  Nome do segredo. Default 'default'. Use um por servidor se quiser (ex.: 'mistral-demo').
.PARAMETER WorkDir
  Pasta onde gravar o blob. Default: <repo>/tmp/advpls. Use a mesma pasta passada
  ao compile.ps1 -WorkDir. Garanta que essa pasta esteja no .gitignore.
.EXAMPLE
  ./set-secret.ps1
.EXAMPLE
  ./set-secret.ps1 -SecretName mistral-demo -WorkDir C:\Users\vinic\.advpls\portal
#>
[CmdletBinding()]
param(
  [string]$SecretName = 'default',
  [string]$WorkDir
)
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
if (-not $WorkDir) { $WorkDir = Join-Path $repoRoot 'tmp\advpls' }
if (-not (Test-Path -LiteralPath $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null }
$blob = Join-Path $WorkDir ("{0}.psw" -f $SecretName)

$sec = Read-Host "Senha TDS para '$SecretName'" -AsSecureString
if (-not $sec -or $sec.Length -eq 0) { throw 'Senha vazia - nada gravado.' }

$enc = ConvertFrom-SecureString -SecureString $sec   # DPAPI (CurrentUser)
[IO.File]::WriteAllText($blob, $enc, [System.Text.Encoding]::ASCII)
$sec.Dispose()

Write-Host "OK - segredo '$SecretName' gravado cifrado (DPAPI): $blob"
Write-Host "Decifravel so por este usuario/maquina. Garanta que '$WorkDir' esteja no .gitignore."
