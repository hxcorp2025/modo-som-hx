# Modo Som HX - instalador de um comando.
# No PowerShell como ADMINISTRADOR, cole:
#   irm https://raw.githubusercontent.com/hxcorp2025/modo-som-hx/main/instalar.ps1 | iex
# Atualizar pegando perfis novos:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/hxcorp2025/modo-som-hx/main/instalar.ps1))) -AtualizarPerfis
param(
  [string]$Destino = (Join-Path $env:USERPROFILE 'ModoSom'),
  [string]$Repo = 'hxcorp2025/modo-som-hx',
  [string]$Ref = 'main',
  [switch]$AtualizarPerfis,
  [switch]$SemAPO,
  [switch]$SemAtalhos,
  [switch]$SemPainel,
  [switch]$SemGerar
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$ApoDir      = 'C:\Program Files\EqualizerAPO'
$ApoUrl      = "https://github.com/$Repo/releases/download/apo-1.4.2/EqualizerAPO-x64-1.4.2.exe"
$ApoSha256   = '7403BE7427BBE1936A40DDED082829B6E217FC4F5990FEE5CBA501F0AE055AFA'
$ZipUrl      = "https://github.com/$Repo/archive/refs/heads/$Ref.zip"
$RawInstalar = "https://raw.githubusercontent.com/$Repo/$Ref/instalar.ps1"

function Passo($m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "    [ok] $m" -ForegroundColor Green }
function Aviso($m) { Write-Host "    [!] $m" -ForegroundColor Yellow }

Write-Host ''
Write-Host '  ===== Modo Som HX - instalacao =====' -ForegroundColor Cyan

# --- precisa de administrador (instala o motor de audio e libera a pasta de config) ---
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
  Aviso 'Esta janela nao e de administrador. Vou abrir outra elevada: clique em SIM na pergunta do Windows.'
  Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$RawInstalar' | iex`""
  return
}

