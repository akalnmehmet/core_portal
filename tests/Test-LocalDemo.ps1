param([string]$SettingsPath = (Join-Path $PSScriptRoot '../.localdemo/current.json'))
$ErrorActionPreference = 'Stop'
$settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
$baseUrl = $settings.Url.TrimEnd('/')
function Assert-Demo($value, $message) { if (!$value) { throw $message } }
function Login-Demo($email, $password) {
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $page = Invoke-WebRequest "$baseUrl/account/login" -WebSession $session
    $token = [regex]::Match($page.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
    $null = Invoke-WebRequest "$baseUrl/account/login" -WebSession $session -Method Post -ContentType 'application/x-www-form-urlencoded' -Body @{ Email = $email; Password = $password; __RequestVerificationToken = $token }
    return $session
}
$page = Invoke-WebRequest $baseUrl
$text = [System.Net.WebUtility]::HtmlDecode($page.Content)
Assert-Demo ($text.Contains('Yerel gösterim ortamı')) 'Demo etiketi görünmüyor.'
Assert-Demo ($text.Contains('CORE Portal gösterimine hoş geldiniz')) 'Ana sayfada örnek duyuru yok.'
foreach ($path in @('/css/site.css', '/lib/bootstrap/dist/css/bootstrap.min.css', '/lib/bootstrap/dist/js/bootstrap.bundle.min.js')) {
    $asset = Invoke-WebRequest "$baseUrl$path" -SkipHttpErrorCheck
    Assert-Demo ($asset.StatusCode -eq 200) "Yayın çıktısında statik dosya eksik: $path"
}
$projects = Invoke-RestMethod "$baseUrl/api/projects"
$events = Invoke-RestMethod "$baseUrl/api/events"
Assert-Demo ($projects.Count -eq 3) 'Demo proje sayısı hatalı.'
Assert-Demo ($events.Count -eq 3) 'Demo etkinlik sayısı hatalı.'
$past = @($events | Where-Object { ([DateTime]$_.startsAt).ToUniversalTime() -lt [DateTime]::UtcNow })
Assert-Demo ($past.Count -eq 1) 'Demo geçmiş/yaklaşan etkinlik dağılımı hatalı.'
$admin = Login-Demo $settings.AdminEmail $settings.AdminPassword
foreach ($path in @('/admin', '/admin/events', '/admin/announcements', '/admin/applications')) {
    $result = Invoke-WebRequest "$baseUrl$path" -WebSession $admin -SkipHttpErrorCheck
    Assert-Demo ($result.StatusCode -eq 200) "Demo Admin ekranı açılmadı: $path"
}
$member = Login-Demo $settings.MemberEmail $settings.MemberPassword
$profile = Invoke-WebRequest "$baseUrl/profile" -WebSession $member
$profileText = [System.Net.WebUtility]::HtmlDecode($profile.Content)
Assert-Demo ($profileText.Contains('Örnek Öğrenci')) 'Örnek öğrenci profili yok.'
Assert-Demo ($profileText.Contains('Onaylandı') -and $profileText.Contains('Beklemede')) 'Örnek karar durumları profilde yok.'
$forbidden = Invoke-WebRequest "$baseUrl/admin" -WebSession $member -SkipHttpErrorCheck
Assert-Demo ($forbidden.StatusCode -eq 403) 'Örnek öğrenci Admin yetkisine sahip.'
$previousPid = $settings.AppPid
$guarded = $false
try { & (Join-Path $PSScriptRoot '../scripts/Start-LocalDemo.ps1') } catch { $guarded = $_.Exception.Message.Contains('önceki demo oturumunu') }
Assert-Demo $guarded 'İkinci demo başlatma girişimi engellenmedi.'
$after = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
Assert-Demo ($after.AppPid -eq $previousPid) 'İkinci başlatma mevcut demoyu değiştirdi.'
Write-Output 'PASS demo content, published assets, admin/member login, profile states, role boundary, duplicate startup guard'
