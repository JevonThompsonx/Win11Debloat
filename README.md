# Win11Debloat — AutoDebloat Fork

[![GitHub](https://img.shields.io/badge/Fork%20of-Raphire%2FWin11Debloat-blue?style=for-the-badge&logo=github)](https://github.com/Raphire/Win11Debloat)

Fork of [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat) with a fully automated one-liner mode for reimaging machines. Single command, no manual prompts after app selection, deep leftover cleanup (registry, AppData, scheduled tasks, startup entries).

---

## AutoDebloat — One-Liner

Open PowerShell as administrator, paste:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/Win11Debloat/master/Invoke-AutoDebloat.ps1")))
```

### What happens

1. **Auto-elevates** — saves script to `%TEMP%`, relaunches with UAC prompt if not already admin
2. **WinGet check** — if WinGet not installed, shows install command and pauses; continue after installing or skip
3. **Downloads repo** — pulls `master.zip` from this repo, extracts to `%TEMP%\Win11Debloat-auto`
4. **App selection UI** — numbered list of all bloat apps, pre-selected for removal:
   - Type numbers (e.g. `3,7,22`) to toggle items on/off
   - Type `a` to unlock protected apps (Edge, Store, Terminal)
   - Type `c` to confirm and begin removal
   - Type `q` to quit without changes
5. **Removes apps** — uninstalls selected apps via WinGet or Appx as appropriate
6. **Applies settings** — aggressive debloat settings (telemetry, Copilot, OneDrive, Bing search, taskbar cleanup, etc.)
7. **Deep leftover scan** — removes orphaned registry uninstall keys, AppData folders, scheduled tasks, and Run/RunOnce startup entries for all removed apps
8. **Reboot prompt** — asks to reboot; does not auto-reboot

### Defaults

| Category | Default |
|---|---|
| Microsoft bloat (Bing, Clipchamp, Maps, etc.) | **REMOVE** |
| OEM adware (McAfee, Norton, WildTangent) | **REMOVE** |
| OneDrive | **REMOVE** |
| Xbox / Gaming apps | **REMOVE** |
| OEM utilities (Lenovo Vantage, Legion, HP Power Manager, HP Diagnostics, Dell SupportAssist) | **KEEP** |
| Notepad, Calculator, Camera, Photos, Snipping Tool, Paint, Media Player, Remote Desktop | **KEEP** |
| Microsoft Edge | **PROTECTED** (locked unless you type `a`) |
| Microsoft Store, Terminal | **PROTECTED** |

### Safe for reimaging

Does not touch engineering software (VectorWorks, AutoCAD, Civil 3D, etc.) — only removes apps listed in `Config/Apps.json`. All changes target the current user profile or system-level Appx packages; no destructive disk wipes.

### WinGet install (if needed)

If the script reports WinGet is missing, install it with:

```powershell
& ([scriptblock]::Create((irm "https://aka.ms/getwinget")))
```

Then re-run the AutoDebloat one-liner.

---

## Original Win11Debloat

Everything below is from the upstream Raphire script, which this fork is built on. The interactive GUI and all original CLI parameters still work — AutoDebloat is an additive mode (`-AutoMode -Silent -CLI`).

> [!Warning]
> Great care went into making sure this script does not unintentionally break any OS functionality, but use at your own risk! If you run into any issues, please report them [here](https://github.com/Raphire/Win11Debloat/issues).

### Quick method (original interactive script)

```PowerShell
& ([scriptblock]::Create((irm "https://debloat.raphi.re/")))
```

### Traditional method

<details>
  <summary>Manually download & run the script.</summary><br/>

  1. [Download the latest version of the script](https://github.com/Raphire/Win11Debloat/releases/latest), and extract the .ZIP file to your desired location.
  2. Navigate to the Win11Debloat folder
  3. Double click the `Run.bat` file to start the script. NOTE: If the console window immediately closes and nothing happens, try the advanced method below.
  4. Accept the Windows UAC prompt to run the script as administrator, this is required for the script to function.
  5. Carefully read through and follow the on-screen instructions.
</details>

### Advanced method

<details>
  <summary>Manually download the script & run via PowerShell.</summary><br/>

  1. [Download the latest version of the script](https://github.com/Raphire/Win11Debloat/releases/latest), and extract the .ZIP file to your desired location.
  2. Open PowerShell or Terminal as an administrator.
  3. Temporarily enable PowerShell execution:

  ```PowerShell
  Set-ExecutionPolicy Unrestricted -Scope Process -Force
  ```

  4. Navigate to the directory: `cd c:\Win11Debloat`
  5. Run the script:

  ```PowerShell
  .\Win11Debloat.ps1
  ```
</details>

## Features

Below is an overview of features from the upstream script. Visit the [upstream wiki](https://github.com/Raphire/Win11Debloat/wiki) for full details.

> [!Tip]
> Almost all changes can be reverted and most apps can be reinstalled through the Microsoft Store.

#### App Removal
- Remove a wide variety of preinstalled apps.

#### Privacy & Suggested Content
- Disable telemetry, diagnostic data, activity history, app-launch tracking & targeted ads.
- Disable tips, tricks, suggestions & ads across Windows, the lock screen and Microsoft Edge.
- Disable Windows location services and Find My Device.
- Hide Microsoft 365 ads on the Settings 'Home' page.

#### AI Features
- Disable & remove Microsoft Copilot, Windows Recall and Click to Do.
- Prevent AI service (WSAIFabricSvc) from starting automatically.
- Disable AI features in Edge, Paint and Notepad.

#### System
- Restore the old Windows 10 style context menu.
- Turn off mouse acceleration (Enhance Pointer Precision).
- Disable Sticky Keys keyboard shortcut.
- Disable Storage Sense automatic disk cleanup.
- Disable fast start-up for full shutdown.
- Disable BitLocker automatic device encryption.

#### Windows Update
- Prevent updates from installing immediately on release.
- Prevent automatic restarts after updates while signed in.
- Disable Delivery Optimization (sharing downloaded updates with other PCs).

#### Appearance
- Enable dark mode for system and apps.
- Disable transparency, animations and visual effects.

#### Start Menu & Search
- Remove pinned apps, hide recommendations.
- Disable Bing web search & Copilot integration in Windows search.

#### Taskbar
- Customize or hide taskbar buttons (search bar, taskview, widgets, etc.).
- Enable 'End Task' in taskbar right-click menu.

#### File Explorer
- Show file extensions for known file types.
- Show hidden files, folders and drives.
- Hide OneDrive section from navigation pane.

#### Advanced Features
- Apply changes to a different user account.
- Sysprep mode for Windows Default user profile.

## License

Win11Debloat is licensed under the MIT license. See the LICENSE file for more information.
