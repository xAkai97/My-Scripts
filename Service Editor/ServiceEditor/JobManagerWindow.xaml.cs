using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Windows;
using ServiceEditor.Models;
using ServiceEditor.Services;

namespace ServiceEditor
{
    public partial class JobManagerWindow : Wpf.Ui.Controls.FluentWindow
    {
        private readonly ConfigData _configData;
        private bool _isUpdatingUI = false;

        public JobManagerWindow(ConfigData config)
        {
            InitializeComponent();
            _configData = config;
            
            if (_configData.Jobs == null)
            {
                _configData.Jobs = new List<MonitoringJob>();
            }

            LoadJobs();
            LoadAvailableServices();
        }

        private void LoadJobs()
        {
            LstJobs.ItemsSource = null;
            LstJobs.ItemsSource = _configData.Jobs;
        }

        private void LoadAvailableServices()
        {
            var serviceNames = _configData.Services.Select(s => s.Name).OrderBy(n => n).ToList();
            LstServices.ItemsSource = serviceNames;
        }

        private void LstJobs_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
        {
            if (LstJobs.SelectedItem is MonitoringJob job)
            {
                _isUpdatingUI = true;
                
                GridDetails.IsEnabled = true;
                TxtJobName.Text = job.Name;
                TxtExecutable.Text = job.LinkedExecutable;
                NumDelay.Value = job.ShutdownDelaySeconds;
                ChkAutoStart.IsChecked = job.AutoStartStop;
                ChkToasts.IsChecked = job.EnableToasts;

                LstServices.SelectedItems.Clear();
                foreach (var svc in job.ServiceNames)
                {
                    if (LstServices.Items.Contains(svc))
                    {
                        LstServices.SelectedItems.Add(svc);
                    }
                }
                
                _isUpdatingUI = false;
            }
            else
            {
                GridDetails.IsEnabled = false;
                TxtJobName.Text = "";
                TxtExecutable.Text = "";
                NumDelay.Value = 0;
                LstServices.SelectedItems.Clear();
            }
        }

        private void JobData_Changed(object sender, RoutedEventArgs e)
        {
            UpdateCurrentJob();
        }

        private void NumDelay_ValueChanged(object sender, RoutedEventArgs e)
        {
            UpdateCurrentJob();
        }

        private void UpdateCurrentJob()
        {
            if (_isUpdatingUI) return;
            if (LstJobs.SelectedItem is MonitoringJob job)
            {
                job.Name = TxtJobName.Text;
                job.LinkedExecutable = TxtExecutable.Text;
                job.ShutdownDelaySeconds = (int)(NumDelay.Value ?? 0);
                job.AutoStartStop = ChkAutoStart.IsChecked ?? false;
                job.EnableToasts = ChkToasts.IsChecked ?? false;
                
                job.ServiceNames.Clear();
                foreach (string svc in LstServices.SelectedItems)
                {
                    job.ServiceNames.Add(svc);
                }

                // Refresh ListBox item name
                LstJobs.Items.Refresh();
            }
        }

        private void BtnAddJob_Click(object sender, RoutedEventArgs e)
        {
            var newJob = new MonitoringJob();
            _configData.Jobs.Add(newJob);
            LoadJobs();
            LstJobs.SelectedItem = newJob;
        }

        private void BtnDeleteJob_Click(object sender, RoutedEventArgs e)
        {
            if (LstJobs.SelectedItem is MonitoringJob job)
            {
                var result = System.Windows.MessageBox.Show($"Are you sure you want to delete job '{job.Name}'?", "Confirm Delete", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (result == MessageBoxResult.Yes)
                {
                    _configData.Jobs.Remove(job);
                    LoadJobs();
                }
            }
        }

        private void BtnStartJob_Click(object sender, RoutedEventArgs e)
        {
            if (LstJobs.SelectedItem is MonitoringJob job)
            {
                int started = 0;
                foreach (var svcName in job.ServiceNames)
                {
                    if (ServiceControlManager.GetStatus(svcName) != "Running")
                    {
                        if (ServiceControlManager.Start(svcName)) started++;
                    }
                }
                System.Windows.MessageBox.Show($"Started {started} services for job '{job.Name}'.", "Job Started", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void BtnShortcut_Click(object sender, RoutedEventArgs e)
        {
            if (LstJobs.SelectedItem is MonitoringJob job)
            {
                try
                {
                    string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                    string shortcutPath = Path.Combine(desktopPath, $"{job.Name}.lnk");
                    string exePath = Process.GetCurrentProcess().MainModule?.FileName ?? "";

                    if (string.IsNullOrEmpty(exePath)) throw new Exception("Could not find current executable path.");

                    Type? t = Type.GetTypeFromProgID("WScript.Shell");
                    if (t == null) throw new Exception("WScript.Shell is not available.");

                    dynamic? shell = Activator.CreateInstance(t);
                    if (shell == null) throw new Exception("Failed to create WScript.Shell instance.");

                    var shortcut = shell.CreateShortcut(shortcutPath);
                    shortcut.TargetPath = exePath;
                    shortcut.Arguments = $"-LaunchJob \"{job.Id}\"";
                    shortcut.WorkingDirectory = Path.GetDirectoryName(exePath);
                    shortcut.Description = $"Launch ServiceEditor Job: {job.Name}";
                    shortcut.Save();

                    System.Windows.MessageBox.Show($"Shortcut created successfully on your Desktop: {job.Name}.lnk", "Success", MessageBoxButton.OK, MessageBoxImage.Information);
                }
                catch (Exception ex)
                {
                    System.Windows.MessageBox.Show($"Failed to create shortcut: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void BtnSave_Click(object sender, RoutedEventArgs e)
        {
            ConfigService.Save(_configData);
            DialogResult = true;
            Close();
        }

        private void BtnCancel_Click(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }
    }
}
