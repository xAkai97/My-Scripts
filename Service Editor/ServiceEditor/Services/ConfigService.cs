using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using ServiceEditor.Models;

namespace ServiceEditor.Services
{
    public static class ConfigService
    {
        private static string? _cachedConfigPath;

        public static string GetConfigPath()
        {
            if (_cachedConfigPath != null)
                return _cachedConfigPath;

            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string fileName = "services-config.json";

            _cachedConfigPath = Path.Combine(baseDir, fileName);
            return _cachedConfigPath;
        }

        public static ConfigData GetDefaultConfig()
        {
            return new ConfigData();
        }

        public static ConfigData Load()
        {
            string path = GetConfigPath();
            if (!File.Exists(path))
            {
                var defaultConfig = GetDefaultConfig();
                Save(defaultConfig);
                return defaultConfig;
            }

            try
            {
                string json = File.ReadAllText(path);
                var data = JsonConvert.DeserializeObject<ConfigData>(json) ?? GetDefaultConfig();
                if (data.Categories != null)
                {
                    data.Categories = data.Categories.Distinct().ToList();
                }
                return data;
            }
            catch
            {
                return GetDefaultConfig();
            }
        }

        public static bool Save(ConfigData data)
        {
            try
            {
                string path = GetConfigPath();
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
