param(
  [Parameter(Mandatory=$true)][string]$AppPath
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $AppPath -PathType Leaf)) {
  throw "Oyun HTML dosyasi bulunamadi: $AppPath"
}

$source = [IO.File]::ReadAllText($AppPath, [Text.Encoding]::UTF8)
$versionMatch = [regex]::Match($source, "const\s+RB_V8_VERSION\s*=\s*'([^']+)'\s*;")
if (-not $versionMatch.Success) { throw 'Uygulama surumu HTML icinde bulunamadi.' }

$oldVersion = $versionMatch.Groups[1].Value
if ($oldVersion -notin @('8.0.0','8.0.1','8.0.2','8.0.3')) {
  throw "Beklenmeyen kaynak surum: $oldVersion."
}

function Replace-ExactlyOnce([string]$Text, [string]$Pattern, [string]$Replacement, [string]$Label) {
  $count = [regex]::Matches($Text, $Pattern).Count
  if ($count -ne 1) { throw "Yama durduruldu: $Label icin tek eslesme bekleniyordu; bulunan: $count" }
  $rx = [regex]::new($Pattern)
  return $rx.Replace($Text, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $Replacement }, 1)
}

$source = Replace-ExactlyOnce $source '<title>Rütbe Bakanlığı v8\.0\.[0-3] - [^<]*</title>' '<title>Rütbe Bakanlığı v8.0.4 - Otomatik Güncelleme Testi</title>' 'HTML basligi'
$source = Replace-ExactlyOnce $source 'SÜRÜM 8\.0\.[0-3] · [^<]*' 'SÜRÜM 8.0.4 · GÜNCELLEME TESTİ' 'Sol menu surum etiketi'
$source = Replace-ExactlyOnce $source '<span class="rb-version-pill">v8\.0\.[0-3]</span>' '<span class="rb-version-pill">v8.0.4</span>' 'Ust surum rozeti'
$source = Replace-ExactlyOnce $source '<div class="eyebrow">8\.0\.[0-3] · [^<]*</div>' '<div class="eyebrow">8.0.4 · OTOMATİK GÜNCELLEME TESTİ</div>' 'Veri merkezi etiketi'
$source = Replace-ExactlyOnce $source 'Rütbe Bakanlığı 8\.0\.[0-3]</h2>' 'Rütbe Bakanlığı 8.0.4</h2>' 'Surum basligi'
$source = Replace-ExactlyOnce $source "const RB_V8_VERSION = '8\.0\.[0-3]';" "const RB_V8_VERSION = '8.0.4';" 'Uygulama surum sabiti'

$releaseParagraph = '<p class="rb-help"><b>8.0.4:</b> Otomatik güncelleme test sürümü.</p>'
if ($source -match '<p class="rb-help"><b>8\.0\.[0-3]:</b>[^<]*</p>') {
  $rx = [regex]::new('<p class="rb-help"><b>8\.0\.[0-3]:</b>[^<]*</p>')
  $source = $rx.Replace($source, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $releaseParagraph }, 1)
} else {
  $anchor = '<div class="rb-update-status" id="rbUpdateSourceStatus">Güncelleme kaynağı: henüz bağlanmadı</div>'
  $source = $source.Replace($anchor, $anchor + $releaseParagraph)
}

$fullPath = [IO.Path]::GetFullPath($AppPath)
$dir = Split-Path -Parent $fullPath
$backupDir = Join-Path $dir 'Surum_Yedekleri'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupName = "Rutbe_Bakanligi_{0}_{1}.html" -f $oldVersion, $stamp
$backup = Join-Path $backupDir $backupName
Copy-Item -LiteralPath $fullPath -Destination $backup -Force
$tmp = "$fullPath.update.tmp"
[IO.File]::WriteAllText($tmp, $source, (New-Object System.Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmp -Destination $fullPath -Force

Write-Output "PATCH_OK|8.0.4|$backup"
