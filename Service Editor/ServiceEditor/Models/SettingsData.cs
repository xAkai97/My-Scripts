using System.Collections.Generic;
using Newtonsoft.Json;

namespace ServiceEditor.Models
{
    public class SettingsData
    {
        [JsonProperty("closeBehavior")]
        public string CloseBehavior { get; set; } = "Ask"; // "Ask", "Minimize", "Exit"

        [JsonProperty("runOnStartup")]
        public bool RunOnStartup { get; set; } = false;

        [JsonProperty("enableGlobalToasts")]
        public bool EnableGlobalToasts { get; set; } = true;

        [JsonProperty("autoBackupNewServices")]
        public bool AutoBackupNewServices { get; set; } = false;

        [JsonProperty("theme")]
        public string Theme { get; set; } = "Auto"; // "Auto", "Dark", "Light", "Pure Dark"

        [JsonProperty("windowWidth")]
        public double WindowWidth { get; set; } = 1100;

        [JsonProperty("windowHeight")]
        public double WindowHeight { get; set; } = 680;

        [JsonProperty("isMaximized")]
        public bool IsMaximized { get; set; } = false;

        [JsonProperty("columnWidths")]
        public Dictionary<string, string> ColumnWidths { get; set; } = new Dictionary<string, string>();

        [JsonProperty("columnVisibility")]
        public Dictionary<string, bool> ColumnVisibility { get; set; } = new Dictionary<string, bool>();

        [JsonProperty("columnDisplayIndex")]
        public Dictionary<string, int> ColumnDisplayIndex { get; set; } = new Dictionary<string, int>();
    }
}
