using System;
using System.Diagnostics;
using System.ServiceProcess;
using Microsoft.Win32;

namespace ServiceEditor.Services
{
    public static class ServiceControlManager
    {
        public static string GetStatus(string serviceName)
        {
            try
            {
                using (var sc = new ServiceController(serviceName))
                {
                    return sc.Status.ToString();
                }
            }
            catch (InvalidOperationException ex) when (ex.InnerException is System.ComponentModel.Win32Exception w32ex && w32ex.NativeErrorCode == 1060)
            {
                return "NotFound";
            }
            catch (Exception)
            {
                return "Error";
            }
        }

        public static string GetStartupType(string serviceName)
        {
            try
            {
                using (RegistryKey? key = Registry.LocalMachine.OpenSubKey($@"SYSTEM\CurrentControlSet\Services\{serviceName}"))
                {
                    if (key != null)
                    {
                        var startVal = key.GetValue("Start");
                        if (startVal is int startValInt)
                        {
                            if (startValInt == 2)
                            {
                                var delayedVal = key.GetValue("DelayedAutostart");
                                if (delayedVal is int delayedValInt && delayedValInt == 1)
                                {
                                    return "DelayedStart";
                                }
                                return "Automatic";
                            }
                            else if (startValInt == 3)
                            {
                                return "Manual";
                            }
                            else if (startValInt == 4)
                            {
                                return "Disabled";
                            }
                        }
                    }
                }
            }
            catch {}
            return "Unknown";
        }
        public static (System.Collections.Generic.List<string> dependsOn, System.Collections.Generic.List<string> requiredBy) GetDependencies(string serviceName)
        {
            var dependsOn = new System.Collections.Generic.List<string>();
            var requiredBy = new System.Collections.Generic.List<string>();
            try
            {
                using (var sc = new ServiceController(serviceName))
                {
                    foreach (var dep in sc.ServicesDependedOn)
                    {
                        dependsOn.Add(dep.ServiceName);
                    }
                    foreach (var req in sc.DependentServices)
                    {
                        requiredBy.Add(req.ServiceName);
                    }
                }
            }
            catch {}
            return (dependsOn, requiredBy);
        }

        public static bool SetStartupType(string serviceName, string startupType)
        {
            string args = "";
            switch (startupType)
            {
                case "Automatic":
                    args = $"config \"{serviceName}\" start= auto";
                    break;
                case "DelayedStart":
                    args = $"config \"{serviceName}\" start= delayed-auto";
                    break;
                case "Manual":
                    args = $"config \"{serviceName}\" start= demand";
                    break;
                case "Disabled":
                    args = $"config \"{serviceName}\" start= disabled";
                    break;
                default:
                    return false;
            }

            try
            {
                var startInfo = new ProcessStartInfo
                {
                    FileName = "sc.exe",
                    Arguments = args,
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };

                using (var process = Process.Start(startInfo))
                {
                    process?.WaitForExit();
                    return process?.ExitCode == 0;
                }
            }
            catch
            {
                return false;
            }
        }

        public static bool Start(string serviceName)
        {
            try
            {
                using (var sc = new ServiceController(serviceName))
                {
                    if (sc.Status == ServiceControllerStatus.Stopped)
                    {
                        sc.Start();
                        sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(20));
                        return true;
                    }
                }
            }
            catch {}
            return false;
        }

        public static bool Stop(string serviceName)
        {
            try
            {
                using (var sc = new ServiceController(serviceName))
                {
                    if (sc.Status != ServiceControllerStatus.Stopped)
                    {
                        sc.Stop();
                        sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(20));
                        return true;
                    }
                }
            }
            catch {}
            return false;
        }

        public static string GetServiceLocation(string serviceName)
        {
            try
            {
                using (RegistryKey? key = Registry.LocalMachine.OpenSubKey($@"SYSTEM\CurrentControlSet\Services\{serviceName}"))
                {
                    if (key != null)
                    {
                        var pathVal = key.GetValue("ImagePath");
                        if (pathVal != null)
                        {
                            return pathVal.ToString() ?? "Unknown";
                        }
                    }
                }
            }
            catch {}
            return "Unknown";
        }
    }
}
