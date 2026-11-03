param(
    [string]$BaseUrl = 'http://127.0.0.1:5088',
    [Parameter(Mandatory)] [string]$AdminEmail,
    [Parameter(Mandatory)] [string]$AdminPassword
)

$ErrorActionPreference = 'Stop'

function Get-Token($page) {
    $match = [regex]::Match($page.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"')
    if (!$match.Success) { throw 'Antiforgery token bulunamadı.' }
    return $match.Groups[1].Value
}

function Post-Form($session, $path, $body) {
    $page = Invoke-WebRequest "$BaseUrl$path" -WebSession $session
    $body['__RequestVerificationToken'] = Get-Token $page
    return Invoke-WebRequest "$BaseUrl$path" -WebSession $session -Method Post -Body $body
}

$admin = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$login = Post-Form $admin '/account/login' @{
    Email = $AdminEmail; Password = $AdminPassword; RememberMe = 'false'
}
if ($login.StatusCode -ne 200) { throw 'Admin girişi başarısız.' }
$dashboard = Invoke-WebRequest "$BaseUrl/admin" -WebSession $admin
if (!$dashboard.Content.Contains('Yönetim')) { throw 'Admin paneli açılmadı.' }

$suffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
$teamName = "Smoke Team $suffix"
$teamResult = Post-Form $admin '/admin/teams/create' @{
    Name = $teamName; Field = 'Robotics'; FoundedYear = '2026'; Description = 'Smoke test team.'
}
if (!$teamResult.Content.Contains($teamName)) { throw 'Takım oluşturulamadı.' }
$teamId = [regex]::Match($teamResult.Content, '/admin/teams/(\d+)/edit').Groups[1].Value
if (!$teamId) { throw 'Takım ID bulunamadı.' }

$projectName = "Smoke Project $suffix"
$projectResult = Post-Form $admin '/admin/projects/create' @{
    Name = $projectName; TeamId = $teamId; Summary = 'Smoke test project.'; Status = 'Active'
}
if (!$projectResult.Content.Contains($projectName)) { throw 'Proje oluşturulamadı.' }

$member = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$email = "smoke-$suffix@example.test"
$register = Post-Form $member '/account/register' @{
    Email = $email; Password = 'SmokeTest!234'; ConfirmPassword = 'SmokeTest!234'; FullName = 'Smoke User'; Department = 'Engineering'
}
if (!$register.Content.Contains('Smoke User') -and !$register.Content.Contains($email)) { throw 'Üye kaydı başarısız.' }
$application = Post-Form $member "/teams/apply/$teamId" @{
    Motivation = 'I would like to help this team with its research projects.'; Skills = 'C sharp and PostgreSQL'
}
if (!([System.Net.WebUtility]::HtmlDecode($application.Content).Contains('başvurunuz alındı'))) {
    throw 'Takım başvurusu alınmadı.'
}

$projectsApi = Invoke-RestMethod "$BaseUrl/api/projects"
if (!($projectsApi | Where-Object name -eq $projectName)) { throw 'Proje API kaydı göstermedi.' }

$eventJson = @{
    title = "Smoke Event $suffix"
    description = 'Test event for registration capacity.'
    startsAt = [DateTime]::UtcNow.AddDays(2).ToString('o')
    location = 'Campus'
    capacity = 1
} | ConvertTo-Json
$anonymousWrite = Invoke-WebRequest "$BaseUrl/api/events" -Method Post -ContentType 'application/json' -Body $eventJson -SkipHttpErrorCheck
if ($anonymousWrite.StatusCode -ne 401) { throw "Anonim API yazma koruması başarısız: $($anonymousWrite.StatusCode)" }
$memberWrite = Invoke-WebRequest "$BaseUrl/api/events" -WebSession $member -Method Post -ContentType 'application/json' -Body $eventJson -SkipHttpErrorCheck
if ($memberWrite.StatusCode -ne 403) { throw "Üye API yazma koruması başarısız: $($memberWrite.StatusCode)" }
$createdEvent = Invoke-RestMethod "$BaseUrl/api/events" -WebSession $admin -Method Post -ContentType 'application/json' -Body $eventJson
$eventId = $createdEvent.id
if (!$eventId) { throw 'Admin etkinlik API kaydı oluşturamadı.' }
$eventPage = Invoke-WebRequest "$BaseUrl/events/details/$eventId" -WebSession $member
$eventTokens = [regex]::Matches($eventPage.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"')
if ($eventTokens.Count -eq 0) { throw 'Etkinlik formunda antiforgery token yok.' }
$eventApplication = Invoke-WebRequest "$BaseUrl/events/register/$eventId" -WebSession $member -Method Post -Form @{__RequestVerificationToken = $eventTokens[$eventTokens.Count - 1].Groups[1].Value} -SkipHttpErrorCheck
if ($eventApplication.StatusCode -ne 200) { throw "Etkinlik başvurusu HTTP $($eventApplication.StatusCode): $($eventApplication.RawContent)" }
if (!$eventApplication.Content.Contains('1 / 1')) { throw 'Etkinlik başvurusu veya kontenjan sayımı başarısız.' }

$eventUpdate = $eventJson | ConvertFrom-Json -AsHashtable
$eventUpdate.capacity = 2
Invoke-WebRequest "$BaseUrl/api/events/$eventId" -WebSession $admin -Method Put -ContentType 'application/json' -Body ($eventUpdate | ConvertTo-Json) | Out-Null
if ((Invoke-RestMethod "$BaseUrl/api/events/$eventId").capacity -ne 2) { throw 'Event API PUT başarısız.' }
Invoke-WebRequest "$BaseUrl/api/events/$eventId" -WebSession $admin -Method Delete | Out-Null
if ((Invoke-WebRequest "$BaseUrl/api/events/$eventId" -SkipHttpErrorCheck).StatusCode -ne 404) { throw 'Event API DELETE başarısız.' }

$apiProject = @{
    name = "API Project $suffix"; summary = 'API lifecycle test project.'; status = 'Active'; teamId = [int]$teamId
} | ConvertTo-Json
$createdProject = Invoke-RestMethod "$BaseUrl/api/projects" -WebSession $admin -Method Post -ContentType 'application/json' -Body $apiProject
if (!$createdProject.id) { throw 'Project API POST başarısız.' }
$projectUpdate = $apiProject | ConvertFrom-Json -AsHashtable
$projectUpdate.status = 'Complete'
Invoke-WebRequest "$BaseUrl/api/projects/$($createdProject.id)" -WebSession $admin -Method Put -ContentType 'application/json' -Body ($projectUpdate | ConvertTo-Json) | Out-Null
if ((Invoke-RestMethod "$BaseUrl/api/projects/$($createdProject.id)").status -ne 'Complete') { throw 'Project API PUT başarısız.' }
Invoke-WebRequest "$BaseUrl/api/projects/$($createdProject.id)" -WebSession $admin -Method Delete | Out-Null
if ((Invoke-WebRequest "$BaseUrl/api/projects/$($createdProject.id)" -SkipHttpErrorCheck).StatusCode -ne 404) { throw 'Project API DELETE başarısız.' }

Write-Output "PASS admin login, team and project create, member registration, team and event applications, capacity, API authorization and CRUD ($suffix)"
