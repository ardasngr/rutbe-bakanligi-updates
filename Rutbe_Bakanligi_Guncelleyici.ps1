$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$appName = 'Rutbe_Bakanligi_v7_0_1_TIM_SAVASLARI_HATA_DUZELTME.html'
$appFile = Join-Path $root $appName
$versionFile = Join-Path $root 'local_version.json'
$logFile = Join-Path $root 'guncelleyici.log'
$rawBase = 'https://raw.githubusercontent.com/ardasngr/rutbe-bakanligi-updates/main'

function Log([string]$Message) {
  $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
  Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
  Write-Host $line
}
function Get-AppVersion([string]$Path) {
  $html = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
  $m = [regex]::Match($html, "const\s+RB_V8_VERSION\s*=\s*'([^']+)'\s*;")
  if ($m.Success) { return $m.Groups[1].Value }
  if (Test-Path -LiteralPath $versionFile) {
    try { return [string](Get-Content -LiteralPath $versionFile -Raw | ConvertFrom-Json).version } catch {}
  }
  return '8.0.0'
}
function Get-RawUrl([string]$RelativePath) {
  $parts = $RelativePath -split '/'
  $safe = ($parts | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
  return "$rawBase/$safe?nocache=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
}

try {
  if (-not (Test-Path -LiteralPath $appFile -PathType Leaf)) {
    throw "$appName bulunamadi. Baslatma dosyalarini oyunun HTML dosyasinin bulundugu klasorde tut."
  }

  # This public-read updater no longer needs any GitHub token.
  foreach ($obsoleteTokenFile in @('github_token.txt','github_token.dpapi')) {
    $obsoletePath = Join-Path $root $obsoleteTokenFile
    if (Test-Path -LiteralPath $obsoletePath) {
      Remove-Item -LiteralPath $obsoletePath -Force -ErrorAction SilentlyContinue
    }
  }

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $headers = @{ 'Cache-Control' = 'no-cache'; 'User-Agent' = 'RutbeBakanligi-Updater' }
  $localVersion = Get-AppVersion $appFile
  Log "Baslatiliyor. Yerel surum: $localVersion"

  $manifestUrl = Get-RawUrl 'latest.json'
  $manifest = Invoke-RestMethod -Uri $manifestUrl -Headers $headers -TimeoutSec 30
  $remoteVersion = [string]$manifest.version
  if (-not $remoteVersion -or -not $manifest.patchPath -or -not $manifest.sha256) {
    throw 'Guncelleme manifesti eksik veya gecersiz.'
  }
  if ([string]$manifest.type -ne 'powershell-patch') { throw 'Desteklenmeyen guncelleme turu.' }
  if ([string]$manifest.patchPath -notmatch '^patches/[A-Za-z0-9._-]+\.ps1$') {
    throw 'Manifestteki yama yolu guvenlik kontrolunden gecmedi.'
  }

  if ([version]$remoteVersion -gt [version]$localVersion) {
    Log "Yeni surum bulundu: $remoteVersion"
    $patchTemp = Join-Path $root 'Rutbe_Bakanligi_patch.tmp.ps1'
    $patchUrl = Get-RawUrl ([string]$manifest.patchPath)
    Invoke-WebRequest -Uri $patchUrl -Headers $headers -OutFile $patchTemp -TimeoutSec 60 -UseBasicParsing
    if (-not (Test-Path -LiteralPath $patchTemp) -or (Get-Item -LiteralPath $patchTemp).Length -lt 100) {
      throw 'Yama dosyasi indirilemedi veya bos.'
    }
    $actualHash = (Get-FileHash -LiteralPath $patchTemp -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne ([string]$manifest.sha256).ToLowerInvariant()) {
      Remove-Item -LiteralPath $patchTemp -Force -ErrorAction SilentlyContinue
      throw 'SHA-256 dogrulamasi basarisiz; mevcut oyun dosyasi korunuyor.'
    }

    $patchOutput = & $patchTemp -AppPath $appFile 2>&1
    $patchText = $patchOutput -join [Environment]::NewLine
    if ($patchText -notmatch [regex]::Escape("PATCH_OK|$remoteVersion|")) {
      throw "Yama beklenen onay mesajini vermedi: $patchText"
    }
    Remove-Item -LiteralPath $patchTemp -Force -ErrorAction SilentlyContinue

    $installedVersion = Get-AppVersion $appFile
    if ($installedVersion -ne $remoteVersion) { throw "Dosya guncellendi ancak HTML surumu beklenenden farkli: $installedVersion" }
    @{ version = $remoteVersion; updatedAt = (Get-Date).ToString('o') } |
      ConvertTo-Json | Set-Content -LiteralPath $versionFile -Encoding UTF8
    Log "Guncelleme tamamlandi: $localVersion -> $remoteVersion"
  } else {
    Log 'Yeni surum yok; mevcut oyun dosyasi aciliyor.'
    @{ version = $localVersion; checkedAt = (Get-Date).ToString('o') } |
      ConvertTo-Json | Set-Content -LiteralPath $versionFile -Encoding UTF8
  }
  Start-Process -FilePath $appFile
}
catch {
  Log "GUNCELLEME KONTROLU BASARISIZ: $($_.Exception.Message)"
  Write-Host "Guncelleme kontrol edilemedi: $($_.Exception.Message)" -ForegroundColor Yellow
  if (Test-Path -LiteralPath $appFile) {
    Write-Host 'Mevcut oyun surumu aciliyor; yerel dosya korunmustur.' -ForegroundColor Green
    Start-Process -FilePath $appFile
  } else {
    exit 1
  }
}