<#
.SYNOPSIS
  webapp-advpls-compile - guarda a senha do TDS no cofre DPAPI (Windows).
.DESCRIPTION
  Pede a senha de forma interativa (SecureString) e grava cifrada com DPAPI
  (Data Protection API): so este USUARIO nesta MAQUINA consegue decifrar.
  O blob fica em tmp/advpls/<SecretName>.psw (tmp/ esta no .gitignore).
  A senha nunca aparece em texto puro, nem no console, nem no git.

  IMPORTANTE: rode isto NO SEU TERMINAL (e interativo). Um agente nao consegue
  rodar (a tool e nao-interativa e o prompt travaria) - e esse e o ponto:
  a senha so passa pelas suas maos, nunca pelo contexto do agente.
.PARAMETER SecretName
  Nome do segredo. Default 'default'. Use um por servidor se quiser (ex.: 'mistral-demo').
.EXAMPLE
  ./set-secret.ps1
.EXAMPLE
  ./set-secret.ps1 -SecretName mistral-demo
#>
[CmdletBinding()]
param([string]$SecretName = 'default')
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$dir = Join-Path $repoRoot 'tmp\advpls'
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$blob = Join-Path $dir ("{0}.psw" -f $SecretName)

$sec = Read-Host "Senha TDS para '$SecretName'" -AsSecureString
if (-not $sec -or $sec.Length -eq 0) { throw 'Senha vazia - nada gravado.' }

$enc = ConvertFrom-SecureString -SecureString $sec   # DPAPI (CurrentUser)
[IO.File]::WriteAllText($blob, $enc, [System.Text.Encoding]::ASCII)
$sec.Dispose()

Write-Host "OK - segredo '$SecretName' gravado cifrado (DPAPI): $blob"
Write-Host "Decifravel so por este usuario/maquina. tmp/ esta no .gitignore."
