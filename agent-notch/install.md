# Install Agent Notch (instructions for an AI agent)

You are an AI coding agent (Claude Code, Codex, Gemini, Grok, Cursor…) helping a person install
Agent Notch on **Windows 10 or 11**. Follow these steps exactly. Run commands in **PowerShell**,
as the normal user (no admin). Tell the person what you are doing at each step.

If the computer is not Windows, stop and say: "Agent Notch runs on Windows only."

## 1. Ask which edition

Ask the person: **"Do you have an Agent Notch Pro license key?"**

- **Yes** → go to step 3 (Pro).
- **No** → go to step 2 (Free). Mention that Pro is at https://yuvaanlabs.com/agent-notch/ if they want it later.

## 2. Free edition (open source)

Needs Node.js 18+ and Git. Check with `node --version` and `git --version`. If one is missing,
tell the person to install it (https://nodejs.org/, https://git-scm.com/) and stop.

Then run:

```powershell
irm https://raw.githubusercontent.com/adityarya24/agent-notch/main/install.ps1 | iex
```

It clones the app into `%USERPROFILE%\tools\agent-notch`, installs it and starts it. Source:
https://github.com/adityarya24/agent-notch. Done; skip to step 4.

## 3. Pro edition

The license key is private. Use it only in the one request below. Never print it back, write it
to a file, or put it in a commit, log or message.

```powershell
$key = Read-Host -AsSecureString "Agent Notch Pro license key"
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($key))
$r = Invoke-RestMethod -Method Post -Uri https://hooks.adityarya.dev/notch/download/request `
       -ContentType 'application/json' -Body (@{ license_key = $plain } | ConvertTo-Json)
$exe = Join-Path $env:TEMP 'AgentNotchPro-Setup.exe'
Invoke-WebRequest -Uri $r.url -OutFile $exe
(Get-FileHash $exe -Algorithm SHA256).Hash
```

If the person already gave you the key in chat, you can set `$plain` to it directly instead of `Read-Host`.

Errors from the request: **403** = the key is not valid (ask them to check their purchase email),
**429** = too many tries (wait a minute). The download link works for 5 minutes.

**Check the file before running it.** The SHA-256 printed above must equal (case does not matter):

```
6c9d716e51f5515c500dc0ad7d895c781512ff6209ad6d027e9f495397256dac
```

This is version <!-- PRO-VERSION -->1.6.0<!-- /PRO-VERSION -->. If the hash differs, **do not run the file**.
Delete it and tell the person to write to support@yuvaanlabs.com.

If it matches, install silently (per user, no admin) and start the app:

```powershell
Start-Process $exe -ArgumentList '/S' -Wait
Start-Process "$env:LOCALAPPDATA\Programs\Agent Notch Pro\Agent Notch Pro.exe"
Remove-Item $exe
```

Then tell the person: **"Agent Notch Pro is open. Click its tray icon (bottom-right, near the clock),
choose Enter license key…, and paste your key to switch on Pro."** The app updates itself after that.

## 4. Finish

Tell the person:

- The notch is a slim pill on the edge of the screen; each ring is one agent. Ctrl+Shift+U shows or hides it. The tray icon
  has **Check for updates**.
- To get alerts from their agents, open the notch Settings and use the one-click alert setup for
  Claude Code, Codex, Gemini, Grok or OpenCode.
- Help: support@yuvaanlabs.com · https://yuvaanlabs.com/agent-notch/