New-Item -ItemType Directory -Force $Destino | Out-Null
$log = Join-Path $Destino 'instalacao.log'
function L($m) { Add-Content $log ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) }
L "--- instalar.ps1 repo=$Repo ref=$Ref destino=$Destino ---"
$tmp = Join-Path $env:TEMP ('modosom_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $tmp | Out-Null

try {
  # 1) arquivos do painel
  Passo "1/5 Baixando o Modo Som HX ($Repo)"
  $zip = Join-Path $tmp 'repo.zip'
  Invoke-WebRequest -Uri $ZipUrl -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $src = Get-ChildItem $tmp -Directory | Where-Object { $_.Name -like 'modo-som-hx*' } | Select-Object -First 1
  if (-not $src) { throw 'pasta do repositorio nao encontrada dentro do zip' }
  $preservar = @('estado.json')
  if (-not $AtualizarPerfis) { $preservar += 'perfis.json' }
  foreach ($f in Get-ChildItem $src.FullName -File) {
    $alvo = Join-Path $Destino $f.Name
    if (($preservar -contains $f.Name) -and (Test-Path $alvo)) { Aviso "mantido o seu $($f.Name)"; continue }
    Copy-Item $f.FullName $alvo -Force
  }
  Ok "arquivos em $Destino"; L 'arquivos copiados'

  # 2) motor
  $instalouAgora = $false
  Passo '2/5 Motor de audio (Equalizer APO 1.4.2)'
  if ($SemAPO) { Aviso 'pulado (-SemAPO)' }
  elseif (Test-Path (Join-Path $ApoDir 'EqualizerAPO.dll')) { Ok 'ja estava instalado'; L 'APO ja instalado' }
  else {
    $exe = Join-Path $tmp 'EqualizerAPO-x64-1.4.2.exe'
    Write-Host '    baixando o instalador (12 MB)...'
    Invoke-WebRequest -Uri $ApoUrl -OutFile $exe -UseBasicParsing
    $sha = (Get-FileHash $exe -Algorithm SHA256).Hash
    if ($sha -ne $ApoSha256) { throw "instalador do Equalizer APO nao bate com o esperado (sha256 $sha). Abortado por seguranca." }
    Ok 'integridade do instalador conferida'
    Add-Type -AssemblyName PresentationFramework
    [void][System.Windows.MessageBox]::Show(
      "Vai abrir a janela 'Equalizer APO Device Selector'.`n`nNa parte de cima (Playback devices), marque o seu FONE e as caixas de som que voce usa. Nao marque microfones (Capture devices).`n`nDepois clique OK. Se perguntar para reiniciar o computador, responda NAO.",
      'Modo Som HX - unico passo manual', 'OK', 'Information')
    $p = Start-Process $exe -ArgumentList '/S' -Wait -PassThru
    L "instalador do APO saiu com $($p.ExitCode)"
    if (-not (Test-Path (Join-Path $ApoDir 'EqualizerAPO.dll'))) { throw 'o Equalizer APO nao ficou instalado (janela cancelada?). Rode o comando de novo.' }
    $instalouAgora = $true
    Ok 'motor instalado'
  }
  if (-not $SemAPO -and (Test-Path $ApoDir)) {
    $cfgDir = Join-Path $ApoDir 'config'
    if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Force $cfgDir | Out-Null }
    icacls $cfgDir /grant '*S-1-5-32-545:(OI)(CI)M' /T | Out-Null
    Ok 'painel liberado para escrever no config (sem precisar de admin)'
  }

  # 3) ativar sem reiniciar o PC
  Passo '3/5 Ativando o motor'
  if ($instalouAgora) {
    try { Restart-Service Audiosrv -Force; Start-Sleep -Seconds 3; Ok "servico de audio reiniciado ($((Get-Service Audiosrv).Status)); o som some por 2 segundos e volta" }
    catch { Aviso "nao consegui reiniciar o servico de audio: $($_.Exception.Message). Reinicie o PC quando puder." }
  } else { Ok 'nada a ativar' }

  # 4) atalho
  Passo '4/5 Atalho na area de trabalho'
  if ($SemAtalhos) { Aviso 'pulado (-SemAtalhos)' } else {
    $ws = New-Object -ComObject WScript.Shell
    $desk = [Environment]::GetFolderPath('Desktop')
    $ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $l = $ws.CreateShortcut((Join-Path $desk 'Modo Som HX.lnk'))
    $l.TargetPath = $ps
    $l.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$Destino\ModoSom.ps1`""
    $l.WorkingDirectory = $Destino; $l.WindowStyle = 7
    $l.IconLocation = "$env:SystemRoot\System32\mmres.dll,0"; $l.Description = 'Equalizacao por saida de som (Modo Som HX)'
    $l.Save()
    Ok "atalho 'Modo Som HX' criado em $desk"
  }

  # 5) perfis
  Passo '5/5 Perfis de som'
  if ($SemGerar) { Aviso 'pulado (-SemGerar)' }
  elseif (Test-Path (Join-Path $ApoDir 'config')) {
    & powershell -NoProfile -ExecutionPolicy Bypass -STA -File (Join-Path $Destino 'ModoSom.ps1') -Gerar | Out-Null
    Ok 'config do Equalizer APO gravado com os perfis (Warzone, Meet, Musica, Flat)'
  } else { Aviso 'Equalizer APO ausente: perfis ficam salvos, mas nada toca diferente ate instalar o motor.' }

  Write-Host ''
  Write-Host "  Pronto! Abra 'Modo Som HX' na area de trabalho e escolha o perfil de cada saida de som." -ForegroundColor Green
  Write-Host "  Log: $log" -ForegroundColor DarkGray
  L 'instalacao concluida'
  if (-not $SemPainel) { Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$Destino\ModoSom.ps1`"" }
}
catch {
  Write-Host ''; Write-Host "  ERRO: $($_.Exception.Message)" -ForegroundColor Red
  L "ERRO: $($_.Exception.Message)"
  Write-Host "  Log em $log. Mande o erro pro Matheus." -ForegroundColor Yellow
}
finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
