# Windows Service Editor

A modern WPF desktop utility for managing, monitoring, and automating Windows Services. Built with **.NET 10** and **WPF-UI** for a sleek Windows 11-native look and feel.

---

## Features

### 🎛️ Service Dashboard
- View all configured services in a categorized, grouped DataGrid
- Real-time status indicators (Running / Stopped / Not Found)
- **Mismatch Detection** — visual warnings when live Windows settings drift from your expected configuration
- Search and filter by service name or category
- Individual and batch Start / Stop controls

### ⚡ Automation (Jobs)
- **Job Manager** — link multiple services to a specific executable (e.g., link all VMware services to `vmware.exe`)
- **Background Auto-Start/Stop** — services start automatically when the linked EXE launches, and stop when it closes
- **Shutdown Delays** — configurable timer before stopping services (aborts if the EXE is reopened)
- **Desktop Shortcuts** — generate `.lnk` files that launch the EXE + services in one click
- **Toast Notifications** — Windows notifications for job start/stop events
- Legacy `linkedPrograms` per-service support still works alongside Jobs

### 🔍 Mismatch Detection
- Compare live Windows Registry startup types against your JSON config
- Headless mode: run `ServiceEditor.exe -CheckMismatch` from Task Scheduler for silent background checks
- Toast alerts when mismatches are detected

### 🖥️ System Tray
- Minimize to tray for background monitoring
- Right-click context menu with quick service toggles
- Configurable close behavior (Ask / Minimize / Exit)

### 📋 Management Tools
- **Category Manager** — create, rename, and delete service categories
- **Service Scanner** — browse the live list of Windows services to quickly add them to your dashboard
- **Settings Window** — configure app-wide preferences and customize the user interface
- **Theme Selection** — dynamic themes including Light, Dark (Mica), and Pure Dark (Solid Black)
- **Log Viewer** — view and clear the `service-history.log` audit trail
- **Import / Export** — back up and share your configuration
- **Keyboard Shortcuts** — navigate quickly with full hotkey support (e.g. `Ctrl+S`, `F1`, `F5`)

---

## Requirements

- **Windows 10/11** (19041+)
- **.NET 10 Runtime** ([Download](https://dotnet.microsoft.com/download/dotnet/10.0))
- **Administrator privileges** (required for service control — the app self-elevates via UAC)

---

## Build Instructions

### Run / Debug
```powershell
cd "Service Editor"
dotnet run --project ServiceEditor
```

### Publish as Single Executable
```powershell
dotnet publish ServiceEditor/ServiceEditor.csproj -c Release -r win-x64 --self-contained -p:PublishSingleFile=true
```

---

## Configuration

The app reads from `services-config.json` in the project root. Example:

```json
{
  "closeBehavior": "Ask",
  "categories": ["Uncategorized", "Network/VPN", "Virtualization", "Gaming"],
  "services": [
    {
      "name": "nordvpn-service",
      "startupType": "Manual",
      "enabled": true,
      "category": "Network/VPN",
      "linkedPrograms": ["NordVPN.exe"]
    }
  ],
  "jobs": [
    {
      "id": "guid-here",
      "name": "VMware Suite",
      "linkedExecutable": "vmware.exe",
      "serviceNames": ["VMAuthdService", "VMnetDHCP", "VMware NAT Service"],
      "shutdownDelaySeconds": 30,
      "enableToasts": true,
      "autoStartStop": true
    }
  ]
}
```

### Startup Types
| Value | Windows Equivalent |
|-------|-------------------|
| `Automatic` | Automatic |
| `DelayedStart` | Automatic (Delayed Start) |
| `Manual` | Manual |
| `Disabled` | Disabled |

---

## CLI Flags

| Flag | Description |
|------|-------------|
| `-CheckMismatch` | Run a headless mismatch check, send a toast if mismatches are found, then exit |
| `-LaunchJob <ID or Name>` | Start all services in the specified Job and launch the linked executable |

**Tip:** Use `-CheckMismatch` with Windows Task Scheduler for periodic silent monitoring.

---

## Project Structure

```
Service Editor/
├── ServiceEditor/
│   ├── App.xaml / App.xaml.cs            # Entry point, CLI parsing, UAC elevation, single-instance mutex
│   ├── MainWindow.xaml / .cs             # Main dashboard with DataGrid, search, batch operations
│   ├── JobManagerWindow.xaml / .cs       # Job CRUD, shortcut generation, manual triggers
│   ├── CategoryManagerWindow.xaml / .cs  # Category CRUD with service reassignment
│   ├── ServiceScanWindow.xaml / .cs      # Scans Windows and allows quick additions
│   ├── SettingsWindow.xaml / .cs         # Preferences and Themes
│   ├── CloseDialogWindow.xaml / .cs      # Exit vs minimize prompt
│   ├── LogViewerWindow.xaml / .cs        # Log file viewer
│   ├── AboutWindow.xaml / .cs            # Version and attribution
│   ├── Models/
│   │   ├── ConfigData.cs                 # Root JSON schema
│   │   ├── ServiceItem.cs               # Service model with INotifyPropertyChanged
│   │   ├── SettingsData.cs              # User preferences and UI theme settings
│   │   └── MonitoringJob.cs             # Job model
│   ├── Services/
│   │   ├── ConfigService.cs             # JSON load/save with path discovery
│   │   ├── SettingsService.cs           # Preferences load/save
│   │   ├── ServiceControlManager.cs     # Windows service control (start/stop/status/startup type)
│   │   ├── ProcessMonitorService.cs     # WMI process event watcher for automation
│   │   └── LoggingService.cs            # Thread-safe file logger
│   └── Utils/
│       ├── SystemTrayManager.cs         # NotifyIcon tray integration
│       └── ToastHelper.cs              # Windows balloon notifications
├── services-config.json                 # User configuration (Git-ignored)
├── app-settings.json                    # User UI settings (Git-ignored)
└── README.md
```

---

## 🔮 Future Roadmap

- **Service Descriptions** — inline display of the official Windows service description text
- **Custom Tray Icon** — replace `SystemIcons.Shield` with a branded app icon
- **Auto-Update Check** — ping GitHub Releases API on startup

---

## License

This project is licensed under the [MIT License](LICENSE).
