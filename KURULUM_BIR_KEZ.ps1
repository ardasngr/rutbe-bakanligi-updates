$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$repo = 'ardasngr/rutbe-bakanligi-updates'
$branch = 'main'
$tokenFile = Join-Path $root 'github_token.dpapi'
$appName = 'Rutbe_Bakanligi_v7_0_1_TIM_SAVASLARI_HATA_DUZELTME.html'
$updaterName = 'Rutbe_Bakanligi_Guncelleyici.ps1'
if (-not (Test-Path -LiteralPath (Join-Path $root 'Rutbe_Bakanligi_Baslat.bat'))) { throw 'BAT baslaticisi bu klasorde bulunamadi. KURULUM_BIR_KEZ.ps1 dosyasini BAT dosyasinin yaninda calistir.' }
if (-not (Test-Path -LiteralPath (Join-Path $root $appName))) { throw "$appName bu klasorde bulunamadi." }
Write-Host ''
Write-Host 'RUTBE BAKANLIGI - TEK SEFERLIK GUNCELLEYICI KURULUMU' -ForegroundColor Yellow
Write-Host "GitHub hesabinda yalnizca rutbe-bakanligi-updates deposuna Contents: Read-only izinli Fine-grained PAT olustur."
Write-Host 'Tokeni buraya degil, yalnizca asagidaki PowerShell istemine gir. Token Windows kullanici hesabinda DPAPI ile sifrelenecek.'
Write-Host ''
$secureToken = Read-Host 'GitHub erisim anahtarini yapistir (giris ekranda gorunmez)' -AsSecureString
if ($secureToken.Length -lt 20) { throw 'Token cok kisa veya bos gorunuyor.' }
$plainPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($plainPtr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($plainPtr) }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28'; 'User-Agent' = 'RutbeBakanligi-Updater-Setup' }
$repoInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo" -Headers $headers -TimeoutSec 30
if (-not $repoInfo.private) { throw 'Guncelleme deposu Private degil. Islemi durdurdum.' }
if (-not $repoInfo.permissions.pull) { throw 'Tokenin depoda okuma izni yok. Contents: Read-only yetkisini kontrol et.' }
$encrypted = $secureToken | ConvertFrom-SecureString
Set-Content -LiteralPath $tokenFile -Value $encrypted -Encoding ASCII
$apiPath = [uri]::EscapeDataString($updaterName)
$updaterResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/contents/$apiPath?ref=$branch" -Headers $headers -TimeoutSec 30
$updaterBytes = [Convert]::FromBase64String(($updaterResponse.content -replace '\s',''))
$updaterPath = Join-Path $root $updaterName
$tmp = "$updaterPath.download.tmp"
[IO.File]::WriteAllBytes($tmp, $updaterBytes)
Move-Item -LiteralPath $tmp -Destination $updaterPath -Force
if (-not (Test-Path -LiteralPath (Join-Path $root 'local_version.json'))) {
  @{ version = '8.0.0'; installedAt = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'local_version.json') -Encoding UTF8
}
Write-Host ''
Write-Host 'Tek seferlik kurulum tamamlandi. Masaustundeki BAT artik ozel GitHub deposundan guncelleme kontrolu yapabilir.' -ForegroundColor Green
Write-Host 'Simdi BAT dosyasini aciyorum...' -ForegroundColor Green
& $updaterPath
