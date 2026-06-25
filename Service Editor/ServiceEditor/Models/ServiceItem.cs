using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Linq;

namespace ServiceEditor.Models
{
    public class ServiceItem : INotifyPropertyChanged
    {
        private bool _isSelected = false;
        private string _name = string.Empty;
        private string _startupType = "Manual";
        private string? _originalStartupType = null;
        private bool _enabled = true;
        private string _category = "Uncategorized";
        private List<string> _linkedPrograms = new List<string>();
        private string _currentStatus = "Unknown";
        private string _currentStartupType = "Unknown";
        private bool _isMismatched = false;
        private string _mismatchSeverity = "None";

        [Newtonsoft.Json.JsonIgnore]
        public string MismatchSeverity
        {
            get => _mismatchSeverity;
            set { _mismatchSeverity = value; OnPropertyChanged(); }
        }

        [Newtonsoft.Json.JsonIgnore]
        public bool IsMismatched
        {
            get => _isMismatched;
            set { _isMismatched = value; OnPropertyChanged(); }
        }

        [Newtonsoft.Json.JsonIgnore]
        public bool IsSelected
        {
            get => _isSelected;
            set { _isSelected = value; OnPropertyChanged(); }
        }

        public string Name
        {
            get => _name;
            set { _name = value; OnPropertyChanged(); }
        }

        public string StartupType
        {
            get => _startupType;
            set { _startupType = value; OnPropertyChanged(); }
        }

        [Newtonsoft.Json.JsonIgnore]
        public string? OriginalStartupType
        {
            get => _originalStartupType;
            set { _originalStartupType = value; OnPropertyChanged(); }
        }

        public bool Enabled
        {
            get => _enabled;
            set { _enabled = value; OnPropertyChanged(); }
        }

        public string Category
        {
            get => _category;
            set { _category = value; OnPropertyChanged(); }
        }

        public List<string> LinkedPrograms
        {
            get => _linkedPrograms;
            set { _linkedPrograms = value; OnPropertyChanged(); OnPropertyChanged(nameof(LinkedProgramsString)); }
        }

        [Newtonsoft.Json.JsonIgnore]
        public string LinkedProgramsString
        {
            get => string.Join(", ", _linkedPrograms);
            set
            {
                if (string.IsNullOrWhiteSpace(value))
                {
                    _linkedPrograms = new List<string>();
                }
                else
                {
                    _linkedPrograms = value.Split(new[] { ',' }, System.StringSplitOptions.RemoveEmptyEntries)
                                           .Select(s => s.Trim())
                                           .ToList();
                }
                OnPropertyChanged();
                OnPropertyChanged(nameof(LinkedPrograms));
            }
        }

        private List<string> _dependsOn = new List<string>();
        public List<string> DependsOn
        {
            get => _dependsOn;
            set { _dependsOn = value; OnPropertyChanged(); }
        }

        private List<string> _requiredBy = new List<string>();
        public List<string> RequiredBy
        {
            get => _requiredBy;
            set { _requiredBy = value; OnPropertyChanged(); }
        }

        [Newtonsoft.Json.JsonIgnore]
        public string CurrentStatus
        {
            get => _currentStatus;
            set { _currentStatus = value; OnPropertyChanged(); }
        }

        [Newtonsoft.Json.JsonIgnore]
        public string CurrentStartupType
        {
            get => _currentStartupType;
            set { _currentStartupType = value; OnPropertyChanged(); }
        }



        private string _serviceLocation = "Unknown";

        [Newtonsoft.Json.JsonIgnore]
        public string ServiceLocation
        {
            get => _serviceLocation;
            set { _serviceLocation = value; OnPropertyChanged(); }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
