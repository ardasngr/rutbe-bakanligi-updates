$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$repo = 'ardasngr/rutbe-bakanligi-updates'
$branch = 'main'
$appName = 'Rutbe_Bakanligi_v7_0_1_TIM_SAVASLARI_HATA_DUZELTME.html'
$appFile = Join-Path $root $appName
$tokenFile = Join-Path $root 'github_token.dpapi'
$versionFile = Join-Path $root 'local_version.json'
$logFile = Join-Path $root 'guncelleyici.log'
function Log([string]$Message) {
  $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
  Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
  Write-Host $line
}
function Get-GitHubToken {
  if (-not (Test-Path -LiteralPath $tokenFile)) { throw 'GitHub erisim anahtari bulunamadi. KURULUM_BIR_KEZ.ps1 dosyasini bir kez calistir.' }
  $secure = Get-Content -LiteralPath $tokenFile -Raw | ConvertTo-SecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
function Get-GitHubFileBytes([string]$Path, [string]$Token) {
  $encodedPath = ($Path -split '/') | ForEach-Object { [uri]::EscapeDataString($_) }
  $url = "https://api.github.com/repos/$repo/contents/$($encodedPath -join '/')?ref=$branch"
  $headers = @{
    Authorization = "Bearer $Token"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'RutbeBakanligi-Updater'
  }
  $response = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 30
  if (-not $response.content) { throw "GitHub dosya icerigi bos: $Path" }
  return [Convert]::FromBase64String(($response.content -replace '\s',''))
}
try {
  if (-not (Test-Path -LiteralPath $appFile -PathType Leaf)) { throw "$appName bulunamadi. Baslaticiyi oyun HTML dosyasinin bulundugu klasorden calistir." }
  if (-not (Test-Path -LiteralPath $tokenFile)) { throw 'GitHub erisim anahtari yok. KURULUM_BIR_KEZ.ps1 dosyasini bir kez calistir.' }
  $localVersion = '8.0.0'
  if (Test-Path -LiteralPath $versionFile) {
    try { $localVersion = [string](Get-Content -LiteralPath $versionFile -Raw | ConvertFrom-Json).version } catch { Log 'Yerel surum okunamadi; 8.0.0 varsayiliyor.' }
  }
  if (-not $localVersion) { $localVersion = '8.0.0' }
  Log "Baslatiliyor. Yerel surum: $localVersion"
  $token = Get-GitHubToken
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $manifestBytes = Get-GitHubFileBytes 'latest.json' $token
  $manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
  $remoteVersion = [string]$manifest.version
  if (-not $remoteVersion -or -not $manifest.patchPath -or -not $manifest.sha256) { throw 'latest.json dosyasi eksik veya gecersiz.' }
  if ([version]$remoteVersion -gt [version]$localVersion) {
    if ([string]$manifest.type -ne 'powershell-patch') { throw 'Desteklenmeyen guncelleme turu.' }
    Log "Yeni surum bulundu: $remoteVersion"
    $patchBytes = Get-GitHubFileBytes ([string]$manifest.patchPath) $token
    $patchTemp = Join-Path $root 'Rutbe_Bakanligi_patch.tmp.ps1'
    [IO.File]::WriteAllBytes($patchTemp, $patchBytes)
    $actualHash = (Get-FileHash -LiteralPath $patchTemp -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne ([string]$manifest.sha256).ToLowerInvariant()) {
      Remove-Item -LiteralPath $patchTemp -Force -ErrorAction SilentlyContinue
      throw 'SHA-256 dogrulamasi basarisiz; mevcut oyun dosyasi korunuyor.'
    }
    $patchOutput = & $patchTemp -AppPath $appFile 2>&1
    if (($patchOutput -join "`n") -notmatch 'PATCH_OK\|8\.0\.1\|') { throw "Yama tamamlanamadi: $($patchOutput -join ' ')" }
    Remove-Item -LiteralPath $patchTemp -Force -ErrorAction SilentlyContinue
    @{ version = $remoteVersion; updatedAt = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $versionFile -Encoding UTF8
    Log "Guncelleme tamamlandi: $localVersion -> $remoteVersion"
  } else {
    Log 'Yeni surum yok; mevcut oyun dosyasi aciliyor.'
  }
  if (-not (Test-Path -LiteralPath $versionFile)) { @{ version = $localVersion; installedAt = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $versionFile -Encoding UTF8 }
  Start-Process -FilePath $appFile
} catch {
  Log "GUNCELLEME KONTROLU / BASLATMA HATASI: $($_.Exception.Message)"
  Write-Host $_.Exception.Message -ForegroundColor Red
  if (Test-Path -LiteralPath $appFile) { Start-Process -FilePath $appFile }
}
