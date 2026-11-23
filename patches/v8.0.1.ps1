param(
  [Parameter(Mandatory=$true)][string]$AppPath
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $AppPath -PathType Leaf)) { throw "Oyun HTML dosyasi bulunamadi: $AppPath" }
$source = [IO.File]::ReadAllText($AppPath, [Text.Encoding]::UTF8)
$replacements = @(
  @('<title>Rütbe Bakanlığı v8.0.0 - Komuta ve Veri Güvenliği</title>', '<title>Rütbe Bakanlığı v8.0.1 - Güncelleme Testi</title>'),
  @('SÜRÜM 8.0.0 · VERİ GÜVENLİĞİ', 'SÜRÜM 8.0.1 · GÜNCELLEME TESTİ'),
  @('<span class="rb-version-pill">v8.0.0</span>', '<span class="rb-version-pill">v8.0.1</span>'),
  @('<div class="eyebrow">8.0.0 · KAYIT GÜVENLİĞİ</div>', '<div class="eyebrow">8.0.1 · GÜNCELLEME DOĞRULAMASI</div>'),
  @('Rütbe Bakanlığı 8.0.0</h2>', 'Rütbe Bakanlığı 8.0.1</h2>'),
  @('<div class="rb-update-status" id="rbUpdateSourceStatus">Güncelleme kaynağı: henüz bağlanmadı</div>', '<div class="rb-update-status" id="rbUpdateSourceStatus">Güncelleme kaynağı: henüz bağlanmadı</div><p class="rb-help"><b>8.0.1:</b> Güncelleme başlatıcısının sürüm bulma, SHA-256 doğrulama, önceki dosyayı yedekleme ve aynı HTML dosyasını yenileme akışı için test sürümü.</p>'),
  @("const RB_V8_VERSION = '8.0.0';", "const RB_V8_VERSION = '8.0.1';")
)
foreach ($pair in $replacements) {
  $old = [string]$pair[0]; $new = [string]$pair[1]
  $count = ([regex]::Matches($source, [regex]::Escape($old))).Count
  if ($count -ne 1) { throw "Yama durduruldu: beklenen tek eslesme bulunamadi (count=$count): $old" }
  $source = $source.Replace($old, $new)
}
if ($source -notmatch 'RB_V8_VERSION\s*=\s*''8\.0\.1''') { throw 'Son dogrulama basarisiz: uygulama surumu 8.0.1 degil.' }
$fullPath = [IO.Path]::GetFullPath($AppPath)
$dir = Split-Path -Parent $fullPath
$backupDir = Join-Path $dir 'Surum_Yedekleri'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $backupDir "Rutbe_Bakanligi_8.0.0_$stamp.html"
Copy-Item -LiteralPath $fullPath -Destination $backup -Force
$tmp = "$fullPath.update.tmp"
[IO.File]::WriteAllText($tmp, $source, (New-Object System.Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmp -Destination $fullPath -Force
Write-Output "PATCH_OK|8.0.1|$backup"
