using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;

namespace ServiceEditor.Services
{
    public static class RegistryBackupService
    {
        private static string GetBackupDirectory()
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string backupDir = Path.Combine(baseDir, "Backups");
            if (!Directory.Exists(backupDir))
            {
                Directory.CreateDirectory(backupDir);
            }
            return backupDir;
        }

        public static string GetBackupFilePath(string serviceName)
        {
            // Sanitize service name for file system
            string safeName = string.Join("_", serviceName.Split(Path.GetInvalidFileNameChars()));
            return Path.Combine(GetBackupDirectory(), $"{safeName}_Backup.reg");
        }

        public static bool HasBackup(string serviceName)
        {
            return File.Exists(GetBackupFilePath(serviceName));
        }

        public static async Task<bool> BackupServiceAsync(string serviceName)
        {
            try
            {
                string backupPath = GetBackupFilePath(serviceName);
                string registryKey = $@"HKLM\SYSTEM\CurrentControlSet\Services\{serviceName}";

                // reg.exe export requires elevation to export HKLM, but we already self-elevate on start.
                // Output format: reg export <key> <file> /y
                var processInfo = new ProcessStartInfo
                {
                    FileName = "reg.exe",
                    Arguments = $"export \"{registryKey}\" \"{backupPath}\" /y",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };

                using var process = Process.Start(processInfo);
                if (process != null)
                {
                    await process.WaitForExitAsync();
                    if (process.ExitCode == 0)
                    {
                        LoggingService.Log($"Successfully created registry backup for '{serviceName}' at {backupPath}");
                        return true;
                    }
                    else
                    {
                        string err = await process.StandardError.ReadToEndAsync();
                        LoggingService.Log($"Failed to backup registry for '{serviceName}': {err}");
                        return false;
                    }
                }
                return false;
            }
            catch (Exception ex)
            {
                LoggingService.Log($"Exception backing up '{serviceName}': {ex.Message}");
                return false;
            }
        }

        public static async Task<bool> RestoreServiceAsync(string serviceName, string backupPath)
        {
            try
            {
                if (!File.Exists(backupPath))
                {
                    LoggingService.Log($"Cannot restore '{serviceName}', no backup found at {backupPath}");
                    return false;
                }

                var processInfo = new ProcessStartInfo
                {
                    FileName = "reg.exe",
                    Arguments = $"import \"{backupPath}\"",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };

                using var process = Process.Start(processInfo);
                if (process != null)
                {
                    await process.WaitForExitAsync();
                    if (process.ExitCode == 0)
                    {
                        LoggingService.Log($"Successfully restored registry for '{serviceName}' from {backupPath}");
                        return true;
                    }
                    else
                    {
                        string err = await process.StandardError.ReadToEndAsync();
                        LoggingService.Log($"Failed to restore registry for '{serviceName}': {err}");
                        return false;
                    }
                }
                return false;
            }
            catch (Exception ex)
            {
                LoggingService.Log($"Exception restoring '{serviceName}': {ex.Message}");
                return false;
            }
        }
    }
}
