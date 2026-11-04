param(
    [Parameter(Mandatory)] [string]$BaseUrl,
    [Parameter(Mandatory)] [string]$AdminEmail,
    [Parameter(Mandatory)] [string]$AdminPassword,
    [Parameter(Mandatory)] [string]$MemberEmail,
    [Parameter(Mandatory)] [string]$MemberPassword
)
$ErrorActionPreference = 'Stop'
function Demo-Get($path, $session) {
    return Invoke-WebRequest "$BaseUrl$path" -WebSession $session
}
function Demo-Post($path, $body, $session, $tokenPath = $path) {
    $page = Demo-Get $tokenPath $session
    $body['__RequestVerificationToken'] = [regex]::Match($page.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
    return Invoke-WebRequest "$BaseUrl$path" -WebSession $session -Method Post -ContentType 'application/x-www-form-urlencoded' -Body $body
}
function Demo-Id($page, $name, $pattern) {
    $row = [regex]::Matches($page.Content, '(?s)<tr>.*?</tr>') | Where-Object { [System.Net.WebUtility]::HtmlDecode($_.Value).Contains($name) } | Select-Object -First 1
    $id = [regex]::Match($row.Value, $pattern).Groups[1].Value
    if (!$id) { throw "Demo kaydı oluşturulamadı: $name" }
    return [int]$id
}
$admin = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$null = Demo-Post '/account/login' @{ Email = $AdminEmail; Password = $AdminPassword } $admin
$null = Demo-Get '/admin' $admin
$teamIds = @()
foreach ($team in @(
    @{ Name = 'Otonom Sistemler'; Field = 'Robotik'; FoundedYear = '2026'; Description = "Algılama, hareket planlama ve kontrol üzerine çalışan örnek Ar-Ge takımı.`nBu kayıt yerel gösterim için hazırlanmıştır." },
    @{ Name = 'Yazılım ve Araştırma'; Field = 'Yazılım'; FoundedYear = '2026'; Description = 'Web teknolojileri ve veri odaklı uygulamalar geliştiren örnek takım. Yerel gösterim verisidir.' }
)) {
    $page = Demo-Post '/admin/teams/create' $team $admin
    $teamIds += Demo-Id $page $team.Name '/admin/teams/(\d+)/edit'
}
foreach ($project in @(
    @{ name = 'Kampüs Robotu'; summary = 'Kampüs içinde rota izleme ve engelden kaçınma üzerine örnek proje.'; status = 'Geliştiriliyor'; teamId = $teamIds[0] },
    @{ name = 'Görsel Algılama'; summary = 'Görüntülerden nesne tespiti ve takip akışını araştıran örnek proje.'; status = 'Planlandı'; teamId = $teamIds[0] },
    @{ name = 'Topluluk Bilgi Panosu'; summary = 'Etkinlik ve duyuruları bir araya getiren örnek web uygulaması.'; status = 'Tamamlandı'; teamId = $teamIds[1] }
)) {
    $null = Invoke-RestMethod "$BaseUrl/api/projects" -Method Post -WebSession $admin -ContentType 'application/json' -Body ($project | ConvertTo-Json)
}
$eventIds = @()
foreach ($event in @(
    @{ title = 'ASP.NET Core Uygulama Atölyesi'; description = "MVC, Identity ve EF Core kavramlarını uygulama üzerinden inceleyeceğiz.`nBu etkinlik gösterim verisidir; gerçek bir duyuru değildir."; startsAt = [DateTime]::UtcNow.AddDays(7).ToString('o'); location = 'Örnek Bilgisayar Laboratuvarı'; capacity = 30 },
    @{ title = 'Robotik Proje Buluşması'; description = 'Takımların çalışmalarını paylaştığı örnek etkinlik. Gösterim verisidir.'; startsAt = [DateTime]::UtcNow.AddDays(14).ToString('o'); location = 'Örnek Toplantı Salonu'; capacity = 20 },
    @{ title = 'Geçmiş Dönem Tanışma Etkinliği'; description = 'Geçmiş etkinlik filtresini denemek için hazırlanmış örnek kayıt.'; startsAt = [DateTime]::UtcNow.AddDays(-7).ToString('o'); location = 'Örnek Kampüs Alanı'; capacity = 50 }
)) {
    $created = Invoke-RestMethod "$BaseUrl/api/events" -Method Post -WebSession $admin -ContentType 'application/json' -Body ($event | ConvertTo-Json)
    $eventIds += [int]$created.id
}
foreach ($announcement in @(
    @{ Title = 'CORE Portal gösterimine hoş geldiniz'; Content = "Bu yerel ortam örnek verilerle çalışır.`nTakımları ve projeleri filtreleyebilir, etkinliklere başvurabilir ve yönetici ekranlarını inceleyebilirsiniz.`nGösterilen kişi ve içerikler gerçek topluluk duyuruları değildir." },
    @{ Title = 'Örnek takım başvuruları açıldı'; Content = 'Profilde başvuru takibini ve yönetici kararlarını denemek için Otonom Sistemler takımını inceleyin. Bu bir gösterim duyurusudur.' }
)) { $null = Demo-Post '/admin/announcements/create' $announcement $admin }
$member = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$null = Demo-Post '/account/register' @{ Email = $MemberEmail; Password = $MemberPassword; ConfirmPassword = $MemberPassword; FullName = 'Örnek Öğrenci'; Department = 'Bilgisayar Mühendisliği' } $member
$null = Demo-Post "/Teams/Apply/$($teamIds[0])" @{ Motivation = 'Robotik ve yazılım çalışmalarına katkı sağlamak için bu örnek takıma katılmak istiyorum.'; Skills = 'C sharp, temel PostgreSQL ve ekip çalışması' } $member
$null = Demo-Post "/Events/Register/$($eventIds[0])" @{} $member "/Events/Details/$($eventIds[0])"
$applications = Demo-Get '/admin/applications' $admin
$applicationId = [regex]::Match($applications.Content, '/admin/applications/teams/(\d+)/status').Groups[1].Value
if (!$applicationId) { throw 'Örnek takım başvurusu bulunamadı.' }
$null = Demo-Post "/admin/applications/teams/$applicationId/status" @{ status = 'Approved' } $admin '/admin/applications'
$profile = Demo-Get '/profile' $member
if (!$profile.Content.Contains('Otonom Sistemler')) { throw 'Örnek profil hazırlanamadı.' }
Write-Output 'Örnek içerikler hazır: 2 takım, 3 proje, 3 etkinlik, 2 duyuru; öğrenci profilinde 2 başvuru.'
