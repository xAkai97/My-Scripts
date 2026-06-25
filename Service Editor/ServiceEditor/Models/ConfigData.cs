using System.Collections.Generic;
using Newtonsoft.Json;

namespace ServiceEditor.Models
{
    public class ConfigData
    {
        [JsonProperty("categories", ObjectCreationHandling = ObjectCreationHandling.Replace)]
        public List<string> Categories { get; set; } = new List<string> { "Uncategorized", "Network/VPN", "Utility", "Gaming", "Peripherals", "Virtualization" };

        [JsonProperty("services")]
        public List<ServiceItem> Services { get; set; } = new List<ServiceItem>();

        [JsonProperty("jobs")]
        public List<MonitoringJob> Jobs { get; set; } = new List<MonitoringJob>();
    }
}
