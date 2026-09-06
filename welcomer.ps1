# Sigma Welcomer - polls guild members, greets newcomers in #welcome and grants the Chadling role
# Runs on GitHub Actions every 2 minutes. Config comes from environment variables.
param([switch]$InitOnly, [switch]$TestWelcome)
$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$token = $env:DISCORD_TOKEN
$guildId = $env:GUILD_ID
$welcomeChannelId = $env:WELCOME_CHANNEL_ID
$botId = $env:BOT_ID
$testUserId = $env:TEST_USER_ID
$guildName = $env:GUILD_NAME
$chadlingRoleId = $env:CHADLING_ROLE_ID
$statePath = Join-Path $dir 'state-welcomer.json'
$state = if (Test-Path $statePath) { Get-Content $statePath -Raw | ConvertFrom-Json } else { [PSCustomObject]@{ known = @() } }
$H = @{ Authorization = "Bot $token"; 'User-Agent' = 'DiscordBot (https://example.com, 1.0)'; Accept = 'application/json' }
$base = 'https://discord.com/api/v10'

function Get-Unix([string]$iso) { ([DateTimeOffset]::Parse($iso)).ToUnixTimeSeconds() }
function SnowToUnix([string]$id) { $ms = ([long]$id -shr 22) + 1420070400000L; ([DateTimeOffset]::FromUnixTimeMilliseconds($ms)).ToUnixTimeSeconds() }
function AvatarUrl($u) {
    if ($u.avatar) { return "https://cdn.discordapp.com/avatars/$($u.id)/$($u.avatar).png?size=256" }
    if ($u.discriminator -and $u.discriminator -ne '0') { $i = [int]$u.discriminator % 5 } else { $i = ([long]$u.id -shr 22) % 6 }
    "https://cdn.discordapp.com/embed/avatars/$i.png"
}
function DisplayName($u) { if ($u.global_name) { $u.global_name } else { $u.username } }

function Grant-Chadling([string]$userId) {
    if (-not $chadlingRoleId) { return }
    Invoke-RestMethod -Method Put -Uri "$base/guilds/$guildId/members/$userId/roles/$chadlingRoleId" -Headers $H | Out-Null
}

function Send-Welcome($m) {
    $name = DisplayName $m.user
    $av = AvatarUrl $m.user
    $srv = Get-Unix $m.joined_at
    $acct = SnowToUnix $m.user.id
    $extra = if ($chadlingRoleId) { ' You got the **Chadling** role 🎉' } else { '' }
    $body = @{
        content = "Welcome to the server, <@$($m.user.id)>!$extra"
        embeds  = @(@{
            author    = @{ name = $name; icon_url = $av }
            thumbnail = @{ url = $av }
            color     = 15844367
            fields    = @(
                @{ name = '👤 Username'; value = $name; inline = $true },
                @{ name = '🏠 Joined Server'; value = "<t:$($srv):F>`n(<t:$($srv):R>)"; inline = $true },
                @{ name = '🪐 Discord Since'; value = "<t:$($acct):F>`n(<t:$($acct):R>)"; inline = $true }
            )
            footer    = @{ text = $guildName }
        })
    } | ConvertTo-Json -Depth 6
    Invoke-RestMethod -Method Post -Uri "$base/channels/$welcomeChannelId/messages" -Headers $H -ContentType 'application/json' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
}

if ($TestWelcome) {
    $m = Invoke-RestMethod -Uri "$base/guilds/$guildId/members/$testUserId" -Headers $H
    Send-Welcome $m
    Grant-Chadling $m.user.id
    Write-Output 'TEST WELCOME SENT'
    exit
}

$members = @(Invoke-RestMethod -Uri "$base/guilds/$guildId/members?limit=1000" -Headers $H)

if ($InitOnly) {
    $state.known = @($members | ForEach-Object { $_.user.id })
    $state | ConvertTo-Json | Set-Content $statePath -Encoding UTF8
    Write-Output "INIT: marked $($state.known.Count) existing members as known (nothing sent)"
    exit
}

$new = @($members | Where-Object { $state.known -notcontains $_.user.id -and $_.user.id -ne $botId -and -not $_.user.bot })
foreach ($m in $new) {
    Send-Welcome $m
    try { Grant-Chadling $m.user.id } catch { Write-Output "WARN: Chadling grant failed for $($m.user.id): $($_.Exception.Message)" }
    Start-Sleep -Milliseconds 500
    Write-Output "WELCOMED: $($m.user.username)"
}
if ($new.Count -gt 0) {
    $state.known = @(@($state.known) + @($new | ForEach-Object { $_.user.id })) | Select-Object -Last 500
    $state | ConvertTo-Json | Set-Content $statePath -Encoding UTF8
}
Write-Output "check done: $($new.Count) new"
