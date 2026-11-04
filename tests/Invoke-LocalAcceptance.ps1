param(
    [string]$DotnetPath = 'dotnet',
    [string]$PostgresBin = '',
    [switch]$KeepArtifacts
)
$ErrorActionPreference = 'Stop'
if (!$IsWindows -or $PSVersionTable.PSVersion.Major -lt 7) { throw 'Bu yardımcı Windows üzerinde PowerShell 7 gerektirir.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.TrimEnd('\')
$dotnetCommand = Get-Command $DotnetPath -ErrorAction Stop
$dotnetExe = $dotnetCommand.Source
if (!$PostgresBin) { $PostgresBin = Split-Path (Get-Command initdb.exe -ErrorAction Stop).Source }
$pgBin = (Resolve-Path $PostgresBin).Path
foreach ($name in @('initdb.exe', 'pg_ctl.exe', 'createdb.exe')) {
    if (!(Test-Path (Join-Path $pgBin $name))) { throw "$name bulunamadı: $pgBin" }
}
function Find-FreePort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    try { $listener.Start(); return $listener.LocalEndpoint.Port } finally { $listener.Stop() }
}
$runPath = Join-Path (Join-Path $repo '.localtest') ('acceptance-' + [guid]::NewGuid().ToString('N'))
$pgData = Join-Path $runPath 'pgdata'
$project = Join-Path $repo 'src/CorePortal.Web/CorePortal.Web.csproj'
$contentRoot = Split-Path $project
$appDll = Join-Path $contentRoot 'bin/Debug/net10.0/CorePortal.Web.dll'
$pgPort = Find-FreePort
$webPort = Find-FreePort
while ($webPort -eq $pgPort) { $webPort = Find-FreePort }
$baseUrl = "http://127.0.0.1:$webPort"
$testEmail = 'acceptance-admin@example.test'
$testPassword = 'Acceptance!' + [guid]::NewGuid().ToString('N')
$names = @('ConnectionStrings__DefaultConnection', 'BootstrapAdmin__Email', 'BootstrapAdmin__Password', 'ASPNETCORE_ENVIRONMENT', 'GitHub__Owner')
$savedEnvironment = @{}
foreach ($name in $names) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$app = $null
$postgresStarted = $false
New-Item -ItemType Directory -Path $runPath -Force | Out-Null
try {
    & $dotnetExe build $project --no-restore
    if ($LASTEXITCODE -ne 0) { throw 'Derleme başarısız. Önce dotnet restore çalıştırın ve hataları giderin.' }
    & (Join-Path $pgBin 'initdb.exe') -D $pgData -U core_test -A trust --encoding UTF8 --locale=C --no-sync
    if ($LASTEXITCODE -ne 0) { throw 'Geçici PostgreSQL kümesi oluşturulamadı.' }
    & (Join-Path $pgBin 'pg_ctl.exe') -D $pgData -l (Join-Path $runPath 'postgres.log') -o "-h 127.0.0.1 -p $pgPort" -w start
    if ($LASTEXITCODE -ne 0) { throw 'Geçici PostgreSQL başlatılamadı.' }
    $postgresStarted = $true
    & (Join-Path $pgBin 'createdb.exe') -h 127.0.0.1 -p $pgPort -U core_test core_portal_acceptance
    if ($LASTEXITCODE -ne 0) { throw 'Geçici veritabanı oluşturulamadı.' }
    $env:ConnectionStrings__DefaultConnection = "Host=127.0.0.1;Port=$pgPort;Database=core_portal_acceptance;Username=core_test"
    $env:BootstrapAdmin__Email = $testEmail
    $env:BootstrapAdmin__Password = $testPassword
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $env:GitHub__Owner = ''
    $app = Start-Process -FilePath $dotnetExe -ArgumentList @(('"' + $appDll + '"'), '--urls', $baseUrl) -WorkingDirectory $contentRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $runPath 'app.log') -RedirectStandardError (Join-Path $runPath 'app-error.log') -PassThru
    $ready = $false
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($app.HasExited) { throw 'Test uygulaması açılışta kapandı.' }
        try { $response = Invoke-WebRequest $baseUrl -TimeoutSec 2 -SkipHttpErrorCheck; $ready = $response.StatusCode -eq 200 } catch { }
        if ($ready) { break }
        Start-Sleep -Milliseconds 250
    }
    if (!$ready) { throw 'Test uygulaması 30 saniyede hazır olmadı.' }
    & (Join-Path $PSScriptRoot 'Smoke.ps1') -BaseUrl $baseUrl -AdminEmail $testEmail -AdminPassword $testPassword
    & (Join-Path $PSScriptRoot 'PortalFlows.ps1') -BaseUrl $baseUrl -AdminEmail $testEmail -AdminPassword $testPassword
    Write-Output 'PASS isolated local acceptance'
}
catch {
    foreach ($log in @('app-error.log', 'app.log')) {
        $path = Join-Path $runPath $log
        if (Test-Path $path) { Get-Content -LiteralPath $path -Tail 15 | Write-Output }
    }
    throw
}
finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
    if ($app -and !$app.HasExited) { Stop-Process -Id $app.Id -Force; $app.WaitForExit() }
    $stopped = $true
    if ($postgresStarted) {
        & (Join-Path $pgBin 'pg_ctl.exe') -D $pgData -m fast -w stop
        $stopped = $LASTEXITCODE -eq 0
    }
    if (!$stopped) { Write-Warning "PostgreSQL durdurulamadı; dosyalar silinmedi: $runPath" }
    elseif ($KeepArtifacts) { Write-Output "Test dosyaları korundu: $runPath" }
    elseif (Test-Path $runPath) {
        $resolved = (Resolve-Path $runPath).Path
        $expectedRoot = Join-Path $repo '.localtest'
        if (!$resolved.StartsWith($expectedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Temizleme yolu test klasörünün dışında.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
        Write-Output 'Geçici test kümesi ve kayıtları temizlendi.'
    }
}
