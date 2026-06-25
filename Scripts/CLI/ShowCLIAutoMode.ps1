function ShowCLIAutoMode {
    # Load apps from Apps.json
    $appsData = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json

    # Build app list with state
    $apps = [System.Collections.Generic.List[hashtable]]::new()
    $index = 0
    foreach ($app in $appsData.Apps) {
        $index++
        $autoDefault = if ($app.PSObject.Properties.Name -contains 'AutoModeDefault') { $app.AutoModeDefault } else { 'remove' }
        $apps.Add(@{
            Index      = $index
            Name       = $app.FriendlyName
            AppId      = $app.AppId
            Rec        = $app.Recommendation
            Default    = $autoDefault
            State      = $autoDefault   # mutable: 'remove', 'skip', 'protected'
            Category   = (Get-AppCategory -AppId ($app.AppId | Select-Object -First 1))
        })
    }

    $unlockProtected = $false

    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "  ===============================================================" -ForegroundColor DarkCyan
        Write-Host "   WIN11 AUTODEBLOAT  -  github.com/JevonThompsonx/Win11Debloat" -ForegroundColor Cyan
        Write-Host "   All REMOVE apps are pre-selected. Type numbers to skip/add." -ForegroundColor Gray
        Write-Host "   'a' = unlock protected apps  |  'q' = quit  |  'c' = CONFIRM" -ForegroundColor Gray
        Write-Host "  ===============================================================" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host ("  {0,3}  {1,-8}  {2,-34} {3}" -f "#", "STATUS", "APP", "CATEGORY") -ForegroundColor DarkGray
        Write-Host ("  {0}  {1}  {2} {3}" -f ("-" * 4), ("-" * 8), ("-" * 34), ("-" * 18)) -ForegroundColor DarkGray

        # Sort: remove first, then keep, then protected
        $sorted = $apps | Sort-Object { switch ($_.State) { 'remove' { 0 } 'skip' { 1 } 'keep' { 2 } 'protected' { 3 } default { 4 } } }, { $_.Category }, { $_.Name }

        foreach ($a in $sorted) {
            $color = switch ($a.State) {
                'remove'    { 'Red' }
                'keep'      { 'Green' }
                'skip'      { 'DarkGray' }
                'protected' { 'DarkRed' }
                default     { 'Gray' }
            }
            $statusLabel = switch ($a.State) {
                'remove'    { '[REMOVE]' }
                'keep'      { '[KEEP  ]' }
                'skip'      { '[SKIP  ]' }
                'protected' { '[LOCK  ]' }
                default     { '[------]' }
            }
            $displayName = if ($a.Name.Length -gt 32) { $a.Name.Substring(0, 29) + "..." } else { $a.Name }
            Write-Host ("  {0,3}  " -f $a.Index) -NoNewline -ForegroundColor DarkGray
            Write-Host ("{0,-8}  " -f $statusLabel) -NoNewline -ForegroundColor $color
            Write-Host ("{0,-34} " -f $displayName) -NoNewline -ForegroundColor White
            Write-Host $a.Category -ForegroundColor DarkGray
        }

        $removeCount = ($apps | Where-Object { $_.State -eq 'remove' }).Count
        Write-Host ""
        Write-Host "  $removeCount app(s) selected for removal." -ForegroundColor Cyan
        Write-Host ""

        $input = Read-Host "  > Numbers to toggle (e.g. 3,7,22), 'a', 'c', or 'q'"
        $input = $input.Trim()

        if ($input -match '^[Qq]$') {
            Write-Host "Cancelled." -ForegroundColor Yellow
            exit 0
        }
        elseif ($input -match '^[Cc]$') {
            break
        }
        elseif ($input -match '^[Aa]$') {
            $unlockProtected = $true
            Write-Host "  Protected apps unlocked. Use numbers to toggle them." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
        else {
            $tokens = $input -split '[,\s]+' | Where-Object { $_ -match '^\d+$' }
            foreach ($token in $tokens) {
                $idx = [int]$token
                $app = $apps | Where-Object { $_.Index -eq $idx } | Select-Object -First 1
                if ($null -eq $app) { continue }
                if ($app.State -eq 'protected' -and -not $unlockProtected) {
                    Write-Host "  App $idx is protected. Type 'a' to unlock protected apps first." -ForegroundColor DarkRed
                    continue
                }
                $app.State = switch ($app.State) {
                    'remove'    { 'skip' }
                    'skip'      { 'remove' }
                    'keep'      { 'remove' }
                    'protected' { 'remove' }
                    default     { 'skip' }
                }
            }
        }
    }

    # Build removal list
    $selectedIds = [System.Collections.Generic.List[string]]::new()
    $selectedNames = [System.Collections.Generic.List[string]]::new()
    foreach ($a in $apps | Where-Object { $_.State -eq 'remove' }) {
        if ($a.AppId -is [array]) {
            foreach ($id in $a.AppId) { $selectedIds.Add($id) }
        } else {
            $selectedIds.Add($a.AppId)
        }
        $selectedNames.Add($a.Name)
    }

    $script:AutoModeRemovedNames = $selectedNames.ToArray()
    $script:AutoModeRemovedIds   = $selectedIds.ToArray()

    # Kill OneDrive before WinGet tries to uninstall it - prevents exit code 2147747483
    if ($selectedIds -contains 'Microsoft.OneDrive') {
        Stop-Process -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
        Stop-Process -Name 'OneDriveSetup' -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }

    if ($selectedIds.Count -eq 0) {
        Write-Host "No apps selected for removal." -ForegroundColor Yellow
    } else {
        AddParameter 'RemoveApps'
        AddParameter 'Apps' ($selectedIds -join ',')
    }

    if (-not (Test-Path $script:AutoModeSettingsFilePath)) {
        Write-Warning "AutoModeSettings.json not found at $script:AutoModeSettingsFilePath, falling back to DefaultSettings.json"
        LoadSettings -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"
    } else {
        LoadSettings -filePath $script:AutoModeSettingsFilePath -expectedVersion "1.0"
    }

    SaveSettings

    Clear-Host
    Write-Host ""
    Write-Host "  $($selectedIds.Count) apps queued for removal." -ForegroundColor Green
    Write-Host "  Applying settings and removing apps - this may take several minutes..." -ForegroundColor Gray
    Write-Host ""
}

function Get-AppCategory {
    param([string]$AppId)
    if ($AppId -match '^AD2F1837')                           { return "HP OEM" }
    if ($AppId -match '^(E046963F|LenovoCompany)')           { return "Lenovo OEM" }
    if ($AppId -match '^DellInc')                            { return "Dell OEM" }
    if ($AppId -match '^(AcerIncorporated|Acer\.)')          { return "Acer OEM" }
    if ($AppId -match '^(ArmouryCrate|B9EBBE6Y6K1RS|ASUS)')  { return "ASUS OEM" }
    if ($AppId -match '^MSICenter')                          { return "MSI OEM" }
    if ($AppId -match '^(McAfee|NortonLifeLock|Symantec|WildTangent)') { return "Adware / Trial" }
    if ($AppId -match '^Microsoft\.Bing')                    { return "Bing Suite" }
    if ($AppId -match '(Xbox|Gaming)')                       { return "Xbox / Gaming" }
    if ($AppId -match '^Microsoft\.')                        { return "Microsoft" }
    return "Third Party"
}
