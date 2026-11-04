param(
    [string]$DotnetPath = '',
    [string]$PostgresBin = ''
)
$ErrorActionPreference = 'Stop'
if (!$IsWindows -or $PSVersionTable.PSVersion.Major -lt 7) { throw 'Windows üzerinde PowerShell 7 gereklidir.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.TrimEnd('\')
$demoRoot = Join-Path $repo '.localdemo'
$settingsPath = Join-Path $demoRoot 'current.json'
if (Test-Path $settingsPath) { throw 'Önce scripts/Stop-LocalDemo.ps1 ile önceki demo oturumunu kapatın.' }
if (!$DotnetPath) {
    $sdk = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($sdk) { $DotnetPath = $sdk.Source }
    else { $DotnetPath = Join-Path $env:LOCALAPPDATA 'core-portal-dotnet/dotnet.exe' }
}
$dotnetExe = (Get-Command $DotnetPath -ErrorAction Stop).Source
if (!$PostgresBin) { $PostgresBin = Split-Path (Get-Command initdb.exe -ErrorAction Stop).Source }
$pgBin = (Resolve-Path $PostgresBin).Path
foreach ($name in @('initdb.exe', 'pg_ctl.exe', 'createdb.exe')) {
    if (!(Test-Path (Join-Path $pgBin $name))) { throw "$name bulunamadı." }
}
function Demo-FreePort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    try { $listener.Start(); return $listener.LocalEndpoint.Port } finally { $listener.Stop() }
}
$pgPort = Demo-FreePort
$webPort = Demo-FreePort
while ($pgPort -eq $webPort) { $webPort = Demo-FreePort }
$url = "http://127.0.0.1:$webPort"
$runPath = Join-Path $demoRoot ('run-' + [guid]::NewGuid().ToString('N'))
$pgData = Join-Path $runPath 'pgdata'
$appRoot = Join-Path $runPath 'app'
$appDll = Join-Path $appRoot 'CorePortal.Web.dll'
$adminPassword = 'Demo!' + [guid]::NewGuid().ToString('N')
$memberPassword = 'Student!' + [guid]::NewGuid().ToString('N')
$names = @('ConnectionStrings__DefaultConnection', 'BootstrapAdmin__Email', 'BootstrapAdmin__Password', 'ASPNETCORE_ENVIRONMENT', 'DOTNET_ENVIRONMENT', 'GitHub__Owner', 'Demo__Enabled')
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$app = $null
$pgStarted = $false
$completed = $false
New-Item -ItemType Directory -Path $runPath -Force | Out-Null
try {
    & $dotnetExe publish (Join-Path $repo 'src/CorePortal.Web/CorePortal.Web.csproj') --no-restore -c Release -o $appRoot -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Yayın çıktısı hazırlanamadı. Önce dotnet restore çalıştırın.' }
    & (Join-Path $pgBin 'initdb.exe') -D $pgData -U core_demo -A trust --encoding UTF8 --locale=C --no-sync
    if ($LASTEXITCODE -ne 0) { throw 'Demo veritabanı kümesi oluşturulamadı.' }
    & (Join-Path $pgBin 'pg_ctl.exe') -D $pgData -l (Join-Path $runPath 'postgres.log') -o "-h 127.0.0.1 -p $pgPort" -w start
    if ($LASTEXITCODE -ne 0) { throw 'Demo PostgreSQL başlatılamadı.' }
    $pgStarted = $true
    & (Join-Path $pgBin 'createdb.exe') -h 127.0.0.1 -p $pgPort -U core_demo core_portal_demo
    if ($LASTEXITCODE -ne 0) { throw 'Demo veritabanı oluşturulamadı.' }
    $env:ConnectionStrings__DefaultConnection = "Host=127.0.0.1;Port=$pgPort;Database=core_portal_demo;Username=core_demo"
    $env:BootstrapAdmin__Email = 'demo-admin@example.test'
    $env:BootstrapAdmin__Password = $adminPassword
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $env:DOTNET_ENVIRONMENT = 'Development'
    $env:GitHub__Owner = ''
    $env:Demo__Enabled = 'true'
    $app = Start-Process -FilePath $dotnetExe -ArgumentList @(('"' + $appDll + '"'), '--urls', $url) -WorkingDirectory $appRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $runPath 'app.log') -RedirectStandardError (Join-Path $runPath 'app-error.log') -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    $ready = $false
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($app.HasExited) { throw 'Demo uygulaması başlangıçta kapandı.' }
        try { $response = Invoke-WebRequest $url -TimeoutSec 2 -SkipHttpErrorCheck; $ready = $response.StatusCode -eq 200 } catch { }
        if ($ready) { break }
        Start-Sleep -Milliseconds 250
    }
    if (!$ready) { throw 'Demo uygulaması hazır olmadı.' }
    & (Join-Path $PSScriptRoot 'Initialize-DemoContent.ps1') -BaseUrl $url -AdminEmail 'demo-admin@example.test' -AdminPassword $adminPassword -MemberEmail 'demo-student@example.test' -MemberPassword $memberPassword
    @{
        Url = $url; RunPath = $runPath; PgData = $pgData; PostgresBin = $pgBin
        AppPid = $app.Id; AppStartedTicks = $app.StartTime.ToUniversalTime().Ticks; AppDll = $appDll; DotnetPath = $dotnetExe
        AdminEmail = 'demo-admin@example.test'; AdminPassword = $adminPassword
        MemberEmail = 'demo-student@example.test'; MemberPassword = $memberPassword
    } | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding utf8
    $completed = $true
    Write-Output "Demo hazır: $url"
    Write-Output "Giriş bilgileri: $settingsPath"
    Write-Output 'Kapatma: ./scripts/Stop-LocalDemo.ps1'
}
catch {
    foreach ($name in @('app-error.log', 'app.log')) {
        $log = Join-Path $runPath $name
        if (Test-Path $log) { Get-Content -LiteralPath $log -Tail 10 | Write-Output }
    }
    throw
}
finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    if (!$completed) {
        if ($app -and !$app.HasExited) { Stop-Process -Id $app.Id -Force; $app.WaitForExit() }
        $stopped = $true
        if ($pgStarted) { & (Join-Path $pgBin 'pg_ctl.exe') -D $pgData -m fast -w stop; $stopped = $LASTEXITCODE -eq 0 }
        if ($stopped -and (Test-Path $runPath)) {
            $resolved = (Resolve-Path $runPath).Path
            if (!$resolved.StartsWith($demoRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Demo temizleme yolu geçersiz.' }
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
