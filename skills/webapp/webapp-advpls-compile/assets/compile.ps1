<#
.SYNOPSIS
  webapp-advpls-compile - wrapper Windows. Compila headless via "advpls cli".
.DESCRIPTION
  Dois modos:
   - Secret store (recomendado, default): -Profile aponta um .ini SEM senha
     (linha "psw=__PSW__"). A senha vem do cofre DPAPI (ver set-secret.ps1).
     O wrapper gera um .ini TRANSIENTE no temp do SO, roda, e o apaga num finally.
     A senha nunca e impressa nem persiste em texto puro.
   - Arquivo direto (legado): -Ini aponta um .ini COMPLETO (com psw) e roda como esta.
  Em ambos, descobre o advpls.exe na extensao TOTVS.tds-vscode mais recente.
.PARAMETER WorkDir
  Pasta de trabalho (perfil + blob de senha + logs). Default: <repo>/tmp/advpls.
  Use outra pasta se nao quiser os artefatos em tmp/ (ex.: -WorkDir C:\Users\x\.advpls\portal).
.PARAMETER Profile
  Caminho do .ini de perfil (sem senha). Default: <WorkDir>/compile.profile.ini
.PARAMETER SecretName
  Nome do segredo no cofre DPAPI (ver set-secret.ps1). Default 'default'.
.PARAMETER Ini
  Modo legado: caminho de um .ini COMPLETO (com psw). Tem precedencia se informado.
.EXAMPLE
  ./compile.ps1
.EXAMPLE
  ./compile.ps1 -SecretName mistral-demo -WorkDir C:\Users\vinic\.advpls\portal
.EXAMPLE
  ./compile.ps1 -Ini "D:\repo\tmp\advpls\compile.ini"
#>
[CmdletBinding()]
param(
  [string]$WorkDir,
  [string]$Profile,
  [string]$SecretName = 'default',
  [string]$Ini
)
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
if (-not $WorkDir) { $WorkDir = Join-Path $repoRoot 'tmp\advpls' }

# --- descobrir o advpls.exe na extensao TDS mais recente ---
$extRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
$ext = Get-ChildItem -LiteralPath $extRoot -Directory -Filter 'totvs.tds-vscode-*' -ErrorAction Stop |
       Sort-Object Name | Select-Object -Last 1
if (-not $ext) { throw "Extensao TOTVS.tds-vscode nao encontrada em $extRoot" }
$advpls = Join-Path $ext.FullName 'node_modules\@totvs\tds-ls\bin\windows\advpls.exe'
if (-not (Test-Path -LiteralPath $advpls)) { throw "advpls.exe nao encontrado: $advpls" }

$tempIni = $null
try {
  if ($Ini) {
    if (-not (Test-Path -LiteralPath $Ini)) { throw "Script .ini nao encontrado: $Ini" }
    $runIni = $Ini
    $modo = 'arquivo (.ini completo)'
  }
  else {
    if (-not $Profile) { $Profile = Join-Path $WorkDir 'compile.profile.ini' }
    if (-not (Test-Path -LiteralPath $Profile)) { throw "Perfil nao encontrado: $Profile (copie compile.profile.ini.template)" }

    $blob = Join-Path $WorkDir ("{0}.psw" -f $SecretName)
    if (-not (Test-Path -LiteralPath $blob)) {
      throw "Segredo '$SecretName' nao encontrado ($blob). Rode: set-secret.ps1 -SecretName $SecretName -WorkDir $WorkDir"
    }

    # decifrar DPAPI -> plaintext apenas em memoria
    $sec = ConvertTo-SecureString -String (Get-Content -Raw -LiteralPath $blob)
    $psw = [System.Net.NetworkCredential]::new('', $sec).Password
    $sec.Dispose()

    # compor .ini transiente: perfil com __PSW__ substituido (literal)
    $txt = (Get-Content -Raw -LiteralPath $Profile).Replace('__PSW__', $psw)
    $psw = $null

    $tempIni = Join-Path ([System.IO.Path]::GetTempPath()) ("tdscli_{0}.ini" -f [System.IO.Path]::GetRandomFileName())
    [IO.File]::WriteAllText($tempIni, $txt, [System.Text.Encoding]::GetEncoding(1252))
    $txt = $null
    $runIni = $tempIni
    $modo = 'secret store (DPAPI) -> .ini transiente'
  }

  # log com horario: arquivo por-run em <WorkDir>/logs/compile_<ts>.log (nao sobrescreve)
  $logDir = Join-Path $WorkDir 'logs'
  if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
  $runLog = Join-Path $logDir ('compile_{0:yyyyMMdd_HHmmss}.log' -f (Get-Date))
  $writeTs = {
    param($msg)
    $l = '[{0:yyyy-MM-dd HH:mm:ss}] {1}' -f (Get-Date), $msg
    Write-Host $l
    Add-Content -LiteralPath $runLog -Value $l
  }

  & $writeTs "modo: $modo"
  & $writeTs "advpls: $advpls"
  & $writeTs '----- advpls cli -----'
  & $advpls cli $runIni 2>&1 | ForEach-Object { & $writeTs $_ }
  $code = $LASTEXITCODE
  & $writeTs "EXIT CODE: $code"
  & $writeTs ($(if ($code -eq 0) { 'OK - compilado.' } else { 'FALHA - veja a saida/log acima.' }))
  Write-Host "log: $runLog"
  exit $code
}
finally {
  if ($tempIni) { try { [IO.File]::Delete($tempIni) } catch {} }
}
