using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Media;
using ServiceEditor.Models;
using ServiceEditor.Services;
using ServiceEditor.Utils;

namespace ServiceEditor
{
    public class GroupExpansionConverter : System.Windows.Data.IValueConverter
    {
        public static Dictionary<string, bool> ExpansionStates = new Dictionary<string, bool>();
        public static bool DefaultState = true;

        public object Convert(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        {
            string groupName = value?.ToString() ?? "";
            if (ExpansionStates.TryGetValue(groupName, out bool isExpanded))
            {
                return isExpanded;
            }
            return DefaultState;
        }

        public object ConvertBack(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        {
            return System.Windows.Data.Binding.DoNothing;
        }
    }

    public class RelayCommand : ICommand
    {
        private readonly Action _execute;
        public RelayCommand(Action execute) => _execute = execute;
#pragma warning disable CS0067
        public event EventHandler? CanExecuteChanged;
#pragma warning restore CS0067
        public bool CanExecute(object? parameter) => true;
        public void Execute(object? parameter) => _execute();
    }

    public partial class MainWindow : Wpf.Ui.Controls.FluentWindow
    {
        private ConfigData _configData = new();
        private SettingsData _settingsData = new();
        public ObservableCollection<ServiceItem> Services { get; set; } = new();
        public ObservableCollection<string> AvailableCategories { get; set; } = new();
        private ServiceItem? _draggedItem;
        private System.Timers.Timer? _searchDebounceTimer;

        private ProcessMonitorService? _processMonitor;
        private SystemTrayManager? _trayManager;
        private bool _isExiting = false;

        public ICommand SaveCommand { get; }
        public ICommand QuitCommand { get; }
        public ICommand RefreshCommand { get; }
        public ICommand SelectAllCommand { get; }
        public ICommand DeselectAllCommand { get; }
        public ICommand ClearSearchCommand { get; }
        public ICommand ImportCommand { get; }
        public ICommand ExportCommand { get; }
        public ICommand ServiceListCommand { get; }
        public ICommand ManageCategoriesCommand { get; }
        public ICommand ManageJobsCommand { get; }
        public ICommand LogsCommand { get; }
        public ICommand SettingsCommand { get; }
        public ICommand HotkeysCommand { get; }

        public MainWindow()
        {
            _configData = ConfigService.Load();
            _settingsData = SettingsService.Load();
            ApplyTheme(_settingsData.Theme);

            SaveCommand = new RelayCommand(() => BtnApplyConfig_Click(this, new RoutedEventArgs()));
            QuitCommand = new RelayCommand(() => MenuExit_Click(this, new RoutedEventArgs()));
            RefreshCommand = new RelayCommand(() => BtnRefresh_Click(this, new RoutedEventArgs()));
            SelectAllCommand = new RelayCommand(() => MenuSelectAll_Click(this, new RoutedEventArgs()));
            DeselectAllCommand = new RelayCommand(() => MenuDeselectAll_Click(this, new RoutedEventArgs()));
            ClearSearchCommand = new RelayCommand(() => { SearchBox.Text = ""; });
            ImportCommand = new RelayCommand(() => MenuImport_Click(this, new RoutedEventArgs()));
            ExportCommand = new RelayCommand(() => MenuExport_Click(this, new RoutedEventArgs()));
            ServiceListCommand = new RelayCommand(() => MenuServiceList_Click(this, new RoutedEventArgs()));
            ManageCategoriesCommand = new RelayCommand(() => MenuManageCategories_Click(this, new RoutedEventArgs()));
            ManageJobsCommand = new RelayCommand(() => MenuManageJobs_Click(this, new RoutedEventArgs()));
            LogsCommand = new RelayCommand(() => MenuLogs_Click(this, new RoutedEventArgs()));
            SettingsCommand = new RelayCommand(() => MenuSettings_Click(this, new RoutedEventArgs()));
            HotkeysCommand = new RelayCommand(() => MenuHotkeys_Click(this, new RoutedEventArgs()));

            DataContext = this;
            InitializeComponent();
            ApplyTheme(_settingsData.Theme);
            this.Loaded += (s, e) => 
            { 
                System.Windows.Application.Current.Dispatcher.InvokeAsync(() => ApplyTheme(_settingsData.Theme)); 
            };
            ApplyWindowLayout();
            
            foreach (var c in _configData.Categories)
            {
                AvailableCategories.Add(c);
            }

            ServicesGrid.ItemsSource = Services;
            LoadServices();
        }

        private void ApplyTheme(string themeString)
        {
            var wpfUiTheme = Wpf.Ui.Appearance.ApplicationTheme.Dark;
            var backdrop = Wpf.Ui.Controls.WindowBackdropType.Mica;

            if (string.Equals(themeString, "Light", StringComparison.OrdinalIgnoreCase))
            {
                wpfUiTheme = Wpf.Ui.Appearance.ApplicationTheme.Light;
            }
            else if (string.Equals(themeString, "Pure Dark", StringComparison.OrdinalIgnoreCase))
            {
                backdrop = Wpf.Ui.Controls.WindowBackdropType.None;
            }
            else if (string.Equals(themeString, "Dark", StringComparison.OrdinalIgnoreCase))
            {
                // default Dark Mode is with Mica
            }
            else // Auto
            {
                var sysTheme = Wpf.Ui.Appearance.ApplicationThemeManager.GetSystemTheme();
                wpfUiTheme = sysTheme == Wpf.Ui.Appearance.SystemTheme.Light ? Wpf.Ui.Appearance.ApplicationTheme.Light : Wpf.Ui.Appearance.ApplicationTheme.Dark;
            }

            Wpf.Ui.Appearance.ApplicationThemeManager.Apply(wpfUiTheme);
            WindowBackdropType = backdrop;
            Wpf.Ui.Controls.WindowBackdrop.ApplyBackdrop(this, backdrop);
            
            if (backdrop == Wpf.Ui.Controls.WindowBackdropType.None && wpfUiTheme == Wpf.Ui.Appearance.ApplicationTheme.Dark)
            {
                Background = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(0, 0, 0));
            }
            else
            {
                SetResourceReference(BackgroundProperty, "ApplicationBackgroundBrush");
            }
        }

        private async void LoadServices()
        {
            TxtStatus.Text = "Loading services configuration...";
            Services.Clear();
            
            // Config is loaded in constructor, just ensure it's not null

            if (_configData.Services == null || _configData.Services.Count == 0)
            {
                TxtStatus.Text = "No services configured. Update services-config.json.";
                return;
            }

            foreach (var item in _configData.Services)
            {
                Services.Add(item);
            }

            // Group by category
            var view = CollectionViewSource.GetDefaultView(Services);
            view.GroupDescriptions.Clear();
            view.GroupDescriptions.Add(new PropertyGroupDescription("Category"));

            await RefreshAllStatusesAsync();
            TxtStatus.Text = "Configuration loaded successfully.";

            // Initialize background services (Process monitor & System tray icon)
            _trayManager = new SystemTrayManager(this);
            
            _processMonitor = new ProcessMonitorService(_configData, OnServiceAutomatedStateChange);
            _processMonitor.Start();
        }

        private void OnServiceAutomatedStateChange(string serviceName)
        {
            // Marshall the UI updates back to the UI/WPF dispatcher thread
            Dispatcher.Invoke(() =>
            {
                var item = Services.FirstOrDefault(s => s.Name == serviceName);
                if (item != null)
                {
                    RefreshServiceStatus(item);
                    TxtStatus.Text = $"Automation: Checked and updated state for '{serviceName}'.";
                }
            });
        }

        public async Task RefreshAllStatusesAsync()
        {
            TxtStatus.Text = "Querying live Windows service statuses...";
            
            int total = Services.Count;
            int running = 0;
            int mismatched = 0;

            // Query live statuses asynchronously — collect results off-thread, apply on UI thread
            var serviceNames = Services.Select(s => s.Name).ToList();
            var serviceEnabled = Services.Select(s => s.Enabled).ToList();
            var serviceExpectedTypes = Services.Select(s => s.StartupType).ToList();
            var results = new (string status, string startupType, string location, bool IsMismatched, string severity, List<string> depends, List<string> required)[serviceNames.Count];

            await Task.Run(() =>
            {
                Parallel.For(0, serviceNames.Count, i =>
                {
                    string CurrentStatus = ServiceControlManager.GetStatus(serviceNames[i]);
                    string currentStartup = ServiceControlManager.GetStartupType(serviceNames[i]);
                    string location = ServiceControlManager.GetServiceLocation(serviceNames[i]);
                    var (depends, required) = ServiceControlManager.GetDependencies(serviceNames[i]);
                    bool IsMismatched = false;
                    string severity = "None";

                    if (serviceEnabled[i])
                    {
                        IsMismatched = !string.Equals(serviceExpectedTypes[i], currentStartup, StringComparison.OrdinalIgnoreCase);
                        if (IsMismatched)
                        {
                            severity = (string.Equals(currentStartup, "Automatic", StringComparison.OrdinalIgnoreCase) || string.Equals(currentStartup, "Boot", StringComparison.OrdinalIgnoreCase))
                                ? "Error" : "Warning";
                        }
                    }
                    results[i] = (CurrentStatus, currentStartup, location, IsMismatched, severity, depends, required);
                });
            });

            // Apply results on UI thread
            bool configChanged = false;
            for (int i = 0; i < Services.Count && i < results.Length; i++)
            {
                Services[i].CurrentStatus = results[i].status;
                Services[i].CurrentStartupType = results[i].startupType;
                Services[i].ServiceLocation = results[i].location;
                Services[i].IsMismatched = results[i].IsMismatched;
                Services[i].MismatchSeverity = results[i].severity;
                Services[i].DependsOn = results[i].depends;
                Services[i].RequiredBy = results[i].required;

                // Option B: Auto-save OriginalStartupType for new services
                if (Services[i].OriginalStartupType == null && results[i].startupType != "Unknown")
                {
                    Services[i].OriginalStartupType = results[i].startupType;
                    configChanged = true;

                    // Option A: Full .reg export for new services
                    if (_settingsData.AutoBackupNewServices && !RegistryBackupService.HasBackup(Services[i].Name))
                    {
                        var ok = await RegistryBackupService.BackupServiceAsync(Services[i].Name);
                        if (ok)
                        {
                            LoggingService.Log($"Auto-backed up service: {Services[i].Name}");
                        }
                    }
                }
            }

            if (configChanged)
            {
                ConfigService.Save(_configData);
            }

            // Update stats
            running = Services.Count(s => s.CurrentStatus == "Running");
            mismatched = Services.Count(s => s.IsMismatched);

            TxtTotal.Text = total.ToString();
            TxtRunning.Text = running.ToString();
            TxtMismatch.Text = mismatched.ToString();

            // Refresh the grid rendering
            CollectionViewSource.GetDefaultView(Services).Refresh();
            TxtStatus.Text = "Status check completed.";

            // Update System Tray dynamic items
            _trayManager?.UpdateMenu();
        }

        private async void RefreshServiceStatus(ServiceItem item)
        {
            await Task.Run(() =>
            {
                item.CurrentStatus = ServiceControlManager.GetStatus(item.Name);
                item.CurrentStartupType = ServiceControlManager.GetStartupType(item.Name);
                item.ServiceLocation = ServiceControlManager.GetServiceLocation(item.Name);
                if (item.Enabled)
                {
                    item.IsMismatched = !string.Equals(item.StartupType, item.CurrentStartupType, StringComparison.OrdinalIgnoreCase);
                    if (item.IsMismatched)
                    {
                        if (string.Equals(item.CurrentStartupType, "Automatic", StringComparison.OrdinalIgnoreCase) || string.Equals(item.CurrentStartupType, "Boot", StringComparison.OrdinalIgnoreCase))
                        {
                            item.MismatchSeverity = "Error";
                        }
                        else
                        {
                            item.MismatchSeverity = "Warning";
                        }
                    }
                    else
                    {
                        item.MismatchSeverity = "None";
                    }
                }
                else
                {
                    item.IsMismatched = false;
                    item.MismatchSeverity = "None";
                }
            });

            // Update stats labels
            TxtRunning.Text = Services.Count(s => s.CurrentStatus == "Running").ToString();
            TxtMismatch.Text = Services.Count(s => s.IsMismatched).ToString();
            CollectionViewSource.GetDefaultView(Services).Refresh();

            // Sync System Tray menu
            _trayManager?.UpdateMenu();
        }

        public async void BtnRefresh_Click(object sender, RoutedEventArgs e)
        {
            await RefreshAllStatusesAsync();
        }

        private async void BtnApplyConfig_Click(object sender, RoutedEventArgs e)
        {
            TxtStatus.Text = "Applying configured startup types...";
            LoggingService.Log("Applying service configuration settings...");

            var enabledServices = Services.Where(s => s.Enabled).ToList();
            if (enabledServices.Count == 0)
            {
                TxtStatus.Text = "No enabled services to apply.";
                return;
            }

            int successCount = 0;
            object lockObj = new object();
            await Task.Run(() =>
            {
                Parallel.ForEach(enabledServices, svc =>
                {
                    bool ok = ServiceControlManager.SetStartupType(svc.Name, svc.StartupType);
                    if (ok)
                    {
                        lock (lockObj) { successCount++; }
                        LoggingService.Log($"Applied startup type '{svc.StartupType}' to '{svc.Name}'.");
                    }
                    else
                    {
                        LoggingService.Log($"Failed to apply startup type '{svc.StartupType}' to '{svc.Name}'.");
                    }
                });
            });

            await RefreshAllStatusesAsync();
            TxtStatus.Text = $"Finished applying startup config. Updated {successCount}/{enabledServices.Count} services.";
        }

        private async void BtnStartSelected_Click(object sender, RoutedEventArgs e)
        {
            var selectedServices = Services.Where(s => s.IsSelected).ToList();
            if (selectedServices.Count == 0)
            {
                TxtStatus.Text = "No services selected.";
                return;
            }

            TxtStatus.Text = "Starting selected services...";
            LoggingService.Log($"Requesting start for {selectedServices.Count} selected services...");

            int startCount = 0;
            object lockObj = new object();
            await Task.Run(() =>
            {
                Parallel.ForEach(selectedServices, svc =>
                {
                    bool ok = ServiceControlManager.Start(svc.Name);
                    if (ok)
                    {
                        lock (lockObj) { startCount++; }
                        LoggingService.Log($"Started service '{svc.Name}'.");
                    }
                    else
                    {
                        LoggingService.Log($"Failed to start service '{svc.Name}'.");
                    }
                });
            });

            await RefreshAllStatusesAsync();
            TxtStatus.Text = $"Started {startCount}/{selectedServices.Count} selected services.";
        }

        private async void BtnStartAll_Click(object sender, RoutedEventArgs e)
        {
            var allServices = Services.ToList();
            if (allServices.Count == 0)
            {
                TxtStatus.Text = "No services to start.";
                return;
            }

            TxtStatus.Text = "Starting all services...";
            LoggingService.Log($"Requesting start for {allServices.Count} services...");

            int startCount = 0;
            await Task.Run(() =>
            {
                foreach (var svc in allServices)
                {
                    bool ok = ServiceControlManager.Start(svc.Name);
                    if (ok)
                    {
                        startCount++;
                        LoggingService.Log($"Started service '{svc.Name}'.");
                    }
                    else
                    {
                        LoggingService.Log($"Failed to start service '{svc.Name}'.");
                    }
                }
            });

            await RefreshAllStatusesAsync();
            TxtStatus.Text = $"Started {startCount}/{allServices.Count} services.";
        }

        private async void BtnStopSelected_Click(object sender, RoutedEventArgs e)
        {
            var selectedServices = Services.Where(s => s.IsSelected).ToList();
            if (selectedServices.Count == 0)
            {
                TxtStatus.Text = "No services selected.";
                return;
            }

            TxtStatus.Text = "Stopping selected services...";
            LoggingService.Log($"Requesting stop for {selectedServices.Count} selected services...");

            int stopCount = 0;
            await Task.Run(() =>
            {
                foreach (var svc in selectedServices)
                {
                    bool ok = ServiceControlManager.Stop(svc.Name);
                    if (ok)
                    {
                        stopCount++;
                        LoggingService.Log($"Stopped service '{svc.Name}'.");
                    }
                    else
                    {
                        LoggingService.Log($"Failed to stop service '{svc.Name}'.");
                    }
                }
            });

            await RefreshAllStatusesAsync();
            TxtStatus.Text = $"Stopped {stopCount}/{selectedServices.Count} selected services.";
        }

        private async void BtnStopAll_Click(object sender, RoutedEventArgs e)
        {
            var allServices = Services.ToList();
            if (allServices.Count == 0)
            {
                TxtStatus.Text = "No services to stop.";
                return;
            }

            TxtStatus.Text = "Stopping all services...";
            LoggingService.Log($"Requesting stop for {allServices.Count} services...");

            int stopCount = 0;
            await Task.Run(() =>
            {
                foreach (var svc in allServices)
                {
                    bool ok = ServiceControlManager.Stop(svc.Name);
                    if (ok)
                    {
                        stopCount++;
                        LoggingService.Log($"Stopped service '{svc.Name}'.");
                    }
                    else
                    {
                        LoggingService.Log($"Failed to stop service '{svc.Name}'.");
                    }
                }
            });

            await RefreshAllStatusesAsync();
            TxtStatus.Text = $"Stopped {stopCount}/{allServices.Count} services.";
        }

        private async void BtnApplySelected_Click(object sender, RoutedEventArgs e)
        {
            var selectedServices = Services.Where(s => s.IsSelected).ToList();
            if (selectedServices.Count == 0)
            {
                TxtStatus.Text = "No services selected.";
                return;
            }

            TxtStatus.Text = "Applying configured startup types to selected services...";
            LoggingService.Log($"Requesting apply for {selectedServices.Count} selected services...");

            int successCount = 0;
            await Task.Run(() =>
            {
                foreach (var svc in selectedServices)
                {
                    bool ok = ServiceControlManager.SetStartupType(svc.Name, svc.StartupType);
                    if (ok)
                    {
                        successCount++;
                        LoggingService.Log($"Applied startup type '{svc.StartupType}' to '{svc.Name}'.");
                    }
                    else
                    {
                        LoggingService.Log($"Failed to apply startup type '{svc.StartupType}' to '{svc.Name}'.");
                    }
                }
            });

            await RefreshAllStatusesAsync();
            TxtStatus.Text = $"Finished applying startup config. Updated {successCount}/{selectedServices.Count} selected services.";
        }

        private async void BtnApplyAll_Click(object sender, RoutedEventArgs e)
        {
            var allServices = Services.ToList();
            if (allServices.Count == 0)
            {
                TxtStatus.Text = "No services to apply to.";
                return;
            }

            TxtStatus.Text = "Applying configured startup types to all services...";
            LoggingService.Log($"Requesting apply for {allServices.Count} services...");

            int successCount = 0;
            await Task.Run(() =>
            {
                foreach (var svc in allServices)
                {
                    bool ok = ServiceControlManager.SetStartupType(svc.Name, svc.StartupType);
                    if (ok)
                    {
                        successCount++;
                        LoggingService.Log($"Applied startup type '{svc.StartupType}' to '{svc.Name}'.");
                    }
                    else
                    {
                        LoggingService.Log($"Failed to apply startup type '{svc.StartupType}' to '{svc.Name}'.");
                    }
                }
            });

            await RefreshAllStatusesAsync();
            TxtStatus.Text = $"Finished applying startup config. Updated {successCount}/{allServices.Count} services.";
        }

        private async void BtnStartIndividual_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn && btn.DataContext is ServiceItem item)
            {
                TxtStatus.Text = $"Starting '{item.Name}'...";
                bool ok = await Task.Run(() => ServiceControlManager.Start(item.Name));
                if (ok)
                {
                    LoggingService.Log($"Started service '{item.Name}' via controls.");
                    TxtStatus.Text = $"Successfully started service '{item.Name}'.";
                }
                else
                {
                    TxtStatus.Text = $"Failed to start service '{item.Name}'.";
                }
                RefreshServiceStatus(item);
            }
        }

