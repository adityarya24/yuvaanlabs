# Hivelane installer for Windows.
#   irm https://yuvaanlabs.com/hivelane/install.ps1 | iex
# Re-run it to update. Your data and licence live in %USERPROFILE%\.hivelane and are kept.

function Install-Hivelane {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar
    $base = if ($env:HIVELANE_DOWNLOAD_BASE) { $env:HIVELANE_DOWNLOAD_BASE } else { 'https://yuvaanlabs.com/hivelane/download' }
    $appDir = if ($env:HIVELANE_APP_DIR) { $env:HIVELANE_APP_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\Hivelane' }

    if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
        throw 'Hivelane needs 64-bit Windows on an x64 (Intel/AMD) processor.'
    }
    $name = 'hivelane-windows-x64'
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("hivelane-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        # The site's CDN can serve an old copy for a few minutes after a release.
        # Fetch the checksums uncached, then ask for the zip by its hash so both
        # come from the same release.
        $sums = (Invoke-WebRequest -UseBasicParsing "$base/SHA256SUMS?t=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())").Content
        if ($sums -is [byte[]]) { $sums = [Text.Encoding]::UTF8.GetString($sums) }
        $line = ($sums -split "`n") | Where-Object { $_ -match "\s\*?$name\.zip\s*$" } | Select-Object -First 1
        if (-not $line) { throw "No checksum published for $name.zip. Nothing was installed." }
        $expected = ($line -split '\s+')[0].ToLower()
        Write-Host "Downloading Hivelane ($name)..."
        $zip = Join-Path $tmp "$name.zip"
        Invoke-WebRequest -UseBasicParsing "$base/$name.zip?sha256=$expected" -OutFile $zip
        $actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
        if ($expected -ne $actual) { throw 'Checksum mismatch: the download is damaged or was changed. Nothing was installed.' }

        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        $new = Join-Path $tmp $name
        & (Join-Path $new 'hivelane.exe') --selftest *> $null
        if ($LASTEXITCODE -ne 0) { throw 'The new build failed its self-test. Nothing was changed.' }

        # Swap in the new version, keeping the old one until the move succeeds.
        # Windows lets us rename the folder of a running hivelane.exe (agents
        # keep their MCP server open), but not delete it: old copies are
        # cleaned up on a later run once nothing uses them.
        Get-ChildItem -Path (Split-Path $appDir) -Filter "$(Split-Path $appDir -Leaf).old-*" -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue }
        $old = "$appDir.old-" + [Guid]::NewGuid().ToString('N').Substring(0, 8)
        New-Item -ItemType Directory -Force -Path (Split-Path $appDir) | Out-Null
        if (Test-Path $appDir) {
            try { Rename-Item -Path $appDir -NewName (Split-Path $old -Leaf) }
            catch { throw 'Could not replace the Hivelane folder (a program is holding it open). Close your agent sessions and run the installer again.' }
        }
        try { Move-Item -Path $new -Destination $appDir }
        catch { if (Test-Path $old) { Rename-Item -Path $old -NewName (Split-Path $appDir -Leaf) }; throw }
        if (Test-Path $old) { Remove-Item -Recurse -Force $old -ErrorAction SilentlyContinue }

        # Command names: hard links to the one binary; it picks the part to run from its own name.
        $exe = Join-Path $appDir 'hivelane.exe'
        foreach ($cmd in 'hivelane-dispatch', 'hivelane-codex-hook', 'hivelane-claude-hook') {
            New-Item -ItemType HardLink -Path (Join-Path $appDir "$cmd.exe") -Target $exe | Out-Null
        }
    }
    finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (($userPath -split ';') -contains $appDir)) {
        [Environment]::SetEnvironmentVariable('Path', ($(if ($userPath) { "$userPath;" } else { '' }) + $appDir), 'User')
        Write-Host "Added $appDir to your PATH (new terminals will see it)."
    }
    if (-not (($env:Path -split ';') -contains $appDir)) { $env:Path = "$env:Path;$appDir" }
    Write-Host "Installed to $appDir"

    if ($env:HIVELANE_SKIP_SETUP -ne '1') {
        Write-Host ''
        Write-Host 'Connecting Hivelane to the agent CLIs on this machine...'
        & (Join-Path $appDir 'hivelane.exe') setup
        if ($LASTEXITCODE -ne 0) { Write-Host "Setup reported a problem. Run 'hivelane doctor' to see what is missing." }
    }
    Write-Host ''
    if ($env:HIVELANE_UPDATING -eq '1') { Write-Host 'Done. Restart your agent sessions to use the new version.' }
    else { Write-Host 'Done. Next: hivelane activate <your-licence-key>' }
}

try { Install-Hivelane } catch { Write-Host "hivelane install: $($_.Exception.Message)" -ForegroundColor Red }
