using System;
using System.IO;
using System.Windows;
using ServiceEditor.Services;

namespace ServiceEditor
{
    public partial class LogViewerWindow : Wpf.Ui.Controls.FluentWindow
    {
        public LogViewerWindow()
        {
            InitializeComponent();
            LoadLogs();
        }

        private void LoadLogs()
        {
            try
            {
                string logPath = LoggingService.GetLogFilePath();
                if (File.Exists(logPath))
                {
                    // Open with FileShare.ReadWrite so we can read it even if the app is currently writing to it
                    using (var fs = new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                    using (var sr = new StreamReader(fs))
                    {
                        TxtLogs.Text = sr.ReadToEnd();
                    }
                    TxtLogs.ScrollToEnd();
                }
                else
                {
                    TxtLogs.Text = "No logs found yet.";
                }
            }
            catch (Exception ex)
            {
                TxtLogs.Text = $"Error reading logs: {ex.Message}";
            }
        }

        private void BtnRefresh_Click(object sender, RoutedEventArgs e)
        {
            LoadLogs();
        }

        private void BtnClear_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                string logPath = LoggingService.GetLogFilePath();
                if (File.Exists(logPath))
                {
                    File.WriteAllText(logPath, "");
                }
                LoadLogs();
                LoggingService.Log("Logs cleared by user.");
                LoadLogs(); // Reload to show the clear message
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show($"Could not clear logs: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }
}