        private async void BtnStopIndividual_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn && btn.DataContext is ServiceItem item)
            {
                TxtStatus.Text = $"Stopping '{item.Name}'...";
                bool ok = await Task.Run(() => ServiceControlManager.Stop(item.Name));
                if (ok)
                {
                    LoggingService.Log($"Stopped service '{item.Name}' via controls.");
                    TxtStatus.Text = $"Successfully stopped service '{item.Name}'.";
                }
                else
                {
                    TxtStatus.Text = $"Failed to stop service '{item.Name}'.";
                }
                RefreshServiceStatus(item);
            }
        }

        private async void BtnApplyIndividual_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn && btn.DataContext is ServiceItem item)
            {
                TxtStatus.Text = $"Applying startup type '{item.StartupType}' to '{item.Name}'...";
                bool ok = await Task.Run(() => ServiceControlManager.SetStartupType(item.Name, item.StartupType));
                if (ok)
                {
                    LoggingService.Log($"Applied startup type '{item.StartupType}' to '{item.Name}' via controls.");
                    TxtStatus.Text = $"Successfully applied startup type '{item.StartupType}' to '{item.Name}'.";
                }
                else
                {
                    TxtStatus.Text = $"Failed to apply startup type to '{item.Name}'.";
                }
                RefreshServiceStatus(item);
            }
        }

        private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (_searchDebounceTimer == null)
            {
                _searchDebounceTimer = new System.Timers.Timer(300);
                _searchDebounceTimer.AutoReset = false;
                _searchDebounceTimer.Elapsed += (s, args) =>
                {
                    Dispatcher.Invoke(() =>
                    {
                        string filterText = SearchBox.Text;
                        ICollectionView view = CollectionViewSource.GetDefaultView(Services);
                        
                        if (string.IsNullOrEmpty(filterText))
                        {
                            view.Filter = null;
                        }
                        else
                        {
                            view.Filter = obj =>
                            {
                                if (obj is ServiceItem item)
                                {
                                    return item.Name.Contains(filterText, StringComparison.OrdinalIgnoreCase) || 
                                           (item.Category != null && item.Category.Contains(filterText, StringComparison.OrdinalIgnoreCase));
                                }
                                return false;
                            };
                        }
                    });
                };
            }
            
            _searchDebounceTimer.Stop();
            _searchDebounceTimer.Start();
        }

        private void ManagedCheck_Changed(object sender, RoutedEventArgs e)
        {
            // Auto-save when enable status changes
            ConfigService.Save(_configData);
            TxtStatus.Text = "Saved management state changes to config.";
        }

        public void ShutdownApp()
        {
            _isExiting = true;
            Close();
        }

        protected override void OnClosing(CancelEventArgs e)
        {
            if (_isExiting) return;

            if (e != null)
            {
                if (_settingsData.CloseBehavior == "Ask")
                {
                    var dialog = new CloseDialogWindow { Owner = this };
                    dialog.ShowDialog();
                    
                    if (dialog.SelectedBehavior != "Ask" && dialog.Result != CloseDialogWindow.CloseAction.Cancel)
                    {
                        _settingsData.CloseBehavior = dialog.SelectedBehavior;
                        SettingsService.Save(_settingsData);
                    }

                    if (dialog.Result == CloseDialogWindow.CloseAction.Minimize)
                    {
                        e.Cancel = true;
                        Hide();
                        _trayManager?.UpdateMenu();
                        return;
                    }
                    else if (dialog.Result == CloseDialogWindow.CloseAction.Exit)
                    {
                        _isExiting = true;
                        e.Cancel = false;
                        _processMonitor?.Stop();
                        _trayManager?.Dispose();
                    }
                    else
                    {
                        // Cancel exit
                        e.Cancel = true;
                        return;
                    }
                }
                else if (_settingsData.CloseBehavior == "Minimize")
                {
                    Hide();
                    _trayManager?.UpdateMenu();
                }
                else // "Exit"
                {
                    _isExiting = true;
                    e.Cancel = false;
                    _processMonitor?.Stop();
                    _trayManager?.Dispose();
                }
            }
        }

        protected override void OnClosed(EventArgs e)
        {
            _searchDebounceTimer?.Dispose();
            SaveWindowLayout();
            base.OnClosed(e);
        }

        private void ApplyWindowLayout()
        {
            Width = _settingsData.WindowWidth > 0 ? _settingsData.WindowWidth : 1100;
            Height = _settingsData.WindowHeight > 0 ? _settingsData.WindowHeight : 680;

            if (_settingsData.IsMaximized)
            {
                WindowState = WindowState.Maximized;
            }

            var converter = new System.Windows.Controls.DataGridLengthConverter();
            foreach (var kvp in _settingsData.ColumnWidths)
            {
                try
                {
                    var converted = converter.ConvertFromString(kvp.Value);
                    if (converted == null) continue;
                    var length = (System.Windows.Controls.DataGridLength)converted;
                    switch (kvp.Key)
                    {
                        case "ColSelection": ColSelection.Width = length; break;
                        case "ColMismatch": ColMismatch.Width = length; break;
                        case "ColServiceName": ColServiceName.Width = length; break;
                        case "ColCategory": ColCategory.Width = length; break;
                        case "ColSetMode": ColSetMode.Width = length; break;
                        case "ColLinkedPrograms": ColLinkedPrograms.Width = length; break;
                        case "ColServiceLocation": ColServiceLocation.Width = length; break;
                        case "ColCurrentMode": ColCurrentMode.Width = length; break;
                        case "ColOriginalMode": ColOriginalMode.Width = length; break;
                        case "ColStatus": ColStatus.Width = length; break;
                    }
                }
                catch { } // Ignore parse errors
            }

            foreach (var kvp in _settingsData.ColumnVisibility)
            {
                switch (kvp.Key)
                {
                    case "ColSelection": ColSelection.Visibility = kvp.Value ? Visibility.Visible : Visibility.Collapsed; break;
                    case "ColMismatch": ColMismatch.Visibility = kvp.Value ? Visibility.Visible : Visibility.Collapsed; break;
                    case "ColServiceName": ColServiceName.Visibility = kvp.Value ? Visibility.Visible : Visibility.Collapsed; break;
                    case "ColCategory": ColCategory.Visibility = kvp.Value ? Visibility.Visible : Visibility.Collapsed; break;
                    case "ColSetMode": ColSetMode.Visibility = kvp.Value ? Visibility.Visible : Visibility.Collapsed; break;
                    case "ColLinkedPrograms": ColLinkedPrograms.Visibility = kvp.Value ? Visibility.Visible : Visibility.Collapsed; break;
                    case "ColServiceLocation": ColServiceLocation.Visibility = kvp.Value ? Visibility.Visible : Visibility.Collapsed; break;
                    case "ColCurrentMode": ColCurrentMode.Visibility = kvp.Value ? Visibility.Visible : Visibility.Collapsed; break;
                    case "ColOriginalMode": ColOriginalMode.Visibility = kvp.Value ? Visibility.Visible : Visibility.Collapsed; break;
                    case "ColStatus": ColStatus.Visibility = kvp.Value ? Visibility.Visible : Visibility.Collapsed; break;
                }
            }

            // We must order by DisplayIndex before setting to avoid out-of-bounds exceptions
            var sortedDisplayIndices = _settingsData.ColumnDisplayIndex.OrderBy(x => x.Value).ToList();
            foreach (var kvp in sortedDisplayIndices)
            {
                switch (kvp.Key)
                {
                    case "ColSelection": ColSelection.DisplayIndex = kvp.Value; break;
                    case "ColMismatch": ColMismatch.DisplayIndex = kvp.Value; break;
                    case "ColServiceName": ColServiceName.DisplayIndex = kvp.Value; break;
                    case "ColCategory": ColCategory.DisplayIndex = kvp.Value; break;
                    case "ColSetMode": ColSetMode.DisplayIndex = kvp.Value; break;
                    case "ColLinkedPrograms": ColLinkedPrograms.DisplayIndex = kvp.Value; break;
                    case "ColServiceLocation": ColServiceLocation.DisplayIndex = kvp.Value; break;
                    case "ColCurrentMode": ColCurrentMode.DisplayIndex = kvp.Value; break;
                    case "ColOriginalMode": ColOriginalMode.DisplayIndex = kvp.Value; break;
                    case "ColStatus": ColStatus.DisplayIndex = kvp.Value; break;
                }
            }
        }

        private void SaveWindowLayout()
        {
            if (WindowState == WindowState.Maximized)
            {
                _settingsData.IsMaximized = true;
                _settingsData.WindowWidth = RestoreBounds.Width;
                _settingsData.WindowHeight = RestoreBounds.Height;
            }
            else
            {
                _settingsData.IsMaximized = false;
                _settingsData.WindowWidth = Width;
                _settingsData.WindowHeight = Height;
            }

            var converter = new System.Windows.Controls.DataGridLengthConverter();
            _settingsData.ColumnWidths["ColSelection"] = converter.ConvertToString(ColSelection.Width) ?? "Auto";
            _settingsData.ColumnWidths["ColMismatch"] = converter.ConvertToString(ColMismatch.Width) ?? "Auto";
            _settingsData.ColumnWidths["ColServiceName"] = converter.ConvertToString(ColServiceName.Width) ?? "Auto";
            _settingsData.ColumnWidths["ColCategory"] = converter.ConvertToString(ColCategory.Width) ?? "Auto";
            _settingsData.ColumnWidths["ColSetMode"] = converter.ConvertToString(ColSetMode.Width) ?? "Auto";
            _settingsData.ColumnWidths["ColLinkedPrograms"] = converter.ConvertToString(ColLinkedPrograms.Width) ?? "Auto";
            _settingsData.ColumnWidths["ColServiceLocation"] = converter.ConvertToString(ColServiceLocation.Width) ?? "Auto";
            _settingsData.ColumnWidths["ColCurrentMode"] = converter.ConvertToString(ColCurrentMode.Width) ?? "Auto";
            _settingsData.ColumnWidths["ColOriginalMode"] = converter.ConvertToString(ColOriginalMode.Width) ?? "Auto";
            _settingsData.ColumnWidths["ColStatus"] = converter.ConvertToString(ColStatus.Width) ?? "Auto";

            _settingsData.ColumnVisibility["ColSelection"] = ColSelection.Visibility == Visibility.Visible;
            _settingsData.ColumnVisibility["ColMismatch"] = ColMismatch.Visibility == Visibility.Visible;
            _settingsData.ColumnVisibility["ColServiceName"] = ColServiceName.Visibility == Visibility.Visible;
            _settingsData.ColumnVisibility["ColCategory"] = ColCategory.Visibility == Visibility.Visible;
            _settingsData.ColumnVisibility["ColSetMode"] = ColSetMode.Visibility == Visibility.Visible;
            _settingsData.ColumnVisibility["ColLinkedPrograms"] = ColLinkedPrograms.Visibility == Visibility.Visible;
            _settingsData.ColumnVisibility["ColServiceLocation"] = ColServiceLocation.Visibility == Visibility.Visible;
            _settingsData.ColumnVisibility["ColCurrentMode"] = ColCurrentMode.Visibility == Visibility.Visible;
            _settingsData.ColumnVisibility["ColOriginalMode"] = ColOriginalMode.Visibility == Visibility.Visible;
            _settingsData.ColumnVisibility["ColStatus"] = ColStatus.Visibility == Visibility.Visible;

            _settingsData.ColumnDisplayIndex["ColSelection"] = ColSelection.DisplayIndex;
            _settingsData.ColumnDisplayIndex["ColMismatch"] = ColMismatch.DisplayIndex;
            _settingsData.ColumnDisplayIndex["ColServiceName"] = ColServiceName.DisplayIndex;
            _settingsData.ColumnDisplayIndex["ColCategory"] = ColCategory.DisplayIndex;
            _settingsData.ColumnDisplayIndex["ColSetMode"] = ColSetMode.DisplayIndex;
            _settingsData.ColumnDisplayIndex["ColLinkedPrograms"] = ColLinkedPrograms.DisplayIndex;
            _settingsData.ColumnDisplayIndex["ColServiceLocation"] = ColServiceLocation.DisplayIndex;
            _settingsData.ColumnDisplayIndex["ColCurrentMode"] = ColCurrentMode.DisplayIndex;
            _settingsData.ColumnDisplayIndex["ColOriginalMode"] = ColOriginalMode.DisplayIndex;
            _settingsData.ColumnDisplayIndex["ColStatus"] = ColStatus.DisplayIndex;

            SettingsService.Save(_settingsData);
        }


        private void MenuImport_Click(object sender, RoutedEventArgs e)
        {
            var openFileDialog = new Microsoft.Win32.OpenFileDialog
            {
                Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*",
                Title = "Import Configuration"
            };

            if (openFileDialog.ShowDialog() == true)
            {
                try
                {
                    string json = System.IO.File.ReadAllText(openFileDialog.FileName);
                    var data = Newtonsoft.Json.JsonConvert.DeserializeObject<ConfigData>(json);
                    if (data != null && data.Services != null)
                    {
                        _configData = data;
                        ConfigService.Save(_configData);
                        LoadServices();
                        TxtStatus.Text = "Configuration imported successfully.";
                        LoggingService.Log($"Imported configuration from {openFileDialog.FileName}");
                    }
                }
                catch (Exception ex)
                {
                    System.Windows.MessageBox.Show($"Error importing configuration: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void MenuExport_Click(object sender, RoutedEventArgs e)
        {
            var saveFileDialog = new Microsoft.Win32.SaveFileDialog
            {
                Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*",
                Title = "Export Configuration",
                FileName = "services-config-export.json"
            };

            if (saveFileDialog.ShowDialog() == true)
            {
                try
                {
                    string json = Newtonsoft.Json.JsonConvert.SerializeObject(_configData, Newtonsoft.Json.Formatting.Indented);
                    System.IO.File.WriteAllText(saveFileDialog.FileName, json);
                    TxtStatus.Text = "Configuration exported successfully.";
                    LoggingService.Log($"Exported configuration to {saveFileDialog.FileName}");
                }
                catch (Exception ex)
                {
                    System.Windows.MessageBox.Show($"Error exporting configuration: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void MenuAbout_Click(object sender, RoutedEventArgs e)
        {
            var aboutWindow = new AboutWindow { Owner = this };
            aboutWindow.ShowDialog();
        }

        private void MenuExit_Click(object sender, RoutedEventArgs e)
        {
            ShutdownApp();
        }

        private void MenuHotkeys_Click(object sender, RoutedEventArgs e)
        {
            var msg = "Hotkeys:\n\n" +
                      "Ctrl+I\t\tImport Config\n" +
                      "Ctrl+E\t\tExport Config\n" +
                      "Ctrl+L\t\tService List\n" +
                      "Ctrl+M\t\tManage Categories\n" +
                      "Ctrl+J\t\tManage Jobs\n" +
                      "F12\t\tLogs\n" +
                      "F4\t\tSettings\n" +
                      "Ctrl+S\t\tSave/Apply Changes\n" +
                      "F5\t\tRefresh\n" +
                      "Ctrl+A\t\tSelect All\n" +
                      "Ctrl+D\t\tDeselect All\n" +
                      "Esc\t\tClear Search\n" +
                      "F1\t\tShow Hotkeys Info";
            System.Windows.MessageBox.Show(msg, "Hotkeys Info", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void MenuLogs_Click(object sender, RoutedEventArgs e)
        {
            var logViewer = new LogViewerWindow();
            logViewer.Owner = this;
            logViewer.Show();
        }

        private void MenuSettings_Click(object sender, RoutedEventArgs e)
        {
            var settingsWindow = new SettingsWindow(_settingsData, _configData);
            settingsWindow.Owner = this;
            if (settingsWindow.ShowDialog() == true)
            {
                SettingsService.Save(_settingsData);
                ApplyTheme(_settingsData.Theme);
            }
        }

        private void MenuServiceList_Click(object sender, RoutedEventArgs e)
        {
            var scanWindow = new ServiceScanWindow(Services, _configData);
            scanWindow.Owner = this;
            scanWindow.ShowDialog();
        }

        private void MenuManageCategories_Click(object sender, RoutedEventArgs e)
        {
            var categoryWindow = new CategoryManagerWindow(_configData, Services);
            categoryWindow.Owner = this;
            if (categoryWindow.ShowDialog() == true)
            {
                ConfigService.Save(_configData);
                // Refresh categories grouping
                var view = CollectionViewSource.GetDefaultView(Services);
                view.Refresh();
            }
        }

        private void MenuManageJobs_Click(object sender, RoutedEventArgs e)
        {
            var jobWindow = new JobManagerWindow(_configData);
            jobWindow.Owner = this;
            if (jobWindow.ShowDialog() == true)
            {
                // Restart process monitor to load new jobs
                _processMonitor?.Stop();
                _processMonitor = new ProcessMonitorService(_configData, OnServiceAutomatedStateChange);
                _processMonitor.Start();
            }
        }

        private void ServicesGrid_CellEditEnding(object sender, DataGridCellEditEndingEventArgs e)
        {
            if (e.EditAction == DataGridEditAction.Commit)
            {
                Dispatcher.InvokeAsync(() =>
                {
                    ConfigService.Save(_configData);
                    
                    if (e.Column.Header?.ToString() == "Category")
                    {
                        var view = CollectionViewSource.GetDefaultView(Services);
                        view.Refresh();
                    }
                }, System.Windows.Threading.DispatcherPriority.Background);
            }
        }

        private bool IsDragHandle(DependencyObject element)
        {
            while (element != null)
            {
                if (element is FrameworkElement fe && fe.Tag?.ToString() == "DragHandle")
                    return true;
                if (element is System.Windows.Controls.DataGridCell)
                    break;
                element = System.Windows.Media.VisualTreeHelper.GetParent(element);
            }
            return false;
        }

        private void ServicesGrid_PreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            if (e.OriginalSource is FrameworkElement fe)
            {
                // Don't interfere with interactive controls
                if (fe is System.Windows.Controls.CheckBox || fe is System.Windows.Controls.Primitives.ToggleButton || fe is System.Windows.Controls.Button || fe.GetType().Name.Contains("Button"))
                {
                    return;
                }

                if (fe.DataContext is ServiceItem item)
                {
                    if (IsDragHandle(fe))
                    {
                        _draggedItem = item;
                    }
                }
            }
        }

        private void ServicesGrid_PreviewMouseLeftButtonUp(object sender, MouseButtonEventArgs e)
        {
            _draggedItem = null; // Clear it to prevent Drag&Drop from firing on random mouse moves later

            if (e.OriginalSource is FrameworkElement fe)
            {
                // Ignore interactive controls
                if (fe is System.Windows.Controls.CheckBox || fe is System.Windows.Controls.Primitives.ToggleButton || fe is System.Windows.Controls.Button || fe.GetType().Name.Contains("Button"))
                {
                    return;
                }

                if (GetVisualParent<System.Windows.Controls.Primitives.DataGridDetailsPresenter>(fe) != null)
                {
                    return; // Don't collapse if clicking inside Row Details
                }

                if (IsDragHandle(fe))
                {
                    return; // Don't toggle row if they just clicked and released the drag handle
                }

                if (fe.DataContext is ServiceItem item)
                {
                    var row = GetVisualParent<System.Windows.Controls.DataGridRow>(fe);
                    if (row != null)
                    {
                        // Explicitly toggle details visibility
                        row.DetailsVisibility = row.DetailsVisibility == Visibility.Visible ? Visibility.Collapsed : Visibility.Visible;
                    }
                }
            }
        }

        private static T? GetVisualParent<T>(DependencyObject child) where T : DependencyObject
        {
            DependencyObject parentObject = System.Windows.Media.VisualTreeHelper.GetParent(child);
            if (parentObject == null) return null;
            if (parentObject is T parent) return parent;
            return GetVisualParent<T>(parentObject);
        }

        public static IEnumerable<T> FindVisualChildren<T>(DependencyObject? depObj) where T : DependencyObject
        {
            if (depObj != null)
            {
                for (int i = 0; i < System.Windows.Media.VisualTreeHelper.GetChildrenCount(depObj); i++)
                {
                    DependencyObject child = System.Windows.Media.VisualTreeHelper.GetChild(depObj, i);
                    if (child != null && child is T t)
                    {
                        yield return t;
                    }
                    foreach (T childOfChild in FindVisualChildren<T>(child))
                    {
                        yield return childOfChild;
                    }
                }
            }
        }

        private void ServicesGrid_MouseMove(object sender, System.Windows.Input.MouseEventArgs e)
        {
            if (e.LeftButton == System.Windows.Input.MouseButtonState.Pressed && _draggedItem != null)
            {
                System.Windows.DragDrop.DoDragDrop(ServicesGrid, _draggedItem, System.Windows.DragDropEffects.Move);
            }
        }

        private System.Windows.Controls.DataGridRow? _lastHighlightedRow;

        private void ServicesGrid_DragOver(object sender, System.Windows.DragEventArgs e)
        {
            if (!e.Data.GetDataPresent(typeof(ServiceItem)))
            {
                e.Effects = System.Windows.DragDropEffects.None;
                return;
            }

            e.Effects = System.Windows.DragDropEffects.Move;

            if (e.OriginalSource is DependencyObject depObj)
            {
                var targetRow = GetVisualParent<System.Windows.Controls.DataGridRow>(depObj);
                if (targetRow != null && targetRow != _lastHighlightedRow)
                {
                    ClearDropHighlight();

                    _lastHighlightedRow = targetRow;
                    targetRow.BorderBrush = System.Windows.Media.Brushes.DodgerBlue;
                    targetRow.BorderThickness = new System.Windows.Thickness(0, 2, 0, 0);
                }
            }
        }

        private void ServicesGrid_DragLeave(object sender, System.Windows.DragEventArgs e)
        {
            if (e.OriginalSource is DependencyObject depObj)
            {
                var targetRow = GetVisualParent<System.Windows.Controls.DataGridRow>(depObj);
                if (targetRow != null && targetRow == _lastHighlightedRow)
                {
                    ClearDropHighlight();
                }
            }
        }

        private void ClearDropHighlight()
        {
            if (_lastHighlightedRow != null)
            {
                _lastHighlightedRow.ClearValue(System.Windows.Controls.Control.BorderBrushProperty);
                _lastHighlightedRow.ClearValue(System.Windows.Controls.Control.BorderThicknessProperty);
                _lastHighlightedRow = null;
            }
        }

        private void ServicesGrid_Drop(object sender, System.Windows.DragEventArgs e)
        {
            ClearDropHighlight();
            
            if (e.Data.GetDataPresent(typeof(ServiceItem)))
            {
                var droppedItem = e.Data.GetData(typeof(ServiceItem)) as ServiceItem;
                var targetItem = ((FrameworkElement)e.OriginalSource).DataContext as ServiceItem;

                if (droppedItem != null && targetItem != null && droppedItem != targetItem)
                {
                    int oldIndex = _configData.Services.IndexOf(droppedItem);
                    int newIndex = _configData.Services.IndexOf(targetItem);
                    
                    if (oldIndex >= 0 && newIndex >= 0)
                    {
                        _configData.Services.RemoveAt(oldIndex);
                        _configData.Services.Insert(newIndex, droppedItem);
                        
                        Services.RemoveAt(oldIndex);
                        Services.Insert(newIndex, droppedItem);
                        
                        if (droppedItem.Category != targetItem.Category)
                        {
                            droppedItem.Category = targetItem.Category;
                            CollectionViewSource.GetDefaultView(Services).Refresh();
                        }
                        
                        ConfigService.Save(_configData);
                    }
                }
            }
            _draggedItem = null;
        }

        private void ServicesGrid_PreviewMouseRightButtonUp(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            var hit = System.Windows.Media.VisualTreeHelper.HitTest(ServicesGrid, e.GetPosition(ServicesGrid));
            if (hit == null) return;

            // Check if we hit a Column Header
            var columnHeader = FindVisualParent<System.Windows.Controls.Primitives.DataGridColumnHeader>(hit.VisualHit);
            if (columnHeader != null)
            {
                var contextMenu = new System.Windows.Controls.ContextMenu();
                var modesMenu = new System.Windows.Controls.MenuItem { Header = "Modes" };

                foreach (var col in ServicesGrid.Columns)
                {
                    string headerText = col.Header?.ToString() ?? string.Empty;
                    if (string.IsNullOrEmpty(headerText))
                    {
                        if (col is System.Windows.Controls.DataGridTemplateColumn && col.Width.Value == 60)
                        {
                            headerText = "Selection";
                        }
                        else
                        {
                            continue;
                        }
                    }

                    var menuItem = new System.Windows.Controls.MenuItem
                    {
                        Header = headerText,
                        IsCheckable = true,
                        IsChecked = col.Visibility == Visibility.Visible
                    };

                    menuItem.Click += (s, args) =>
                    {
                        col.Visibility = menuItem.IsChecked ? Visibility.Visible : Visibility.Collapsed;
                    };

                    if (headerText == "Set" || headerText == "Current" || headerText == "Original")
                    {
                        modesMenu.Items.Add(menuItem);
                    }
                    else
                    {
                        contextMenu.Items.Add(menuItem);
                    }
                }

                if (modesMenu.Items.Count > 0)
                {
                    contextMenu.Items.Add(new System.Windows.Controls.Separator());
                    contextMenu.Items.Add(modesMenu);
                }

                                var resetMenuItem = new System.Windows.Controls.MenuItem
                {
                    Header = "Reset Columns to Default",
                    Foreground = System.Windows.Media.Brushes.DodgerBlue
                };
                resetMenuItem.Click += (s, args) =>
                {
                    ResetColumnsToDefault();
                };
                contextMenu.Items.Add(new System.Windows.Controls.Separator());
                contextMenu.Items.Add(resetMenuItem);

                contextMenu.PlacementTarget = columnHeader;
                contextMenu.IsOpen = true;
                e.Handled = true;
                return;
            }

            // Check if we hit a Row or Cell
            var row = FindVisualParent<System.Windows.Controls.DataGridRow>(hit.VisualHit);
            if (row != null && row.DataContext is ServiceItem item)
            {
                // Ensure row is selected
                if (!ServicesGrid.SelectedItems.Contains(item))
                {
                    ServicesGrid.SelectedItem = item;
                }
                
                // Show row context menu
                if (TryFindResource("RowContextMenu") is System.Windows.Controls.ContextMenu rowMenu)
                {
                    rowMenu.PlacementTarget = row;
                    rowMenu.IsOpen = true;
                }
                e.Handled = true;
            }
        }

        private void ResetColumnsToDefault()
        {
            _settingsData.ColumnDisplayIndex.Clear();
            _settingsData.ColumnVisibility.Clear();
            _settingsData.ColumnWidths.Clear();

            foreach (var col in ServicesGrid.Columns)
            {
                col.ClearValue(System.Windows.Controls.DataGridColumn.DisplayIndexProperty);
                col.ClearValue(System.Windows.Controls.DataGridColumn.WidthProperty);
            }

            if (ColCategory != null) ColCategory.Visibility = Visibility.Collapsed;
            if (ColOriginalMode != null) ColOriginalMode.Visibility = Visibility.Collapsed;
            if (ColServiceLocation != null) ColServiceLocation.Visibility = Visibility.Collapsed;
            
            if (ColSelection != null) ColSelection.Visibility = Visibility.Visible;
            if (ColMismatch != null) ColMismatch.Visibility = Visibility.Visible;
            if (ColServiceName != null) ColServiceName.Visibility = Visibility.Visible;
            if (ColCurrentMode != null) ColCurrentMode.Visibility = Visibility.Visible;
            if (ColSetMode != null) ColSetMode.Visibility = Visibility.Visible;
            if (ColLinkedPrograms != null) ColLinkedPrograms.Visibility = Visibility.Visible;
            if (ColStatus != null) ColStatus.Visibility = Visibility.Visible;

            if (ColManaged != null) { ColManaged.Visibility = Visibility.Visible; ColManaged.Width = 95; }
            if (ColDragHandle != null) ColDragHandle.Visibility = Visibility.Visible;
            if (ColControls != null) ColControls.Visibility = Visibility.Visible;

            if (ColDragHandle != null) ColDragHandle.DisplayIndex = 0;
            if (ColSelection != null) ColSelection.DisplayIndex = 1;
            if (ColMismatch != null) ColMismatch.DisplayIndex = 2;
            if (ColServiceName != null) ColServiceName.DisplayIndex = 3;
            if (ColCategory != null) ColCategory.DisplayIndex = 4;
            if (ColOriginalMode != null) ColOriginalMode.DisplayIndex = 5;
            if (ColCurrentMode != null) ColCurrentMode.DisplayIndex = 6;
            if (ColSetMode != null) ColSetMode.DisplayIndex = 7;
            if (ColLinkedPrograms != null) ColLinkedPrograms.DisplayIndex = 8;
            if (ColServiceLocation != null) ColServiceLocation.DisplayIndex = 9;
            if (ColStatus != null) ColStatus.DisplayIndex = 10;
            if (ColManaged != null) ColManaged.DisplayIndex = 11;
            if (ColControls != null) ColControls.DisplayIndex = 12;

            SaveWindowLayout();
        }

        private void GroupExpander_Expanded(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Expander exp && exp.DataContext is System.Windows.Data.CollectionViewGroup group)
            {
                GroupExpansionConverter.ExpansionStates[group.Name?.ToString() ?? ""] = true;
            }
        }

        private void GroupExpander_Collapsed(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Expander exp && exp.DataContext is System.Windows.Data.CollectionViewGroup group)
            {
                GroupExpansionConverter.ExpansionStates[group.Name?.ToString() ?? ""] = false;
            }
        }

        private void SetVisibleExpanders(bool isExpanded, string? categoryFilter)
        {
            var expanders = FindVisualChildren<System.Windows.Controls.Expander>(ServicesGrid);
            foreach (var exp in expanders)
            {
                if (exp.DataContext is System.Windows.Data.CollectionViewGroup group)
                {
                    string groupName = group.Name?.ToString() ?? "";
                    if (categoryFilter == null || groupName == categoryFilter)
                    {
                        exp.IsExpanded = isExpanded;
                    }
                }
            }
        }

        private void MenuExpandAll_Click(object sender, RoutedEventArgs e)
        {
            GroupExpansionConverter.DefaultState = true;
            GroupExpansionConverter.ExpansionStates.Clear();
            SetVisibleExpanders(true, null);
        }

        private void MenuCollapseAll_Click(object sender, RoutedEventArgs e)
        {
            GroupExpansionConverter.DefaultState = false;
            GroupExpansionConverter.ExpansionStates.Clear();
            SetVisibleExpanders(false, null);
        }

        private void MenuExpandByCategory_Click(object sender, RoutedEventArgs e)
        {
            if (ServicesGrid.SelectedItem is ServiceItem item)
            {
                string cat = item.Category ?? "";
                GroupExpansionConverter.ExpansionStates[cat] = true;
                SetVisibleExpanders(true, cat);
            }
        }

        private void MenuCollapseByCategory_Click(object sender, RoutedEventArgs e)
        {
            if (ServicesGrid.SelectedItem is ServiceItem item)
            {
                string cat = item.Category ?? "";
                GroupExpansionConverter.ExpansionStates[cat] = false;
                SetVisibleExpanders(false, cat);
            }
        }

        private void CheckBox_PreviewMouseLeftButtonDown(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            if (sender is System.Windows.Controls.CheckBox cb && cb.DataContext is ServiceItem item)
            {
                item.IsSelected = !item.IsSelected;
                e.Handled = true; // Mark as handled to prevent the DataGrid from selecting the row and expanding it
            }
        }

        private static T? FindVisualParent<T>(System.Windows.DependencyObject child) where T : System.Windows.DependencyObject
        {
            var parentObject = System.Windows.Media.VisualTreeHelper.GetParent(child);
            if (parentObject == null) return null;
            if (parentObject is T parent) return parent;
            return FindVisualParent<T>(parentObject);
        }

        private void MenuSelectAll_Click(object sender, RoutedEventArgs e)
        {
            foreach (var service in Services)
            {
                service.IsSelected = true;
            }
            TxtStatus.Text = "Selected all services.";
        }

        private void MenuDeselectAll_Click(object sender, RoutedEventArgs e)
        {
            foreach (var service in Services)
            {
                service.IsSelected = false;
            }
            TxtStatus.Text = "Deselected all services.";
        }

        private void MenuSelectByCategory_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.MenuItem menuItem)
            {
                var contextMenu = menuItem.Parent as System.Windows.Controls.ContextMenu;
                if (contextMenu == null)
                {
                    contextMenu = System.Windows.LogicalTreeHelper.GetParent(menuItem) as System.Windows.Controls.ContextMenu;
                }
                if (contextMenu != null && contextMenu.PlacementTarget is DataGridRow row && row.DataContext is ServiceItem clickedItem)
                {
                    string category = clickedItem.Category;
                    int count = 0;
                    foreach (var service in Services)
                    {
                        if (service.Category == category)
                        {
                            service.IsSelected = true;
                            count++;
                        }
                    }
                    TxtStatus.Text = $"Selected {count} services in category '{category}'.";
                }
            }
        }

        private void MenuDeselectByCategory_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.MenuItem menuItem)
            {
                var contextMenu = menuItem.Parent as System.Windows.Controls.ContextMenu;
                if (contextMenu == null)
                {
                    contextMenu = System.Windows.LogicalTreeHelper.GetParent(menuItem) as System.Windows.Controls.ContextMenu;
                }
                if (contextMenu != null && contextMenu.PlacementTarget is DataGridRow row && row.DataContext is ServiceItem clickedItem)
                {
                    string category = clickedItem.Category;
                    int count = 0;
                    foreach (var service in Services)
                    {
                        if (service.Category == category)
                        {
                            service.IsSelected = false;
                            count++;
                        }
                    }
                    TxtStatus.Text = $"Deselected {count} services in category '{category}'.";
                }
            }
        }

        private async void MenuStartIndividual_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.MenuItem menuItem)
            {
                var contextMenu = menuItem.Parent as System.Windows.Controls.ContextMenu;
                if (contextMenu == null)
                {
                    contextMenu = System.Windows.LogicalTreeHelper.GetParent(menuItem) as System.Windows.Controls.ContextMenu;
                }
                if (contextMenu != null && contextMenu.PlacementTarget is DataGridRow row && row.DataContext is ServiceItem clickedItem)
                {
                    TxtStatus.Text = $"Starting '{clickedItem.Name}'...";
                    bool ok = await Task.Run(() => ServiceControlManager.Start(clickedItem.Name));
                    if (ok)
                    {
                        LoggingService.Log($"Started service '{clickedItem.Name}' via context menu.");
                        TxtStatus.Text = $"Successfully started service '{clickedItem.Name}'.";
                    }
                    else
                    {
                        TxtStatus.Text = $"Failed to start service '{clickedItem.Name}'.";
                    }
                    RefreshServiceStatus(clickedItem);
                }
            }
        }

        private async void MenuStopIndividual_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.MenuItem menuItem)
            {
                var contextMenu = menuItem.Parent as System.Windows.Controls.ContextMenu;
                if (contextMenu == null)
                {
                    contextMenu = System.Windows.LogicalTreeHelper.GetParent(menuItem) as System.Windows.Controls.ContextMenu;
                }
                if (contextMenu != null && contextMenu.PlacementTarget is DataGridRow row && row.DataContext is ServiceItem clickedItem)
                {
                    TxtStatus.Text = $"Stopping '{clickedItem.Name}'...";
                    bool ok = await Task.Run(() => ServiceControlManager.Stop(clickedItem.Name));
                    if (ok)
                    {
                        LoggingService.Log($"Stopped service '{clickedItem.Name}' via context menu.");
                        TxtStatus.Text = $"Successfully stopped service '{clickedItem.Name}'.";
                    }
                    else
                    {
                        TxtStatus.Text = $"Failed to stop service '{clickedItem.Name}'.";
                    }
                    RefreshServiceStatus(clickedItem);
                }
            }
        }
    }
}


