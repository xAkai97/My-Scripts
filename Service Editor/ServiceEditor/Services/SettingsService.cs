using System;
using System.IO;
using Newtonsoft.Json;
using ServiceEditor.Models;

namespace ServiceEditor.Services
{
    public static class SettingsService
    {
        private static string? _cachedSettingsPath;

        public static string GetSettingsPath()
        {
            if (_cachedSettingsPath != null)
                return _cachedSettingsPath;

            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string fileName = "app-settings.json";

            _cachedSettingsPath = Path.Combine(baseDir, fileName);
            return _cachedSettingsPath;
        }

        public static SettingsData Load()
        {
            string path = GetSettingsPath();
            if (!File.Exists(path))
            {
                var defaultSettings = new SettingsData();
                Save(defaultSettings);
                return defaultSettings;
            }

            try
            {
                string json = File.ReadAllText(path);
                return JsonConvert.DeserializeObject<SettingsData>(json) ?? new SettingsData();
            }
            catch
            {
                return new SettingsData();
            }
        }

        public static bool Save(SettingsData data)
        {
            try
            {
                string path = GetSettingsPath();
                string json = JsonConvert.SerializeObject(data, Formatting.Indented);
                File.WriteAllText(path, json);
                return true;
            }
            catch
            {
                return false;
            }
        }
    }
}
