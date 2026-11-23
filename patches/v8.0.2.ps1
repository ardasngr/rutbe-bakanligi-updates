param(
  [Parameter(Mandatory=$true)][string]$AppPath
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $AppPath -PathType Leaf)) { throw "Oyun HTML dosyasi bulunamadi: $AppPath" }
$source = [IO.File]::ReadAllText($AppPath, [Text.Encoding]::UTF8)
$versionMatch = [regex]::Match($source, "const\s+RB_V8_VERSION\s*=\s*'([^']+)'\s*;")
if (-not $versionMatch.Success) { throw 'Uygulama surumu HTML icinde bulunamadi.' }
$oldVersion = $versionMatch.Groups[1].Value
if ($oldVersion -notin @('8.0.0','8.0.1')) { throw "Beklenmeyen kaynak surum: $oldVersion. 8.0.0 veya 8.0.1 bekleniyordu." }

function Replace-ExactlyOnce([string]$Text, [string]$Pattern, [string]$Replacement, [string]$Label) {
  $count = [regex]::Matches($Text, $Pattern).Count
  if ($count -ne 1) { throw "Yama durduruldu: $Label icin tek eslesme bekleniyordu; bulunan: $count" }
  return [regex]::Replace($Text, $Pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $Replacement }, 1)
}

$source = Replace-ExactlyOnce $source '<title>Rütbe Bakanlığı v8\.0\.[01] - [^<]*</title>' '<title>Rütbe Bakanlığı v8.0.2 - Otomatik Güncelleme Testi</title>' 'HTML basligi'
$source = Replace-ExactlyOnce $source 'SÜRÜM 8\.0\.[01] · [^<]*' 'SÜRÜM 8.0.2 · GÜNCELLEME TESTİ' 'Sol menu surum etiketi'
$source = Replace-ExactlyOnce $source '<span class="rb-version-pill">v8\.0\.[01]</span>' '<span class="rb-version-pill">v8.0.2</span>' 'Ust surum rozeti'
$source = Replace-ExactlyOnce $source '<div class="eyebrow">8\.0\.[01] · [^<]*</div>' '<div class="eyebrow">8.0.2 · OTOMATİK GÜNCELLEME TESTİ</div>' 'Veri merkezi etiketi'
$source = Replace-ExactlyOnce $source 'Rütbe Bakanlığı 8\.0\.[01]</h2>' 'Rütbe Bakanlığı 8.0.2</h2>' 'Surum basligi'
$source = Replace-ExactlyOnce $source "const RB_V8_VERSION = '8\.0\.[01]';" "const RB_V8_VERSION = '8.0.2';" 'Uygulama surum sabiti'

$releaseParagraph = '<p class="rb-help"><b>8.0.2:</b> Otomatik güncelleme doğrulama sürümü. Oyun kayıt anahtarı ve mevcut personel verileri korunur.</p>'
if ($source -match '<p class="rb-help"><b>8\.0\.[01]:</b>[^<]*</p>') {
  $source = [regex]::Replace($source, '<p class="rb-help"><b>8\.0\.[01]:</b>[^<]*</p>', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $releaseParagraph }, 1)
} else {
  $anchor = '<div class="rb-update-status" id="rbUpdateSourceStatus">Güncelleme kaynağı: henüz bağlanmadı</div>'
  if (([regex]::Matches($source, [regex]::Escape($anchor))).Count -ne 1) { throw 'Guncelleme merkezi notu icin ekleme noktasi bulunamadi.' }
  $source = $source.Replace($anchor, $anchor + $releaseParagraph)
}
if ($source -notmatch "const\s+RB_V8_VERSION\s*=\s*'8\.0\.2'\s*;") { throw 'Son surum dogrulamasi basarisiz.' }
if ($source -notmatch 'rutbeBakanligi') { throw 'Oyun kayit anahtari dogrulamasi basarisiz.' }

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
Write-Output "PATCH_OK|8.0.2|$backup"
