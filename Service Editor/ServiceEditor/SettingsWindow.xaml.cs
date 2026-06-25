using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using Microsoft.Win32;
using ServiceEditor.Models;
using ServiceEditor.Services;

namespace ServiceEditor
{
    public partial class SettingsWindow : Wpf.Ui.Controls.FluentWindow
    {
        private ConfigData _config;
        private SettingsData _settings;

        public SettingsWindow(SettingsData settings, ConfigData config)
        {
            InitializeComponent();
            _settings = settings;
            _config = config;
            
            if (_settings.CloseBehavior == "Ask") CmbCloseBehavior.SelectedIndex = 0;
            else if (_settings.CloseBehavior == "Minimize") CmbCloseBehavior.SelectedIndex = 1;
            else CmbCloseBehavior.SelectedIndex = 2;

            ChkRunOnStartup.IsChecked = _settings.RunOnStartup;
            ChkGlobalToasts.IsChecked = _settings.EnableGlobalToasts;
            ChkAutoBackup.IsChecked = _settings.AutoBackupNewServices;
            
            if (string.Equals(_settings.Theme, "Light", StringComparison.OrdinalIgnoreCase)) CmbTheme.SelectedIndex = 1;
            else if (string.Equals(_settings.Theme, "Dark", StringComparison.OrdinalIgnoreCase)) CmbTheme.SelectedIndex = 2;
            else if (string.Equals(_settings.Theme, "Pure Dark", StringComparison.OrdinalIgnoreCase)) CmbTheme.SelectedIndex = 3;
            else CmbTheme.SelectedIndex = 0;

            if (CmbTheme.SelectedIndex == 3)
            {
                WindowBackdropType = Wpf.Ui.Controls.WindowBackdropType.None;
                Background = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(0, 0, 0));
            }
        }

        private void BtnSave_Click(object sender, RoutedEventArgs e)
        {
            if (CmbCloseBehavior.SelectedIndex == 0) _settings.CloseBehavior = "Ask";
            else if (CmbCloseBehavior.SelectedIndex == 1) _settings.CloseBehavior = "Minimize";
            else _settings.CloseBehavior = "Exit";

            _settings.RunOnStartup = ChkRunOnStartup.IsChecked ?? false;
            _settings.EnableGlobalToasts = ChkGlobalToasts.IsChecked ?? true;
            _settings.AutoBackupNewServices = ChkAutoBackup.IsChecked ?? false;
            if (CmbTheme.SelectedIndex == 1) _settings.Theme = "Light";
            else if (CmbTheme.SelectedIndex == 2) _settings.Theme = "Dark";
            else if (CmbTheme.SelectedIndex == 3) _settings.Theme = "Pure Dark";
            else _settings.Theme = "Auto";

            ApplyRunOnStartup(_settings.RunOnStartup);

            DialogResult = true;
            Close();
        }

        private void BtnCancel_Click(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }

        private async void BtnBackupAll_Click(object sender, RoutedEventArgs e)
        {
            int successCount = 0;
            foreach (var svc in _config.Services)
            {
                if (await RegistryBackupService.BackupServiceAsync(svc.Name))
                {
                    successCount++;
                }
            }
            System.Windows.MessageBox.Show($"Successfully backed up {successCount} services.", "Backup Complete", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private async void BtnRestore_Click(object sender, RoutedEventArgs e)
        {
            Microsoft.Win32.OpenFileDialog dlg = new Microsoft.Win32.OpenFileDialog
            {
                Title = "Select Registry Backup File",
                Filter = "Registry Files (*.reg)|*.reg",
                InitialDirectory = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Backups")
            };

            if (dlg.ShowDialog() == true)
            {
                // Guess service name from file name (Format: {safeName}_Backup.reg)
                string fileName = Path.GetFileNameWithoutExtension(dlg.FileName);
                string serviceName = fileName.Replace("_Backup", "");

                var result = System.Windows.MessageBox.Show($"Are you sure you want to restore registry settings for '{serviceName}'?\n\nThis will overwrite the current registry configuration.", "Confirm Restore", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (result == MessageBoxResult.Yes)
                {
                    bool ok = await RegistryBackupService.RestoreServiceAsync(serviceName, dlg.FileName);
                    if (ok) System.Windows.MessageBox.Show("Restore successful.", "Success", MessageBoxButton.OK, MessageBoxImage.Information);
                    else System.Windows.MessageBox.Show("Restore failed. Check logs.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void BtnOpenBackups_Click(object sender, RoutedEventArgs e)
        {
            string backupDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Backups");
            if (!Directory.Exists(backupDir)) Directory.CreateDirectory(backupDir);
            Process.Start("explorer.exe", backupDir);
        }

        private void ApplyRunOnStartup(bool enable)
        {
            try
            {
                using RegistryKey? key = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true);
                if (key != null)
                {
                    if (enable)
                    {
                        string exePath = Process.GetCurrentProcess().MainModule?.FileName ?? "";
                        if (!string.IsNullOrEmpty(exePath))
                        {
                            key.SetValue("ServiceEditor", $"\"{exePath}\" -CheckMismatch");
                        }
                    }
                    else
                    {
                        key.DeleteValue("ServiceEditor", false);
                    }
                }
            }
            catch (Exception ex)
            {
                LoggingService.Log("Failed to set Run on Startup registry key: " + ex.Message);
            }
        }
    }
}
