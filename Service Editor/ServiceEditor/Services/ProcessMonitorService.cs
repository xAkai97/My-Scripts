using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Management;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using ServiceEditor.Models;
using ServiceEditor.Utils;

namespace ServiceEditor.Services
{
    public class ProcessMonitorService : IDisposable
    {
        private ManagementEventWatcher? _creationWatcher;
        private ManagementEventWatcher? _deletionWatcher;
        private readonly ConfigData _config;
        private readonly Action<string> _onStatusChange;
        private bool _disposed = false;
        
        // Thread-safe dictionary for tracking cancellation tokens/timers for delayed job shutdowns
        private readonly ConcurrentDictionary<string, CancellationTokenSource> _shutdownTimers = new();

        public ProcessMonitorService(ConfigData config, Action<string> onStatusChange)
        {
            _config = config;
            _onStatusChange = onStatusChange;
        }

        public void Start()
        {
            try
            {
                var creationQuery = new WqlEventQuery("__InstanceCreationEvent", new TimeSpan(0, 0, 1), "TargetInstance ISA 'Win32_Process'");
                _creationWatcher = new ManagementEventWatcher(creationQuery);
                _creationWatcher.EventArrived += CreationWatcher_EventArrived;
                _creationWatcher.Start();

                var deletionQuery = new WqlEventQuery("__InstanceDeletionEvent", new TimeSpan(0, 0, 1), "TargetInstance ISA 'Win32_Process'");
                _deletionWatcher = new ManagementEventWatcher(deletionQuery);
                _deletionWatcher.EventArrived += DeletionWatcher_EventArrived;
                _deletionWatcher.Start();
                
                LoggingService.Log("Process monitor background service started.");
            }
            catch (Exception ex)
            {
                LoggingService.Log($"Failed to start process monitor: {ex.Message}");
            }
        }

        public void Stop()
        {
            try
            {
                if (_creationWatcher != null)
                {
                    _creationWatcher.Stop();
                    _creationWatcher.Dispose();
                    _creationWatcher = null;
                }
                if (_deletionWatcher != null)
                {
                    _deletionWatcher.Stop();
                    _deletionWatcher.Dispose();
                    _deletionWatcher = null;
                }
                
                // Cancel any pending shutdowns
                foreach (var kvp in _shutdownTimers)
                {
                    kvp.Value.Cancel();
                    kvp.Value.Dispose();
                }
                _shutdownTimers.Clear();

                LoggingService.Log("Process monitor background service stopped.");
            }
            catch {}
        }

        private void CreationWatcher_EventArrived(object sender, EventArrivedEventArgs e)
        {
            try
            {
                var targetInstance = (ManagementBaseObject)e.NewEvent["TargetInstance"];
                string procName = targetInstance["Name"]?.ToString() ?? "";
                if (string.IsNullOrEmpty(procName)) return;

                // 1. Check backward compatible LinkedPrograms
                var matchedServices = _config.Services
                    .Where(s => s.Enabled && s.LinkedPrograms != null && s.LinkedPrograms.Contains(procName, StringComparer.OrdinalIgnoreCase))
                    .ToList();

                foreach (var svc in matchedServices)
                {
                    if (ServiceControlManager.GetStatus(svc.Name) != "Running")
                    {
                        LoggingService.Log($"Automation: Process '{procName}' launched. Starting service '{svc.Name}'...");
                        if (ServiceControlManager.Start(svc.Name)) _onStatusChange?.Invoke(svc.Name);
                    }
                }

                // 2. Check Jobs
                if (_config.Jobs != null)
                {
                    var matchedJobs = _config.Jobs.Where(j => j.AutoStartStop && string.Equals(j.LinkedExecutable, procName, StringComparison.OrdinalIgnoreCase)).ToList();
                    foreach (var job in matchedJobs)
                    {
                        // Cancel any pending shutdown for this job
                        if (_shutdownTimers.TryRemove(job.Id, out var existingCts))
                        {
                            existingCts.Cancel();
                            existingCts.Dispose();
                            LoggingService.Log($"Job '{job.Name}': Process reopened, cancelled pending shutdown.");
                        }

                        int startedCount = 0;
                        foreach (string svcName in job.ServiceNames)
                        {
                            if (ServiceControlManager.GetStatus(svcName) != "Running")
                            {
                                if (ServiceControlManager.Start(svcName))
                                {
                                    startedCount++;
                                    _onStatusChange?.Invoke(svcName);
                                }
                            }
                        }

                        if (startedCount > 0)
                        {
                            LoggingService.Log($"Job '{job.Name}': Started {startedCount} services because {procName} launched.");
                            if (job.EnableToasts)
                            {
                                ToastHelper.ShowToast("Job Started", $"Job '{job.Name}' started {startedCount} services.", ToolTipIcon.Info);
                            }
                        }
                    }
                }
            }
            catch {}
        }

