param([switch]$KeepFiles)
$ErrorActionPreference = 'Stop'
if (!$IsWindows -or $PSVersionTable.PSVersion.Major -lt 7) { throw 'Windows üzerinde PowerShell 7 gereklidir.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.TrimEnd('\')
$demoRoot = Join-Path $repo '.localdemo'
$settingsPath = Join-Path $demoRoot 'current.json'
if (!(Test-Path $settingsPath)) { Write-Output 'Açık demo oturumu bulunamadı.'; return }
$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$runPath = (Resolve-Path $settings.RunPath).Path
if (!$runPath.StartsWith($demoRoot + '\run-', [StringComparison]::OrdinalIgnoreCase)) { throw 'Demo çalışma klasörü beklenen konumda değil.' }
$pgData = (Resolve-Path $settings.PgData).Path
if ($pgData -ne (Join-Path $runPath 'pgdata')) { throw 'Demo veritabanı yolu geçersiz.' }
if ($settings.AppDll -ne (Join-Path $runPath 'app/CorePortal.Web.dll')) { throw 'Demo uygulama yolu geçersiz.' }
$app = Get-Process -Id ([int]$settings.AppPid) -ErrorAction SilentlyContinue
if ($app) {
    $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$($app.Id)"
    if ($app.Path -ne $settings.DotnetPath -or $app.StartTime.ToUniversalTime().Ticks -ne [long]$settings.AppStartedTicks -or !$processInfo.CommandLine.Contains($settings.AppDll)) {
        throw 'Süreç kimliği demo uygulamasıyla eşleşmiyor; işlem durdurulmadı.'
    }
    Stop-Process -Id $app.Id -Force
    $app.WaitForExit()
}
$pgCtl = Join-Path $settings.PostgresBin 'pg_ctl.exe'
& $pgCtl -D $pgData status | Out-Null
if ($LASTEXITCODE -eq 0) {
    & $pgCtl -D $pgData -m fast -w stop
    if ($LASTEXITCODE -ne 0) { throw 'Demo PostgreSQL kapatılamadı; dosyalar korundu.' }
} elseif ($LASTEXITCODE -ne 3) { throw 'Demo PostgreSQL durumu belirlenemedi; dosyalar korundu.' }
if ($KeepFiles) {
    Copy-Item -LiteralPath $settingsPath -Destination (Join-Path $runPath 'demo-settings.json')
    Write-Output "Demo kapatıldı; dosyalar korundu: $runPath"
} else {
    # runPath has been resolved and verified to be inside this repository's demo root.
    Remove-Item -LiteralPath $runPath -Recurse -Force
    Write-Output 'Demo kapatıldı; örnek veritabanı, giriş bilgileri ve dosyaları temizlendi.'
}
Remove-Item -LiteralPath $settingsPath -Force
