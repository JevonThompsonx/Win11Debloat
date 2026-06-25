function Remove-AppLeftovers {
    param(
        [string]$AppId,
        [string]$FriendlyName
    )

    # Known-app cleanup map: keyed by substring match against AppId
    $cleanupMap = @{
        'OneDrive' = @{
            Registry = @('HKCU:\Software\Microsoft\OneDrive')
            Folders  = @(
                (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive'),
                (Join-Path $env:ProgramData  'Microsoft OneDrive')
            )
            RunKeys  = @('OneDrive', 'OneDriveSetup')
        }
        'MicrosoftTeams' = @{
            Registry = @('HKCU:\Software\Microsoft\Teams')
            Folders  = @(
                (Join-Path $env:APPDATA      'Microsoft\Teams'),
                (Join-Path $env:LOCALAPPDATA 'Microsoft\Teams')
            )
            RunKeys  = @()
        }
        'MSTeams' = @{
            Registry = @('HKCU:\Software\Microsoft\Teams')
            Folders  = @(
                (Join-Path $env:APPDATA      'Microsoft\Teams'),
                (Join-Path $env:LOCALAPPDATA 'Microsoft\Teams')
            )
            RunKeys  = @()
        }
        'Copilot' = @{
            Registry = @('HKCU:\Software\Microsoft\Windows\Shell\Copilot')
            Folders  = @()
            RunKeys  = @()
        }
        'McAfee' = @{
            Registry = @('HKLM:\SOFTWARE\McAfee', 'HKCU:\Software\McAfee')
            Folders  = @(
                (Join-Path $env:ProgramData  'McAfee'),
                (Join-Path $env:ProgramFiles 'McAfee'),
                (Join-Path ${env:ProgramFiles(x86)} 'McAfee')
            )
            RunKeys  = @('McAfee')
        }
        'NortonLifeLock' = @{
            Registry = @('HKLM:\SOFTWARE\Norton', 'HKLM:\SOFTWARE\Symantec', 'HKCU:\Software\Symantec')
            Folders  = @(
                (Join-Path $env:ProgramData  'Norton'),
                (Join-Path $env:ProgramData  'Symantec'),
                (Join-Path $env:ProgramFiles 'Norton Security')
            )
            RunKeys  = @()
        }
        'AD2F1837.HP' = @{
            Registry = @('HKLM:\SOFTWARE\HP', 'HKCU:\Software\HP')
            Folders  = @(
                (Join-Path $env:ProgramData  'HP'),
                (Join-Path $env:LOCALAPPDATA 'HP')
            )
            RunKeys  = @()
        }
        'DellInc.Dell' = @{
            Registry = @()
            Folders  = @(
                (Join-Path $env:ProgramData 'Dell\SARemediation')
            )
            RunKeys  = @()
        }
    }

    foreach ($key in $cleanupMap.Keys) {
        if ($AppId -notlike "*$key*") { continue }

        $map = $cleanupMap[$key]

        foreach ($regPath in $map.Registry) {
            if (Test-Path $regPath) {
                try {
                    Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
                    Write-Verbose "Removed registry key: $regPath"
                }
                catch { Write-Verbose "Could not remove registry key $regPath : $_" }
            }
        }

        foreach ($folder in $map.Folders) {
            if ([string]::IsNullOrWhiteSpace($folder)) { continue }
            if (Test-Path $folder) {
                try {
                    Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
                    Write-Verbose "Removed folder: $folder"
                }
                catch { Write-Verbose "Could not remove folder $folder : $_" }
            }
        }

        $runKeyPaths = @(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
        )
        foreach ($runName in $map.RunKeys) {
            foreach ($runPath in $runKeyPaths) {
                try {
                    if ((Get-ItemProperty -Path $runPath -ErrorAction SilentlyContinue).$runName) {
                        Remove-ItemProperty -Path $runPath -Name $runName -Force -ErrorAction Stop
                        Write-Verbose "Removed startup entry: $runName from $runPath"
                    }
                }
                catch { Write-Verbose "Could not remove startup entry $runName from $runPath : $_" }
            }
        }
    }
}


function Invoke-GenericLeftoverScan {
    param([string[]]$RemovedAppNames)

    if (-not $RemovedAppNames -or $RemovedAppNames.Count -eq 0) { return }

    Write-Host ""

    # 1. Orphaned Uninstall registry keys
    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($uPath in $uninstallPaths) {
        if (-not (Test-Path $uPath)) { continue }
        Get-ChildItem -Path $uPath -ErrorAction SilentlyContinue | ForEach-Object {
            $displayName = (Get-ItemProperty -Path $_.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
            if ($null -eq $displayName) { return }
            foreach ($appName in $RemovedAppNames) {
                if ($displayName -like "*$appName*") {
                    try {
                        Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction Stop
                        Write-Host "  Removed orphaned uninstall key: $displayName" -ForegroundColor DarkGray
                    }
                    catch { Write-Verbose "Could not remove uninstall key for $displayName : $_" }
                    break
                }
            }
        }
    }

    # 2. AppData leftover folders
    $scanRoots = @($env:APPDATA, $env:LOCALAPPDATA, $env:ProgramData) | Where-Object { $_ }
    foreach ($root in $scanRoots) {
        foreach ($appName in $RemovedAppNames) {
            $candidate = Join-Path $root $appName
            if (Test-Path $candidate -PathType Container) {
                try {
                    Remove-Item -Path $candidate -Recurse -Force -ErrorAction Stop
                    Write-Host "  Removed leftover folder: $candidate" -ForegroundColor DarkGray
                }
                catch { Write-Verbose "Could not remove folder $candidate : $_" }
            }
        }
    }

    # 3. Scheduled tasks matching removed app names
    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
        foreach ($task in $tasks) {
            foreach ($appName in $RemovedAppNames) {
                if ($task.TaskName -like "*$appName*" -or $task.TaskPath -like "*$appName*") {
                    try {
                        Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
                        Write-Host "  Removed scheduled task: $($task.TaskName)" -ForegroundColor DarkGray
                    }
                    catch { Write-Verbose "Could not remove scheduled task $($task.TaskName) : $_" }
                    break
                }
            }
        }
    }
    catch { Write-Verbose "Scheduled task scan failed: $_" }

    # 4. Startup Run/RunOnce entries
    $runPaths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    )
    foreach ($runPath in $runPaths) {
        if (-not (Test-Path $runPath)) { continue }
        $props = Get-ItemProperty -Path $runPath -ErrorAction SilentlyContinue
        if ($null -eq $props) { continue }
        foreach ($propName in ($props.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' -and $_.Name -notmatch '^PS' } | Select-Object -ExpandProperty Name)) {
            foreach ($appName in $RemovedAppNames) {
                if ($propName -like "*$appName*" -or $props.$propName -like "*$appName*") {
                    try {
                        Remove-ItemProperty -Path $runPath -Name $propName -Force -ErrorAction Stop
                        Write-Host "  Removed startup entry: $propName" -ForegroundColor DarkGray
                    }
                    catch { Write-Verbose "Could not remove startup entry $propName : $_" }
                    break
                }
            }
        }
    }

    Write-Host "  Leftover cleanup complete." -ForegroundColor Green
}


function Invoke-RemovalVerification {
    param([string[]]$AppIds)

    if (-not $AppIds -or $AppIds.Count -eq 0) { return }

    Write-Host ""
    Write-Host "> Verifying removals..." -ForegroundColor Cyan

    $stillPresent = [System.Collections.Generic.List[string]]::new()
    $confirmed    = [System.Collections.Generic.List[string]]::new()

    # Build installed Appx list once (faster than per-app calls)
    $installedAppx = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue

    foreach ($id in $AppIds) {
        $found = $false

        $match = $installedAppx | Where-Object { $_.Name -eq $id }
        if ($match) { $found = $true }

        # OneDrive Win32 fallback check
        if (-not $found -and $id -eq 'Microsoft.OneDrive') {
            $odPath = Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\OneDrive.exe'
            if (Test-Path $odPath) { $found = $true }
        }

        if ($found) { $stillPresent.Add($id) } else { $confirmed.Add($id) }
    }

    Write-Host "  Confirmed removed : $($confirmed.Count)" -ForegroundColor Green

    if ($stillPresent.Count -gt 0) {
        Write-Host "  Still present     : $($stillPresent.Count)" -ForegroundColor Yellow
        foreach ($id in $stillPresent) {
            Write-Host "    - $id" -ForegroundColor Yellow
        }
    }
}
