using System;
using System.Diagnostics;
using System.Linq;
using System.Security.Principal;
using System.Threading;
using System.Windows;
using System.Windows.Forms;
using ServiceEditor.Services;
using ServiceEditor.Utils;

namespace ServiceEditor
{
    public partial class App : System.Windows.Application
    {
        private static Mutex? _mutex;

        public App()
        {
            AppDomain.CurrentDomain.UnhandledException += (s, ev) => 
            {
                System.IO.File.AppendAllText(System.IO.Path.Combine(System.IO.Path.GetTempPath(), "ServiceEditor_Crash.log"), $"[{DateTime.Now}] Unhandled: {ev.ExceptionObject}\n");
            };
            DispatcherUnhandledException += (s, ev) => 
            {
                System.IO.File.AppendAllText(System.IO.Path.Combine(System.IO.Path.GetTempPath(), "ServiceEditor_Crash.log"), $"[{DateTime.Now}] Dispatcher: {ev.Exception}\n");
                ev.Handled = true; // prevent immediate crash to see if we can continue
            };
        }

        protected override void OnStartup(StartupEventArgs e)
        {
            // Handle CLI flags
            bool headlessMode = e.Args.Contains("-CheckMismatch", StringComparer.OrdinalIgnoreCase) || 
                               e.Args.Contains("--check-mismatch", StringComparer.OrdinalIgnoreCase);

            string? launchJobId = null;
            for (int i = 0; i < e.Args.Length; i++)
            {
                if (e.Args[i].Equals("-LaunchJob", StringComparison.OrdinalIgnoreCase) && i + 1 < e.Args.Length)
                {
                    launchJobId = e.Args[i + 1];
                    break;
                }
            }

            bool isHeadless = headlessMode || !string.IsNullOrEmpty(launchJobId);

            const string appName = "ServiceEditorSingleInstanceMutex";
            bool createdNew;
            _mutex = new Mutex(true, appName, out createdNew);

            if (!createdNew && !isHeadless)
            {
                var result = System.Windows.MessageBox.Show(
                    "Another instance of Service Editor is already running.\n\nDo you want to forcefully close it and launch a new instance?",
                    "Service Editor is Running",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question);

                if (result == MessageBoxResult.Yes)
                {
                    var currentProcess = Process.GetCurrentProcess();
                    foreach (var process in Process.GetProcessesByName(currentProcess.ProcessName))
                    {
                        if (process.Id != currentProcess.Id)
                        {
                            try { process.Kill(); process.WaitForExit(2000); } catch { }
                        }
                    }
                    // Try to recreate mutex after killing
                    try
                    {
                        if (_mutex != null) { _mutex.Dispose(); _mutex = null; }
                        _mutex = new Mutex(true, appName, out createdNew);
                    }
                    catch { }
                }
                else
                {
                    Shutdown();
                    return;
                }
            }

            base.OnStartup(e);

            if (!IsRunningAsAdmin())
            {
                if (_mutex != null && createdNew)
                {
                    _mutex.ReleaseMutex();
                    _mutex.Dispose();
                    _mutex = null;
                }
                Elevate(e.Args);
                Shutdown();
                return;
            }

            if (!string.IsNullOrEmpty(launchJobId))
            {
                RunJobHeadless(launchJobId);
                // Exit after launching job headless
                Shutdown();
                return;
            }

            if (headlessMode)
            {
                RunMismatchCheckHeadless();
                Shutdown();
            }
            else
            {
                // GUI Mode - Create and show MainWindow programmatically
                var mainWindow = new MainWindow();
                mainWindow.Show();
            }
        }

        private bool IsRunningAsAdmin()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }

        private void Elevate(string[] args)
        {
            string? exePath = Environment.ProcessPath;
            
            // If running via "dotnet run", ProcessPath is dotnet.exe. We need the actual built executable.
            if (exePath != null && exePath.EndsWith("dotnet.exe", StringComparison.OrdinalIgnoreCase))
            {
                string? assemblyLocation = System.Reflection.Assembly.GetEntryAssembly()?.Location;
                if (!string.IsNullOrEmpty(assemblyLocation))
                {
                    // Assuming the .exe is next to the .dll
                    if (assemblyLocation.EndsWith(".dll", StringComparison.OrdinalIgnoreCase))
                    {
                        exePath = assemblyLocation.Substring(0, assemblyLocation.Length - 4) + ".exe";
                    }
                    else
                    {
                        exePath = assemblyLocation;
                    }
                }
            }

            if (string.IsNullOrEmpty(exePath) || !System.IO.File.Exists(exePath)) 
            {
                return;
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = exePath,
                UseShellExecute = true,
                Verb = "runas",
                WorkingDirectory = Environment.CurrentDirectory
            };

            // Pass command line arguments through
            if (args.Length > 0)
            {
                startInfo.Arguments = string.Join(" ", args);
            }

            try
            {
                Process.Start(startInfo);
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show($"Administrator privileges are required to run this Service Management Tool. Failed to elevate: {ex.Message}", 
                    "Elevation Required", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private void RunMismatchCheckHeadless()
        {
            LoggingService.Log("[Headless Run] Initiating background Mismatch check...");
            var config = ConfigService.Load();
            if (config.Services == null || config.Services.Count == 0)
            {
                LoggingService.Log("[Headless Run] No services configured. Exiting.");
                return;
            }

            var MismatchedList = new System.Collections.Generic.List<string>();

            foreach (var item in config.Services)
            {
                if (!item.Enabled) continue;

                string currentType = ServiceControlManager.GetStartupType(item.Name);
                if (!string.Equals(item.StartupType, currentType, StringComparison.OrdinalIgnoreCase))
                {
                    MismatchedList.Add($"{item.Name} ({currentType}, set to {item.StartupType})");
                }
            }

            if (MismatchedList.Count > 0)
            {
                string msg = string.Join(", ", MismatchedList);
                LoggingService.Log($"[Headless Run] Mismatch detected for: {msg}");
                
                string toastMsg = MismatchedList.Count == 1 
                    ? $"Mismatch detected: {MismatchedList[0]}" 
                    : $"Mismatch detected for {MismatchedList.Count} services: {string.Join(", ", MismatchedList.Take(3))}...";
                
                ToastHelper.ShowToast("Service Config Mismatched", toastMsg, ToolTipIcon.Warning);
            }
            else
            {
                LoggingService.Log("[Headless Run] No Mismatch detected. All service configurations match.");
            }
        }
        private void RunJobHeadless(string jobId)
        {
            var config = ConfigService.Load();
            var job = config.Jobs?.FirstOrDefault(j => string.Equals(j.Id, jobId, StringComparison.OrdinalIgnoreCase) || string.Equals(j.Name, jobId, StringComparison.OrdinalIgnoreCase));
            
            if (job == null)
            {
                System.Windows.MessageBox.Show($"Could not find Job with ID or Name: {jobId}", "Job Not Found", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            // Start services
            foreach (var svcName in job.ServiceNames)
            {
                if (ServiceControlManager.GetStatus(svcName) != "Running")
                {
                    ServiceControlManager.Start(svcName);
                }
            }

            // Start Executable
            if (!string.IsNullOrEmpty(job.LinkedExecutable))
            {
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = job.LinkedExecutable,
                        UseShellExecute = true
                    });
                }
                catch (Exception ex)
                {
                    System.Windows.MessageBox.Show($"Failed to launch '{job.LinkedExecutable}': {ex.Message}", "Launch Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }
    }
}
