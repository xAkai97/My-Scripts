using System;
using System.IO;

namespace ServiceEditor.Services
{
    public static class LoggingService
    {
        private static string? _logFilePath;
        private static readonly object _lock = new();

        public static string GetLogFilePath()
        {
            if (_logFilePath != null)
                return _logFilePath;

            // Put the log in the same folder as the config file
            string configPath = ConfigService.GetConfigPath();
            string? dir = Path.GetDirectoryName(configPath);
            _logFilePath = Path.Combine(dir ?? AppDomain.CurrentDomain.BaseDirectory, "service-history.log");
            return _logFilePath;
        }

        public static void Log(string message)
        {
            try
            {
                string path = GetLogFilePath();
                string timestampedMsg = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {message}";
                lock (_lock)
                {
                    if (File.Exists(path))
                    {
                        var fi = new FileInfo(path);
                        if (fi.Length > 5 * 1024 * 1024) // 5 MB
                        {
                            RotateLogs(path);
                        }
                    }
                    File.AppendAllText(path, timestampedMsg + Environment.NewLine);
                }
            }
            catch {}
        }

        private static void RotateLogs(string basePath)
        {
            try
            {
                // Max 3 backups
                int maxBackups = 3;
                for (int i = maxBackups - 1; i >= 1; i--)
                {
                    string oldFile = basePath.Replace(".log", $".{i}.log");
                    string newFile = basePath.Replace(".log", $".{i + 1}.log");
                    if (File.Exists(oldFile))
                    {
                        if (File.Exists(newFile)) File.Delete(newFile);
                        File.Move(oldFile, newFile);
                    }
                }
                
                string firstBackup = basePath.Replace(".log", ".1.log");
                if (File.Exists(firstBackup)) File.Delete(firstBackup);
                File.Move(basePath, firstBackup);
            }
            catch {}
        }

    }
}
