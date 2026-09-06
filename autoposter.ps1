# Sigma AutoPoster - checks a YouTube RSS feed and posts new videos to Discord
# Runs on GitHub Actions every 5 minutes. Config comes from environment variables.
param([switch]$InitOnly, [switch]$TestPost)
$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$token = $env:DISCORD_TOKEN
$feedUrl = $env:YT_FEED_URL
$postChannelId = $env:POST_CHANNEL_ID
$roleId = $env:ROLE_ID
$channelName = $env:CHANNEL_NAME
$channelUrl = $env:CHANNEL_URL
$statePath = Join-Path $dir 'state-autoposter.json'
$state = if (Test-Path $statePath) { Get-Content $statePath -Raw | ConvertFrom-Json } else { [PSCustomObject]@{ seen = @() } }
$H = @{ Authorization = "Bot $token"; 'User-Agent' = 'DiscordBot (https://example.com, 1.0)'; Accept = 'application/json' }

function Send-Video([string]$vid, [string]$title, [string]$pub) {
    $body = @{
        content = "<@&$roleId> :clapper: **New video just dropped!**"
        embeds  = @(@{
            title     = $title
            url       = "https://www.youtube.com/watch?v=$vid"
            color     = 15844367
            timestamp = $pub
            author    = @{ name = $channelName; url = $channelUrl }
            thumbnail = @{ url = "https://i.ytimg.com/vi/$vid/hqdefault.jpg" }
            footer    = @{ text = $channelName }
        })
    } | ConvertTo-Json -Depth 6
    Invoke-RestMethod -Method Post -Uri "https://discord.com/api/v10/channels/$postChannelId/messages" -Headers $H -ContentType 'application/json' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
}

function Get-Feed {
    $raw = (Invoke-WebRequest -Uri $feedUrl -Headers @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } -UseBasicParsing -TimeoutSec 25).Content
    [regex]::Matches($raw, '<entry>.*?</entry>', 'Singleline') | ForEach-Object {
        [PSCustomObject]@{
            vid   = [regex]::Match($_.Value, '<yt:videoId>([^<]+)').Groups[1].Value
            title = [System.Net.WebUtility]::HtmlDecode([regex]::Match($_.Value, '<title>([^<]+)').Groups[1].Value)
            pub   = [regex]::Match($_.Value, '<published>([^<]+)').Groups[1].Value
        }
    }
}

if ($TestPost) {
    Send-Video 'dQw4w9WgXcQ' '[TEST] This is what a video announcement will look like' (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    Write-Output 'TEST POST SENT'
    exit
}

$videos = @(Get-Feed)
if (-not $videos) { Write-Output 'WARN: feed returned no entries'; exit }

if ($InitOnly) {
    $state.seen = @($videos | ForEach-Object { $_.vid })
    $state | ConvertTo-Json | Set-Content $statePath -Encoding UTF8
    Write-Output "INIT: marked $($state.seen.Count) existing videos as seen (nothing posted)"
    exit
}

$new = @($videos | Where-Object { $state.seen -notcontains $_.vid })
foreach ($v in $new) {
    Send-Video $v.vid $v.title $v.pub
    Start-Sleep -Milliseconds 700
    Write-Output "POSTED: $($v.vid) - $($v.title)"
}
if ($new.Count -gt 0) {
    $state.seen = @(@($state.seen) + @($new | ForEach-Object { $_.vid })) | Select-Object -Last 100
    $state | ConvertTo-Json | Set-Content $statePath -Encoding UTF8
}
Write-Output "check done: $($new.Count) new"
