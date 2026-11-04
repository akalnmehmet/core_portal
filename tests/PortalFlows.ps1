param(
    [string]$BaseUrl = 'http://localhost:5201',
    [Parameter(Mandatory)] [string]$AdminEmail,
    [Parameter(Mandatory)] [string]$AdminPassword
)
$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
$suffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
function Assert($condition, $message) { if (!$condition) { throw $message } }
function Read-Page($path, $session) {
    $p = Invoke-WebRequest "$BaseUrl$path" -WebSession $session -SkipHttpErrorCheck
    Assert ($p.StatusCode -eq 200) "GET $path returned $($p.StatusCode)"
    return $p
}
function Send-Form($path, $body, $session, $tokenPath = $path) {
    $page = Read-Page $tokenPath $session
    $token = [regex]::Match($page.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
    Assert (![string]::IsNullOrEmpty($token)) "Missing token at $tokenPath"
    $body['__RequestVerificationToken'] = $token
    return Invoke-WebRequest "$BaseUrl$path" -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded' -WebSession $session -SkipHttpErrorCheck
}
function Row-Id($page, $name, $pattern) {
    $row = [regex]::Matches($page.Content, '(?s)<tr>.*?</tr>') | Where-Object { $_.Value.Contains($name) } | Select-Object -First 1
    Assert ($null -ne $row) "Row not found: $name"
    $id = [regex]::Match($row.Value, $pattern).Groups[1].Value
    Assert (![string]::IsNullOrEmpty($id)) "ID not found: $name"
    return $id
}
function Register-Member($label) {
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $result = Send-Form '/account/register' @{
        Email = "flow-$label-$suffix@example.test"; Password = 'FlowTest!23456'; ConfirmPassword = 'FlowTest!23456'
        FullName = "Flow $label $suffix"; Department = 'Engineering'
    } $session
    Assert ($result.StatusCode -eq 200) 'Member registration failed'
    return $session
}
$admin = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$login = Send-Form '/account/login' @{ Email = $AdminEmail; Password = $AdminPassword } $admin
Assert ($login.StatusCode -eq 200) 'Admin login failed'
$null = Read-Page '/admin' $admin
$member = Register-Member 'one'
$other = Register-Member 'two'

# New routes must render, including their forms, without requiring a populated database.
foreach ($path in @('/', '/Home/About', '/Announcements', '/Teams', '/Projects', '/Events')) { $null = Read-Page $path $member }
foreach ($path in @('/admin/events', '/admin/events/create', '/admin/announcements', '/admin/announcements/create', '/admin/applications')) { $null = Read-Page $path $admin }

# Content CRUD, validation and HTML encoding.
$title = "Flow Announcement $suffix"
$created = Send-Form '/admin/announcements/create' @{ Title = $title; Content = '<script>alert(1)</script> Plain text content.' } $admin
Assert ($created.StatusCode -eq 200) 'Announcement create failed'
$announcementId = Row-Id $created $title '/admin/announcements/(\d+)/edit'
$public = Read-Page "/Announcements/Details/$announcementId" $member
Assert ($public.Content.Contains('&lt;script&gt;')) 'Announcement content was not encoded'
Assert (!( $public.Content.Contains('<script>alert(1)</script>'))) 'Executable announcement HTML'
$homePage = Read-Page '/' $member
Assert ($homePage.Content.Contains($title)) 'Home did not show announcement'
$updatedTitle = "$title Updated"
$edited = Send-Form "/admin/announcements/$announcementId/edit" @{ Title = $updatedTitle; Content = 'Updated announcement.' } $admin
Assert ($edited.StatusCode -eq 200 -and $edited.Content.Contains($updatedTitle)) 'Announcement edit failed'
$search = Read-Page "/Announcements?q=$suffix" $member
Assert ($search.Content.Contains($updatedTitle)) 'Announcement search failed'
$invalid = Send-Form '/admin/announcements/create' @{ Title = ''; Content = 'Invalid' } $admin
Assert ($invalid.Content.Contains('validation-summary-errors')) 'Announcement validation missing'

# Admin event form uses local time; record UTC conversion through the API.
$eventTitle = "Flow Event $suffix"
$localDate = (Get-Date).AddDays(3).ToString('yyyy-MM-ddTHH:mm')
$eventBody = @{ Title = $eventTitle; Description = 'Event managed through MVC.'; StartsAtLocal = $localDate; Location = 'Flow Campus'; Capacity = '1' }
$createdEvent = Send-Form '/admin/events/create' $eventBody $admin
Assert ($createdEvent.StatusCode -eq 200) 'Event create failed'
$eventId = Row-Id $createdEvent $eventTitle '/admin/events/(\d+)/edit'
$apiEvent = Invoke-RestMethod "$BaseUrl/api/events/$eventId"
$expectedUtc = [DateTime]::SpecifyKind([DateTime]::ParseExact($localDate, 'yyyy-MM-ddTHH:mm', $null), [DateTimeKind]::Local).ToUniversalTime()
Assert (([DateTime]$apiEvent.startsAt).ToUniversalTime() -eq $expectedUtc) 'Local to UTC conversion mismatch'
$invalidEvent = Send-Form '/admin/events/create' @{ Title = 'Invalid'; Description = 'Missing date'; Location = 'Campus'; Capacity = '0' } $admin
Assert ($invalidEvent.Content.Contains('validation-summary-errors')) 'Event validation missing'

# Team and project filters are combined, not applied independently.
$teamName = "Flow Team $suffix"
$teamCreated = Send-Form '/admin/teams/create' @{ Name = $teamName; Field = "FlowField$suffix"; FoundedYear = '2026'; Description = 'Research team.' } $admin
$teamId = Row-Id $teamCreated $teamName '/admin/teams/(\d+)/edit'
$projectName = "Flow Project $suffix"
$null = Send-Form '/admin/projects/create' @{ Name = $projectName; Summary = 'Searchable project'; Status = "FlowStatus$suffix"; TeamId = $teamId } $admin
$filtered = Read-Page "/Projects?q=$suffix&teamId=$teamId&status=FlowStatus$suffix" $member
Assert ($filtered.Content.Contains($projectName)) 'Combined project filter failed'
$filtered = Read-Page "/Projects?q=$suffix&teamId=$teamId&status=not-existing" $member
Assert (!$filtered.Content.Contains($projectName)) 'Project status filter ignored'
$filtered = Read-Page "/Teams?q=$suffix&field=FlowField$suffix" $member
Assert ($filtered.Content.Contains($teamName)) 'Team filter failed'
$filtered = Read-Page "/Teams?q=$suffix&field=not-existing" $member
Assert (!$filtered.Content.Contains($teamName)) 'Team field filter ignored'
$filtered = Read-Page "/Events?q=$suffix&period=upcoming" $member
Assert ($filtered.Content.Contains($eventTitle)) 'Upcoming event filter failed'
$filtered = Read-Page "/Events?q=$suffix&period=past" $member
Assert (!$filtered.Content.Contains($eventTitle)) 'Past event filter ignored'

# Profile editing and ownership. Forged identity/role fields must have no effect.
$null = Send-Form '/profile' @{ 'Form.FullName' = "Updated Flow $suffix"; 'Form.Department' = 'Computer Engineering'; UserId = 'forged'; Role = 'Admin' } $member
$profile = Read-Page '/profile' $member
Assert ($profile.Content.Contains("Updated Flow $suffix")) 'Profile update failed'
$otherProfile = Read-Page '/profile' $other
Assert (!$otherProfile.Content.Contains("Updated Flow $suffix")) 'Profile leaked another user'
$invalidProfile = Send-Form '/profile' @{ 'Form.FullName' = ''; 'Form.Department' = 'Invalid' } $member
Assert ($invalidProfile.Content.Contains('validation-summary-errors')) 'Profile validation missing'

# Applications and administrator decisions.
$null = Send-Form "/Teams/Apply/$teamId" @{ Motivation = 'I want to contribute to this research team.'; Skills = 'C sharp and testing' } $member
$null = Send-Form "/Events/Register/$eventId" @{} $member "/Events/Details/$eventId"
$applications = Read-Page '/admin/applications' $admin
$eventApplicationId = Row-Id $applications "flow-one-$suffix@example.test" '/admin/applications/events/(\d+)/status'
$teamCard = [regex]::Matches($applications.Content, '(?s)<article.*?</article>') | Where-Object { $_.Value.Contains($teamName) } | Select-Object -First 1
$teamForm = [regex]::Match($teamCard.Value, '(?s)<form[^>]*action="/admin/applications/teams/(\d+)/status"')
$teamApplicationId = $teamForm.Groups[1].Value
Assert (![string]::IsNullOrEmpty($teamApplicationId)) 'Team application decision form missing'
foreach ($kind in @('events', 'teams')) {
    $id = if ($kind -eq 'events') { $eventApplicationId } else { $teamApplicationId }
    $decision = Send-Form "/admin/applications/$kind/$id/status" @{ status = 'Approved' } $admin '/admin/applications'
    Assert ($decision.StatusCode -eq 200) "Approval failed: $kind"
}
$profile = Read-Page '/profile' $member
$decodedProfile = [System.Net.WebUtility]::HtmlDecode($profile.Content)
Assert ([regex]::Matches($decodedProfile, 'Onaylandı').Count -eq 2) 'Approved decisions did not reach profile'
$otherProfile = Read-Page '/profile' $other
Assert (!$otherProfile.Content.Contains($eventTitle) -and !$otherProfile.Content.Contains($teamName)) 'Applications leaked across profiles'
$filtered = Read-Page '/admin/applications?status=Rejected' $admin
Assert (!$filtered.Content.Contains($eventTitle)) 'Application status filter ignored'

# A rejected application frees a place; re-approval must not overflow a full event.
$null = Send-Form "/admin/applications/events/$eventApplicationId/status" @{ status = 'Rejected' } $admin '/admin/applications'
$null = Send-Form "/Events/Register/$eventId" @{} $other "/Events/Details/$eventId"
$blocked = Send-Form "/admin/applications/events/$eventApplicationId/status" @{ status = 'Approved' } $admin '/admin/applications'
Assert ([System.Net.WebUtility]::HtmlDecode($blocked.Content).Contains('Etkinlik dolu')) 'Re-approval bypassed capacity'
$profile = Read-Page '/profile' $member
Assert ([System.Net.WebUtility]::HtmlDecode($profile.Content).Contains('Reddedildi')) 'Rejected state was lost'
$eventBody.Capacity = '2'
$null = Send-Form "/admin/events/$eventId/edit" $eventBody $admin
$null = Send-Form "/admin/applications/events/$eventApplicationId/status" @{ status = 'Approved' } $admin '/admin/applications'
$eventBody.Capacity = '1'
$blockedEdit = Send-Form "/admin/events/$eventId/edit" $eventBody $admin
Assert ($blockedEdit.Content.Contains('validation-summary-errors')) 'MVC capacity reduction bypassed active applications'
$apiEvent = Invoke-RestMethod "$BaseUrl/api/events/$eventId"
Assert ($apiEvent.capacity -eq 2) 'Invalid capacity update changed data'
$apiBody = @{ title = $eventTitle; description = 'API capacity guard'; startsAt = $expectedUtc.ToString('o'); location = 'Campus'; capacity = 1 } | ConvertTo-Json
$apiBlocked = Invoke-WebRequest "$BaseUrl/api/events/$eventId" -WebSession $admin -Method Put -ContentType 'application/json' -Body $apiBody -SkipHttpErrorCheck
Assert ($apiBlocked.StatusCode -eq 409) 'API capacity reduction bypassed active applications'

# Role, antiforgery and enum boundaries.
foreach ($path in @('/admin/events', '/admin/announcements', '/admin/applications')) {
    $forbidden = Invoke-WebRequest "$BaseUrl$path" -WebSession $member -SkipHttpErrorCheck
    Assert ($forbidden.StatusCode -eq 403) "Member entered $path"
}
$forbiddenWrite = Send-Form '/admin/announcements/create' @{ Title = 'Unauthorized'; Content = 'Unauthorized' } $member '/profile'
Assert ($forbiddenWrite.StatusCode -eq 403) 'Member wrote admin content'
$noToken = Invoke-WebRequest "$BaseUrl/admin/applications/events/$eventApplicationId/status" -WebSession $admin -Method Post -Body @{ status = 'Rejected' } -SkipHttpErrorCheck
Assert ($noToken.StatusCode -eq 400) 'Missing antiforgery token accepted'
foreach ($bad in @(@{ status = '999' }, @{ status = 'nonsense' }, @{})) {
    $invalidStatus = Send-Form "/admin/applications/events/$eventApplicationId/status" $bad $admin '/admin/applications'
    Assert ($invalidStatus.StatusCode -eq 400) 'Invalid application status accepted'
}
$missing = Send-Form '/admin/applications/events/2147483647/status' @{ status = 'Approved' } $admin '/admin/applications'
Assert ($missing.StatusCode -eq 404) "Missing application returned $($missing.StatusCode), expected 404"

# Delete via MVC and verify database changes through public reads.
# Two users competing for the last place must not create two active registrations.
$raceTitle = "Flow Race $suffix"
$raceJson = @{ title = $raceTitle; description = 'Concurrent capacity check'; startsAt = $expectedUtc.ToString('o'); location = 'Campus'; capacity = 1 } | ConvertTo-Json
$race = Invoke-RestMethod "$BaseUrl/api/events" -WebSession $admin -Method Post -ContentType 'application/json' -Body $raceJson
$raceUrl = "$BaseUrl/Events/Register/$($race.id)"
$racers = foreach ($raceSession in @($member, $other)) {
    $page = Read-Page "/Events/Details/$($race.id)" $raceSession
    @{ Session = $raceSession; Token = [regex]::Match($page.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value }
}
$raceCodes = $racers | ForEach-Object -Parallel {
    $response = Invoke-WebRequest $using:raceUrl -WebSession $_.Session -Method Post -Body @{ __RequestVerificationToken = $_.Token } -ContentType 'application/x-www-form-urlencoded' -SkipHttpErrorCheck
    $response.StatusCode
} -ThrottleLimit 2
Assert (@($raceCodes | Where-Object { $_ -ne 200 }).Count -eq 0) 'Concurrent registration returned a server error'
$raceOwners = 0
foreach ($raceSession in @($member, $other)) {
    $p = Read-Page '/profile' $raceSession
    if ($p.Content.Contains($raceTitle)) { $raceOwners++ }
}
Assert ($raceOwners -eq 1) 'Concurrent registration exceeded the last place'
$null = Invoke-WebRequest "$BaseUrl/api/events/$($race.id)" -WebSession $admin -Method Delete

$null = Send-Form "/admin/announcements/$announcementId/delete" @{} $admin '/admin/announcements'
$deleted = Invoke-WebRequest "$BaseUrl/Announcements/Details/$announcementId" -SkipHttpErrorCheck
Assert ($deleted.StatusCode -eq 404) 'Announcement delete failed'
$null = Send-Form "/admin/events/$eventId/delete" @{} $admin '/admin/events'
$deleted = Invoke-WebRequest "$BaseUrl/api/events/$eventId" -SkipHttpErrorCheck
Assert ($deleted.StatusCode -eq 404) 'Event delete failed'
$profile = Read-Page '/profile' $member
Assert (!$profile.Content.Contains($eventTitle)) 'Deleted event remained in profile'
Write-Output "PASS content CRUD, validation, encoding, filters, profile ownership, approvals, capacity, concurrent registration, authorization, antiforgery ($suffix)"