        private void DeletionWatcher_EventArrived(object sender, EventArrivedEventArgs e)
        {
            try
            {
                var targetInstance = (ManagementBaseObject)e.NewEvent["TargetInstance"];
                string procName = targetInstance["Name"]?.ToString() ?? "";
                if (string.IsNullOrEmpty(procName)) return;

                // Check if process actually has no more instances
                string nameOnly = procName.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) 
                    ? procName[..^4] 
                    : procName;
                bool anyRunning = Process.GetProcessesByName(nameOnly).Length > 0;
                if (anyRunning) return; // Still instances running

                // 1. Check backward compatible LinkedPrograms
                var matchedServices = _config.Services
                    .Where(s => s.Enabled && s.LinkedPrograms != null && s.LinkedPrograms.Contains(procName, StringComparer.OrdinalIgnoreCase))
                    .ToList();

                foreach (var svc in matchedServices)
                {
                    if (ServiceControlManager.GetStatus(svc.Name) == "Running")
                    {
                        LoggingService.Log($"Automation: All '{procName}' terminated. Stopping service '{svc.Name}'...");
                        if (ServiceControlManager.Stop(svc.Name)) _onStatusChange?.Invoke(svc.Name);
                    }
                }

                // 2. Check Jobs
                if (_config.Jobs != null)
                {
                    var matchedJobs = _config.Jobs.Where(j => j.AutoStartStop && string.Equals(j.LinkedExecutable, procName, StringComparison.OrdinalIgnoreCase)).ToList();
                    foreach (var job in matchedJobs)
                    {
                        if (job.ShutdownDelaySeconds > 0)
                        {
                            LoggingService.Log($"Job '{job.Name}': Process closed. Scheduling shutdown in {job.ShutdownDelaySeconds} seconds.");
                            if (job.EnableToasts)
                            {
                                ToastHelper.ShowToast("Job Shutdown Pending", $"Job '{job.Name}' will stop in {job.ShutdownDelaySeconds} seconds.", ToolTipIcon.Info);
                            }
                            ScheduleJobShutdown(job);
                        }
                        else
                        {
                            ExecuteJobShutdown(job);
                        }
                    }
                }
            }
            catch {}
        }

        private void ScheduleJobShutdown(MonitoringJob job)
        {
            var cts = new CancellationTokenSource();
            _shutdownTimers[job.Id] = cts;

            Task.Run(async () =>
            {
                try
                {
                    await Task.Delay(job.ShutdownDelaySeconds * 1000, cts.Token);
                    
                    // If we get here without throwing, timer finished
                    _shutdownTimers.TryRemove(job.Id, out _);
                    ExecuteJobShutdown(job);
                }
                catch (TaskCanceledException)
                {
                    // Shutdown was cancelled — process was reopened
                }
            });
        }

        private void ExecuteJobShutdown(MonitoringJob job)
        {
            int stoppedCount = 0;
            foreach (string svcName in job.ServiceNames)
            {
                if (ServiceControlManager.GetStatus(svcName) == "Running")
                {
                    if (ServiceControlManager.Stop(svcName))
                    {
                        stoppedCount++;
                        _onStatusChange?.Invoke(svcName);
                    }
                }
            }

            if (stoppedCount > 0)
            {
                LoggingService.Log($"Job '{job.Name}': Stopped {stoppedCount} services.");
                if (job.EnableToasts)
                {
                    ToastHelper.ShowToast("Job Stopped", $"Job '{job.Name}' stopped {stoppedCount} services.", ToolTipIcon.Info);
                }
            }
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                Stop();
                _disposed = true;
            }
        }
    }
}
