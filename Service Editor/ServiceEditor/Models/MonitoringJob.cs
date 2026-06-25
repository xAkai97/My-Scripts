using System;
using System.Collections.Generic;

namespace ServiceEditor.Models
{
    public class MonitoringJob
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string Name { get; set; } = "New Job";
        public string LinkedExecutable { get; set; } = string.Empty;
        public List<string> ServiceNames { get; set; } = new List<string>();
        public int ShutdownDelaySeconds { get; set; } = 0;
        public bool EnableToasts { get; set; } = true;
        public bool AutoStartStop { get; set; } = true;

        public override string ToString()
        {
            return Name;
        }
    }
}
