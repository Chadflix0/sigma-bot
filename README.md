# sigma-bot

24/7 Discord automation for **chadflix's sigma server**, running free on GitHub Actions.

## What it does
- **autoposter.ps1** - checks the YouTube RSS feed of @realchadflix every 5 minutes. New video -> embed with thumbnail in Discord `#new-videos` + ping to the Notification Squad role.
- **welcomer.ps1** - polls the guild member list every 5 minutes. New member -> welcome embed in `#welcome` (avatar, username, server-join date, Discord account age).
- **keepalive.yml** - monthly empty commit so GitHub never auto-disables the schedules (60-day inactivity rule).

## Memory
`state-autoposter.json` / `state-welcomer.json` track seen videos / known members. The workflow commits them back after every run - that is how the bot remembers across runs. Do not delete them.

## Setup
1. Repo secret `DISCORD_TOKEN` = Discord bot token (Settings -> Secrets and variables -> Actions).
2. That's it. Schedules run automatically; you can also trigger manually via Actions -> sigma-bot -> Run workflow.

## Manual test switches
The scripts accept `-TestPost` / `-TestWelcome` (post sample messages) and `-InitOnly` (mark current videos/members as seen without posting).

## Note
The Discord bot will always appear **offline** in the member list - it uses the REST API only and never opens a gateway connection. That is normal and does not affect functionality.
