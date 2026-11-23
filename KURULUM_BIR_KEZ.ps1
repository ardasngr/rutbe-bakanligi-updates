$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$repo = 'ardasngr/rutbe-bakanligi-updates'
$branch = 'main'
$tokenFile = Join-Path $root 'github_token.dpapi'
$appName = 'Rutbe_Bakanligi_v7_0_1_TIM_SAVASLARI_HATA_DUZELTME.html'
$updaterName = 'Rutbe_Bakanligi_Guncelleyici.ps1'

if (-not (Test-Path -LiteralPath (Join-Path $root 'Rutbe_Bakanligi_Baslat.bat'))) {
  throw 'BAT baslaticisi bu klasorde bulunamadi. Kurulum dosyasini oyun klasorune koy.'
}
if (-not (Test-Path -LiteralPath (Join-Path $root $appName))) {
  throw "$appName bu klasorde bulunamadi."
}

Write-Host ''
Write-Host 'RUTBE BAKANLIGI - TEK SEFERLIK GUNCELLEYICI KURULUMU' -ForegroundColor Yellow
Write-Host 'GitHub tokenini simdi panoya kopyala. Bu pencereye yapistirman gerekmiyor.'
Write-Host 'Token panodan okunacak, dogrulanacak ve Windows hesabinda DPAPI ile sifrelenecek.'
Write-Host ''

$plainToken = (Get-Clipboard -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($plainToken) -or -not $plainToken.StartsWith('github_pat_') -or $plainToken.Length -lt 30) {
  throw 'Panoda gecerli bir github_pat_ tokeni bulunamadi. GitHubdaki Copy simgesine basip tekrar calistir.'
}
Set-Clipboard -Value ''
$secureToken = ConvertTo-SecureString -String $plainToken -AsPlainText -Force
$plainToken = $null

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tokenPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
try { $plainForHeader = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPtr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPtr) }
$headers = @{
  Authorization = "Bearer $plainForHeader"
  Accept = 'application/vnd.github+json'
  'X-GitHub-Api-Version' = '2022-11-28'
  'User-Agent' = 'RutbeBakanligi-Updater-Setup'
}
$plainForHeader = $null

try {
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
  Write-Host 'GitHub baglantisi dogrulandi. Token bu Windows kullanicisinda sifreli saklandi.' -ForegroundColor Green
  Write-Host 'Tek seferlik kurulum tamamlandi; 8.0.1 kontrolu basliyor...' -ForegroundColor Green
  & $updaterPath
}
finally {
  $headers = $null
  $plainForHeader = $null
  $secureToken = $null
  [GC]::Collect()
}
