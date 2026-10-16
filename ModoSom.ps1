# Modo Som HX — perfis de equalização por dispositivo em cima do Equalizer APO.
# Repositório: https://github.com/hxcorp2025/modo-som-hx  (instalar: ver README.md)
# Uso:  ModoSom.ps1              -> abre o painel
#       ModoSom.ps1 jogo         -> cada saída vai pro perfil "Modo Jogo" dela (sem painel)
#       ModoSom.ps1 trabalho     -> cada saída vai pro perfil "Modo Trabalho" dela
#       ModoSom.ps1 -Gerar       -> só regrava o config do Equalizer APO a partir do estado salvo
[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$Modo = '',
  [switch]$Gerar
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$inv = [Globalization.CultureInfo]::InvariantCulture

$global:MS = @{
  dir        = $PSScriptRoot
  perfisPath = (Join-Path $PSScriptRoot 'perfis.json')
  estadoPath = (Join-Path $PSScriptRoot 'estado.json')
  perfisDir  = (Join-Path $PSScriptRoot 'perfis')
  apoDir     = 'C:\Program Files\EqualizerAPO'
  configPath = 'C:\Program Files\EqualizerAPO\config\config.txt'
  perfis = $null; estado = $null; dispositivos = @(); ui = @{}; carregando = $false
  status = $null; win = $null; painelAjuste = $null; perfilEditando = $null; timerGravar = $null
}

# ---------- perfis de fábrica (ponto de partida; o ajuste fino salva por cima) ----------
function global:Perfis-Padrao {
  return [pscustomobject]@{
    flat = [pscustomobject]@{ nome = 'Flat (sem equalização)'; descricao = 'Som puro do dispositivo. Use pra comparar.'; preamp = 0; filtros = @() }
    warzone = [pscustomobject]@{
      nome = 'Warzone (competitivo)'
      descricao = 'Corta o ronco grave que esconde passo, tira a lama dos médios-graves e levanta a faixa onde passo e recarga vivem (2 a 7 kHz). Preamp negativo evita distorcer.'
      preamp = -5
      filtros = @(
        [pscustomobject]@{ tipo = 'HPQ'; fc = 90;    gain = 0;    q = 0.7; rotulo = 'Corte de grave (passa-alta)' },
        [pscustomobject]@{ tipo = 'PK';  fc = 180;   gain = -3;   q = 1.0; rotulo = 'Ronco (explosão, veículo)' },
        [pscustomobject]@{ tipo = 'PK';  fc = 450;   gain = -1.5; q = 1.2; rotulo = 'Lama (médio-grave)' },
        [pscustomobject]@{ tipo = 'PK';  fc = 1200;  gain = 1.5;  q = 1.2; rotulo = 'Corpo do passo' },
        [pscustomobject]@{ tipo = 'PK';  fc = 2500;  gain = 4;    q = 1.2; rotulo = 'Passo e recarga (principal)' },
        [pscustomobject]@{ tipo = 'PK';  fc = 4000;  gain = 3;    q = 1.4; rotulo = 'Detalhe do passo' },
        [pscustomobject]@{ tipo = 'PK';  fc = 6500;  gain = 2;    q = 1.6; rotulo = 'Ar / direção' },
        [pscustomobject]@{ tipo = 'HS';  fc = 10000; gain = -2;   q = 0.7; rotulo = 'Chiado agudo (prateleira)' }
      )
    }
    meet = [pscustomobject]@{
      nome = 'Meet (voz)'
      descricao = 'Voz mais clara e menos abafada em call: corta sub-grave, tira o "boom" de 250 Hz e dá presença em 3 kHz.'
      preamp = -3
      filtros = @(
        [pscustomobject]@{ tipo = 'HPQ'; fc = 80;   gain = 0;   q = 0.7; rotulo = 'Corte de grave (passa-alta)' },
        [pscustomobject]@{ tipo = 'PK';  fc = 250;  gain = -2;  q = 1.0; rotulo = 'Boom de voz' },
        [pscustomobject]@{ tipo = 'PK';  fc = 1000; gain = 1;   q = 1.2; rotulo = 'Corpo da voz' },
        [pscustomobject]@{ tipo = 'PK';  fc = 3000; gain = 2.5; q = 1.2; rotulo = 'Presença (inteligibilidade)' },
        [pscustomobject]@{ tipo = 'PK';  fc = 5500; gain = 1;   q = 1.5; rotulo = 'Dicção (s, t)' },
        [pscustomobject]@{ tipo = 'HS';  fc = 9000; gain = 0;   q = 0.7; rotulo = 'Brilho (prateleira)' }
      )
    }
    musica = [pscustomobject]@{
      nome = 'Música'
      descricao = 'Leve sorriso: um pouco mais de grave e de brilho, médio limpo.'
      preamp = -4
      filtros = @(
        [pscustomobject]@{ tipo = 'LS';  fc = 100;   gain = 2.5; q = 0.7; rotulo = 'Grave (prateleira)' },
        [pscustomobject]@{ tipo = 'PK';  fc = 250;   gain = -1;  q = 1.0; rotulo = 'Lama' },
        [pscustomobject]@{ tipo = 'PK';  fc = 1000;  gain = 0;   q = 1.2; rotulo = 'Médio' },
        [pscustomobject]@{ tipo = 'PK';  fc = 3000;  gain = 1;   q = 1.2; rotulo = 'Presença' },
        [pscustomobject]@{ tipo = 'HS';  fc = 10000; gain = 2;   q = 0.7; rotulo = 'Brilho (prateleira)' }
      )
    }
  }
}

# ---------- arquivos ----------
function global:Ler-Json($p) { Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json }
function global:Gravar-Json($obj, $p) { $obj | ConvertTo-Json -Depth 8 | Set-Content $p -Encoding UTF8 }
function global:Carregar-Perfis {
  if (Test-Path $global:MS.perfisPath) { $global:MS.perfis = Ler-Json $global:MS.perfisPath }
  else { $global:MS.perfis = Perfis-Padrao; Gravar-Json $global:MS.perfis $global:MS.perfisPath }
}
function global:Nomes-Perfis { @($global:MS.perfis.PSObject.Properties | ForEach-Object { $_.Name }) }
function global:Num($v) { ([double]$v).ToString('0.##', [Globalization.CultureInfo]::InvariantCulture) }

# gera perfis\<id>.txt na sintaxe do Equalizer APO
function global:Gerar-PerfilTxt($id) {
  $p = $global:MS.perfis.$id
  if (-not (Test-Path $global:MS.perfisDir)) { New-Item -ItemType Directory $global:MS.perfisDir | Out-Null }
  $linhas = @("# Modo Som HX - perfil '$id' (gerado; edite pelo painel)")
  $linhas += "Preamp: $(Num $p.preamp) dB"
  foreach ($f in @($p.filtros)) {
    switch ($f.tipo) {
      'HPQ' { $linhas += "Filter: ON HPQ Fc $(Num $f.fc) Hz Q $(Num $f.q)" }
      'LPQ' { $linhas += "Filter: ON LPQ Fc $(Num $f.fc) Hz Q $(Num $f.q)" }
      'LS'  { $linhas += "Filter: ON LS Fc $(Num $f.fc) Hz Gain $(Num $f.gain) dB Q $(Num $f.q)" }
      'HS'  { $linhas += "Filter: ON HS Fc $(Num $f.fc) Hz Gain $(Num $f.gain) dB Q $(Num $f.q)" }
      default { $linhas += "Filter: ON PK Fc $(Num $f.fc) Hz Gain $(Num $f.gain) dB Q $(Num $f.q)" }
    }
  }
  $linhas -join "`r`n" | Set-Content (Join-Path $global:MS.perfisDir "$id.txt") -Encoding ASCII
}
function global:Gerar-TodosPerfis { foreach ($n in (Nomes-Perfis)) { Gerar-PerfilTxt $n } }

# ---------- dispositivos de saída (registro do Windows; inclui desplugados) ----------
function global:Ler-Dispositivos {
  $base = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render'
  $lista = @()
  foreach ($k in (Get-ChildItem $base -ErrorAction SilentlyContinue)) {
    $p = Get-ItemProperty $k.PSPath
    $pr = Get-ItemProperty (Join-Path $k.PSPath 'Properties') -ErrorAction SilentlyContinue
    $nome = $pr.'{a45c254e-df1c-4efd-8020-67d146a850e0},14'
    $conexao = $pr.'{a45c254e-df1c-4efd-8020-67d146a850e0},2'
    $aparelho = $pr.'{b3f8fa53-0004-438e-9003-51a46e139bfc},6'
    if (-not $nome) { if ($conexao -and $aparelho) { $nome = "$conexao ($aparelho)" } elseif ($conexao) { $nome = $conexao } else { continue } }
    if ($nome -match 'FxSound') { continue }
    # 1 = conectada, 8 = desplugada (Bluetooth fora). 4 e outros = fantasmas de monitor/placa antiga.
    if ([int]$p.DeviceState -notin @(1, 8)) { continue }
    if ($nome -match 'Hands-Free') { continue }
    $palavras = (("$aparelho $conexao") -replace '[(),]', ' ') -split '\s+' | Where-Object { $_ -ne '' }
    $lista += [pscustomobject]@{
      id = $k.PSChildName; nome = $nome; conexao = $conexao; aparelho = $aparelho
      estado = [int]$p.DeviceState; padrao = ($palavras -join ' ')
    }
  }
  return $lista
}
function global:Estado-Texto($e) { switch ($e) { 1 { 'conectado' } 2 { 'desabilitado' } 4 { 'ausente' } 8 { 'desplugado' } default { "estado $e" } } }

# ---------- estado (qual perfil em cada saída) ----------
function global:Carregar-Estado {
  if (Test-Path $global:MS.estadoPath) { $global:MS.estado = Ler-Json $global:MS.estadoPath }
  else { $global:MS.estado = [pscustomobject]@{ ligado = $true; dispositivos = [pscustomobject]@{} } }
  $global:MS.dispositivos = Ler-Dispositivos
  foreach ($d in $global:MS.dispositivos) {
    if (-not $global:MS.estado.dispositivos.($d.id)) {
      $jogo = 'warzone'; $trab = 'flat'; $ativo = 'flat'
      # fone/headset de qualquer marca: jogo = warzone, trabalho = meet (o painel deixa trocar)
      if ($d.nome -match 'Morcego|Fallen|AirPods|U850|Headset|Headphone|Fone|Arctis|HyperX|Cloud|Razer|Kraken|Redragon|Logitech|Astro|Corsair|Quantum|Buds|Sony|WH-') { $trab = 'meet'; $ativo = 'meet' }
      $global:MS.estado.dispositivos | Add-Member -NotePropertyName $d.id -NotePropertyValue ([pscustomobject]@{
        nome = $d.nome; padrao = $d.padrao; ativo = $ativo; jogo = $jogo; trabalho = $trab }) -Force
    } else {
      $e = $global:MS.estado.dispositivos.($d.id); $e.nome = $d.nome; $e.padrao = $d.padrao
    }
  }
  Salvar-Estado
}
function global:Salvar-Estado { Gravar-Json $global:MS.estado $global:MS.estadoPath }

# ---------- grava o config.txt do Equalizer APO ----------
function global:Gerar-Config {
  Gerar-TodosPerfis
  $l = @()
  $l += "# ===== Modo Som HX ====="
  $l += "# Gerado em $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') por $($global:MS.dir)\ModoSom.ps1 - NAO editar a mao (o painel sobrescreve)."
  if ($global:MS.estado.ligado) {
    foreach ($d in $global:MS.dispositivos) {
      $e = $global:MS.estado.dispositivos.($d.id); if (-not $e) { continue }
      if ($e.ativo -eq 'flat' -or -not $e.ativo) { continue }
      $l += ""
      $l += "# $($d.nome) -> perfil $($e.ativo)"
      $l += "Device: $($e.padrao)"
      $l += "Include: $($global:MS.perfisDir)\$($e.ativo).txt"
    }
  } else { $l += "# DESLIGADO pelo painel: nenhum filtro ativo." }
  $dirCfg = Split-Path $global:MS.configPath
  if (-not (Test-Path $dirCfg)) { throw "Equalizer APO nao encontrado em $dirCfg. Instale primeiro." }
  $l -join "`r`n" | Set-Content $global:MS.configPath -Encoding ASCII
}
function global:Aplicar-Modo($m) {
  foreach ($d in $global:MS.dispositivos) {
    $e = $global:MS.estado.dispositivos.($d.id); if (-not $e) { continue }
    if ($m -eq 'jogo') { $e.ativo = $e.jogo } elseif ($m -eq 'trabalho') { $e.ativo = $e.trabalho }
  }
  Salvar-Estado; Gerar-Config
}

# ---------- toast ----------
function Mostrar-Toast($texto, $cor) {
  $w = New-Object System.Windows.Window
  $w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Topmost = $true; $w.ShowInTaskbar = $false
  $w.SizeToContent = 'WidthAndHeight'; $w.WindowStartupLocation = 'Manual'
  $w.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($cor)
  $tb = New-Object System.Windows.Controls.TextBlock
  $tb.Text = $texto; $tb.FontSize = 16; $tb.FontFamily = 'Segoe UI'; $tb.Margin = '22,14,22,14'
  $tb.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#FFFFFF')
  $w.Content = $tb
  $w.Add_Loaded({ $wa = [System.Windows.SystemParameters]::WorkArea; $w.Left = $wa.Right - $w.ActualWidth - 24; $w.Top = $wa.Bottom - $w.ActualHeight - 24 }.GetNewClosure())
  $t = New-Object System.Windows.Threading.DispatcherTimer; $t.Interval = [TimeSpan]::FromSeconds(2.8)
  $t.Add_Tick({ $t.Stop(); $w.Close() }.GetNewClosure()); $t.Start()
  [void]$w.ShowDialog()
}

# ---------- painel ----------
function global:Novo-Brush($hex) { (New-Object System.Windows.Media.BrushConverter).ConvertFromString($hex) }
function global:Novo-Texto($texto, $tam, $cor, $negrito) {
  $tb = New-Object System.Windows.Controls.TextBlock
  $tb.Text = $texto; $tb.FontSize = $tam; $tb.Foreground = Novo-Brush $cor; $tb.TextWrapping = 'Wrap'
  if ($negrito) { $tb.FontWeight = 'SemiBold' }
  return $tb
}
function global:Novo-Botao($texto) {
  $b = New-Object System.Windows.Controls.Button
  $b.Content = $texto; $b.Padding = '14,7,14,7'; $b.Margin = '0,0,8,8'; $b.FontSize = 13
  $b.Background = Novo-Brush '#1E2330'; $b.Foreground = Novo-Brush '#FFFFFF'; $b.BorderThickness = 0; $b.Cursor = 'Hand'
  return $b
}
function global:Novo-Combo($itens, $sel, $tag) {
  $cb = New-Object System.Windows.Controls.ComboBox
  foreach ($i in $itens) { [void]$cb.Items.Add($i) }
  $cb.SelectedItem = $sel; $cb.Tag = $tag; $cb.Margin = '4,0,4,0'; $cb.MinWidth = 150; $cb.VerticalAlignment = 'Center'
  return $cb
}
function global:Set-Status($t) { if ($global:MS.status) { $global:MS.status.Text = $t } }
function global:Rotulo-Perfil($id) { $p = $global:MS.perfis.$id; if ($p) { "$id - $($p.nome)" } else { $id } }
function global:Id-Do-Rotulo($r) { if ($r) { ($r -split ' - ')[0] } else { 'flat' } }

function global:Montar-Ajuste($id) {
  $pa = $global:MS.painelAjuste; $pa.Children.Clear()
  $global:MS.perfilEditando = $id
  $p = $global:MS.perfis.$id
  if (-not $p) { return }
  $d = Novo-Texto $p.descricao 12 '#9AA3B2' $false; $d.Margin = '0,0,0,8'; [void]$pa.Children.Add($d)
  $global:MS.carregando = $true
  $linhas = @([pscustomobject]@{ idx = -1; rotulo = 'Volume base (preamp)'; sub = 'acima de 0 dB = mais alto, mas pode distorcer nos picos'; min = -20; max = 12; val = $p.preamp })
  $i = 0
  foreach ($f in @($p.filtros)) {
    if ($f.tipo -in @('HPQ','LPQ')) { $i++; continue }
    $linhas += [pscustomobject]@{ idx = $i; rotulo = $f.rotulo; sub = "$(Num $f.fc) Hz"; min = -12; max = 12; val = $f.gain }
    $i++
  }
  foreach ($ln in $linhas) {
    $g = New-Object System.Windows.Controls.Grid; $g.Margin = '0,3,0,0'
    foreach ($wd in @('250','*','64')) { $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = (New-Object System.Windows.GridLengthConverter).ConvertFromString($wd); $g.ColumnDefinitions.Add($cd) }
    $lb = Novo-Texto "$($ln.rotulo)" 12 '#E6E6E6' $false; $lb.VerticalAlignment = 'Center'; $lb.ToolTip = $ln.sub
    $sp = New-Object System.Windows.Controls.StackPanel; [void]$sp.Children.Add($lb)
    $sb = Novo-Texto $ln.sub 10 '#7D8795' $false; [void]$sp.Children.Add($sb)
    [System.Windows.Controls.Grid]::SetColumn($sp, 0); [void]$g.Children.Add($sp)
    $s = New-Object System.Windows.Controls.Slider; $s.Minimum = $ln.min; $s.Maximum = $ln.max; $s.TickFrequency = 0.5; $s.IsSnapToTickEnabled = $true
    $s.Value = $ln.val; $s.VerticalAlignment = 'Center'; $s.Margin = '8,0,8,0'; $s.Tag = $ln.idx
    $vl = Novo-Texto "$(Num $ln.val) dB" 12 '#FFFFFF' $true; $vl.VerticalAlignment = 'Center'; $vl.TextAlignment = 'Right'
    $s.Add_ValueChanged({ param($sender, $e)
      $v = [math]::Round($sender.Value * 2) / 2
      $global:MS.ui["sl_$($sender.Tag)"].Text = "$(Num $v) dB"
      if ($global:MS.carregando) { return }
      $p = $global:MS.perfis.($global:MS.perfilEditando)
      if ([int]$sender.Tag -lt 0) { $p.preamp = $v } else { (@($p.filtros))[[int]$sender.Tag].gain = $v }
      $global:MS.timerGravar.Stop(); $global:MS.timerGravar.Start()
    })
    $global:MS.ui["sl_$($ln.idx)"] = $vl
    [System.Windows.Controls.Grid]::SetColumn($s, 1); [void]$g.Children.Add($s)
    [System.Windows.Controls.Grid]::SetColumn($vl, 2); [void]$g.Children.Add($vl)
    [void]$pa.Children.Add($g)
  }
  $global:MS.carregando = $false
}

function Iniciar-GUI {
  Carregar-Perfis; Carregar-Estado
  $apoOk = Test-Path (Split-Path $global:MS.configPath)
  $global:MS.carregando = $true

  $win = New-Object System.Windows.Window
  $win.Title = 'Modo Som HX'; $win.Width = 820; $win.SizeToContent = 'Height'; $win.ResizeMode = 'CanMinimize'
  $win.Background = Novo-Brush '#0F1115'; $win.Foreground = Novo-Brush '#E6E6E6'
  $win.FontFamily = 'Segoe UI'; $win.FontSize = 13; $win.WindowStartupLocation = 'CenterScreen'
  $root = New-Object System.Windows.Controls.StackPanel; $root.Margin = '22,18,22,16'; $win.Content = $root

  [void]$root.Children.Add((Novo-Texto 'Modo Som HX' 21 '#FFFFFF' $true))
  $sub = Novo-Texto 'Equalização por saída de som, dentro do próprio áudio do Windows (sem atraso extra). Mexeu num slider, mudou na hora no fone.' 12 '#9AA3B2' $false
  $sub.Margin = '0,2,0,10'; [void]$root.Children.Add($sub)

  # ligado geral
  $top = New-Object System.Windows.Controls.WrapPanel
  $ckOn = New-Object System.Windows.Controls.CheckBox; $ckOn.Content = 'Equalização ligada'; $ckOn.Foreground = Novo-Brush '#E6E6E6'; $ckOn.IsChecked = [bool]$global:MS.estado.ligado; $ckOn.Margin = '0,0,24,8'; $ckOn.VerticalAlignment = 'Center'
  $ckOn.Add_Checked({ if ($global:MS.carregando) { return }; $global:MS.estado.ligado = $true; Salvar-Estado; Gerar-Config; Set-Status 'Equalização LIGADA.' })
  $ckOn.Add_Unchecked({ if ($global:MS.carregando) { return }; $global:MS.estado.ligado = $false; Salvar-Estado; Gerar-Config; Set-Status 'Equalização DESLIGADA (som puro em todas as saídas).' })
  [void]$top.Children.Add($ckOn)
  $bJogo = Novo-Botao 'Modo Jogo (todas as saídas)'; $bJogo.Add_Click({ Aplicar-Modo 'jogo'; Atualizar-Combos; Set-Status 'Modo Jogo aplicado: cada saída foi pro perfil de jogo dela.' })
  $bTrab = Novo-Botao 'Modo Trabalho (todas as saídas)'; $bTrab.Add_Click({ Aplicar-Modo 'trabalho'; Atualizar-Combos; Set-Status 'Modo Trabalho aplicado.' })
  [void]$top.Children.Add($bJogo); [void]$top.Children.Add($bTrab)
  [void]$root.Children.Add($top)

  # dispositivos
  $h1 = Novo-Texto 'Saídas de som' 15 '#FFFFFF' $true; $h1.Margin = '0,10,0,4'; [void]$root.Children.Add($h1)
  $cab = New-Object System.Windows.Controls.Grid
  foreach ($wd in @('*','160','160','160')) { $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = (New-Object System.Windows.GridLengthConverter).ConvertFromString($wd); $cab.ColumnDefinitions.Add($cd) }
  $i = 0; foreach ($t in @('dispositivo','AGORA','no Modo Jogo','no Modo Trabalho')) { $tb = Novo-Texto $t 11 '#7D8795' $true; $tb.Margin = '4,0,4,2'; [System.Windows.Controls.Grid]::SetColumn($tb, $i); [void]$cab.Children.Add($tb); $i++ }
  [void]$root.Children.Add($cab)
  $rotulos = @((Nomes-Perfis) | ForEach-Object { Rotulo-Perfil $_ })
  foreach ($d in ($global:MS.dispositivos | Sort-Object estado, nome)) {
    $e = $global:MS.estado.dispositivos.($d.id); if (-not $e) { continue }
    $g = New-Object System.Windows.Controls.Grid; $g.Margin = '0,3,0,0'
    foreach ($wd in @('*','160','160','160')) { $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = (New-Object System.Windows.GridLengthConverter).ConvertFromString($wd); $g.ColumnDefinitions.Add($cd) }
    $cor = '#E6E6E6'; if ($d.estado -ne 1) { $cor = '#6B7280' }
    $sp = New-Object System.Windows.Controls.StackPanel
    $n = Novo-Texto $d.nome 13 $cor $false; [void]$sp.Children.Add($n)
    $st = Novo-Texto (Estado-Texto $d.estado) 10 '#7D8795' $false; [void]$sp.Children.Add($st)
    $sp.VerticalAlignment = 'Center'; [System.Windows.Controls.Grid]::SetColumn($sp, 0); [void]$g.Children.Add($sp)
    $col = 1
    foreach ($campo in @('ativo','jogo','trabalho')) {
      $cb = Novo-Combo $rotulos (Rotulo-Perfil $e.$campo) (@{ id = $d.id; campo = $campo })
      $cb.Add_SelectionChanged({ param($sender, $ev)
        if ($global:MS.carregando) { return }
        $t = $sender.Tag; $novo = Id-Do-Rotulo $sender.SelectedItem
        $global:MS.estado.dispositivos.($t.id).($t.campo) = $novo
        Salvar-Estado
        if ($t.campo -eq 'ativo') { Gerar-Config; Set-Status "$($global:MS.estado.dispositivos.($t.id).nome): agora no perfil $novo (já valendo)."; Montar-Ajuste $novo; $global:MS.ui['cbEditar'].SelectedItem = (Rotulo-Perfil $novo) }
        else { Set-Status "Salvo: no Modo $($t.campo) essa saída usa $novo." }
      })
      $global:MS.ui["cb_$($d.id)_$campo"] = $cb
      [System.Windows.Controls.Grid]::SetColumn($cb, $col); [void]$g.Children.Add($cb); $col++
    }
    [void]$root.Children.Add($g)
  }
  if ($global:MS.dispositivos.Count -eq 0) { [void]$root.Children.Add((Novo-Texto 'Nenhuma saída de som encontrada no registro.' 12 '#F0A070' $false)) }

  # ajuste fino
  $h2 = New-Object System.Windows.Controls.WrapPanel; $h2.Margin = '0,16,0,4'
  $t2 = Novo-Texto 'Ajuste fino do perfil:' 15 '#FFFFFF' $true; $t2.VerticalAlignment = 'Center'; [void]$h2.Children.Add($t2)
  $primeiro = 'warzone'
  $cbEditar = Novo-Combo $rotulos (Rotulo-Perfil $primeiro) 'editar'; $cbEditar.Margin = '10,0,0,0'
  $cbEditar.Add_SelectionChanged({ param($sender, $ev) if ($global:MS.carregando) { return }; Montar-Ajuste (Id-Do-Rotulo $sender.SelectedItem) })
  $global:MS.ui['cbEditar'] = $cbEditar; [void]$h2.Children.Add($cbEditar)
  [void]$root.Children.Add($h2)
  $pa = New-Object System.Windows.Controls.StackPanel; $global:MS.painelAjuste = $pa; [void]$root.Children.Add($pa)

  # botões
  $bar = New-Object System.Windows.Controls.WrapPanel; $bar.Margin = '0,14,0,0'
  $bRestaurar = Novo-Botao 'Restaurar perfis de fábrica'
  $bRestaurar.Add_Click({ $global:MS.perfis = Perfis-Padrao; Gravar-Json $global:MS.perfis $global:MS.perfisPath; Gerar-Config; Montar-Ajuste $global:MS.perfilEditando; Set-Status 'Perfis voltaram ao ponto de partida.' })
  $bTeste = Novo-Botao 'Tocar som de teste'
  $bTeste.Add_Click({ $w = @('C:\Windows\Media\Ring08.wav','C:\Windows\Media\Alarm05.wav','C:\Windows\Media\tada.wav') | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($w) { (New-Object System.Media.SoundPlayer $w).Play(); Set-Status 'Tocando no dispositivo padrão. Alterne o perfil e toque de novo pra comparar.' } })
  $bEditor = Novo-Botao 'Editor avançado (Equalizer APO)'
  $bEditor.Add_Click({ $ed = Join-Path $global:MS.apoDir 'Editor.exe'; if (Test-Path $ed) { Start-Process $ed -WorkingDirectory $global:MS.apoDir; Set-Status 'Editor aberto. Ele mostra o config gerado; mudanças por lá são sobrescritas pelo painel.' } else { Set-Status 'Editor.exe não encontrado.' } })
  $bConfig = Novo-Botao 'Dispositivos do Equalizer APO'
  $bConfig.Add_Click({ $c = Join-Path $global:MS.apoDir 'DeviceSelector.exe'; if (Test-Path $c) { Start-Process $c -WorkingDirectory $global:MS.apoDir -Verb RunAs; Set-Status 'Seletor de dispositivos aberto: marque as saídas que devem ter equalização e clique OK.' } else { Set-Status 'DeviceSelector.exe não encontrado.' } })
  foreach ($b in @($bRestaurar, $bTeste, $bEditor, $bConfig)) { [void]$bar.Children.Add($b) }
  [void]$root.Children.Add($bar)

  $status = Novo-Texto '' 12 '#7CD992' $false; $status.Margin = '0,6,0,0'; [void]$root.Children.Add($status)
  $global:MS.status = $status; $global:MS.win = $win
  if ($apoOk) { Set-Status "Pronto. Config do Equalizer APO: $($global:MS.configPath)" }
  else { $status.Foreground = Novo-Brush '#F0A070'; Set-Status 'Equalizer APO NÃO está instalado: o painel salva, mas nada toca diferente até instalar.' }

  # gravação com atraso curto (slider dispara muitas vezes)
  $tg = New-Object System.Windows.Threading.DispatcherTimer; $tg.Interval = [TimeSpan]::FromMilliseconds(180)
  $tg.Add_Tick({ $global:MS.timerGravar.Stop(); Gravar-Json $global:MS.perfis $global:MS.perfisPath; try { Gerar-Config; Set-Status "Perfil $($global:MS.perfilEditando) gravado às $(Get-Date -Format 'HH:mm:ss') (já valendo)." } catch { Set-Status "Não gravei: $($_.Exception.Message)" } })
  $global:MS.timerGravar = $tg

  Montar-Ajuste $primeiro
  $global:MS.carregando = $false
  if ($apoOk) { try { Gerar-Config } catch { Set-Status "Não consegui gravar o config: $($_.Exception.Message)" } }
  [void]$win.ShowDialog()
}
function global:Atualizar-Combos {
  $global:MS.carregando = $true
  foreach ($d in $global:MS.dispositivos) {
    $e = $global:MS.estado.dispositivos.($d.id); if (-not $e) { continue }
    foreach ($campo in @('ativo','jogo','trabalho')) { $cb = $global:MS.ui["cb_$($d.id)_$campo"]; if ($cb) { $cb.SelectedItem = (Rotulo-Perfil $e.$campo) } }
  }
  $global:MS.carregando = $false
}

# ---------- entrada ----------
try {
  if ($Modo -in @('jogo','trabalho')) {
    Carregar-Perfis; Carregar-Estado; Aplicar-Modo $Modo
    Mostrar-Toast "Som em Modo $Modo (perfis aplicados)" '#1E2330'; exit 0
  }
  if ($Gerar) { Carregar-Perfis; Carregar-Estado; Gerar-Config; "config gravado em $($global:MS.configPath)"; exit 0 }
  Iniciar-GUI
} catch {
  if ($Modo) { Mostrar-Toast "Modo Som HX: $($_.Exception.Message)" '#7A2E2E' }
  else { [void][System.Windows.MessageBox]::Show($_.Exception.Message, 'Modo Som HX', 'OK', 'Error') }
  exit 1
}
