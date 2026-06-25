using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.ServiceProcess;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using ServiceEditor.Models;
using ServiceEditor.Services;

namespace ServiceEditor
{
    public class ScannedServiceItem : INotifyPropertyChanged
    {
        private string _name = string.Empty;
        private string _displayName = string.Empty;
        private string _status = string.Empty;
        private bool _isAdded;

        public string Name
        {
            get => _name;
            set { _name = value; OnPropertyChanged(); }
        }

        public string DisplayName
        {
            get => _displayName;
            set { _displayName = value; OnPropertyChanged(); }
        }

        public string Status
        {
            get => _status;
            set { _status = value; OnPropertyChanged(); }
        }

        public bool IsAdded
        {
            get => _isAdded;
            set 
            { 
                _isAdded = value; 
                OnPropertyChanged(); 
                OnPropertyChanged(nameof(IsNotAdded)); 
            }
        }

        public bool IsNotAdded => !IsAdded;

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }

    public partial class ServiceScanWindow : Wpf.Ui.Controls.FluentWindow
    {
        private readonly ObservableCollection<ServiceItem> _mainServices;
        private readonly ConfigData _configData;
        public ObservableCollection<ScannedServiceItem> ScannedServices { get; set; } = new();

        public ServiceScanWindow(ObservableCollection<ServiceItem> mainServices, ConfigData configData)
        {
            _mainServices = mainServices;
            _configData = configData;

            InitializeComponent();
            DataContext = this;

            ScanGrid.ItemsSource = ScannedServices;
            LoadWindowsServices();
        }

        private void LoadWindowsServices()
        {
            ScannedServices.Clear();
            var services = ServiceController.GetServices();
            
            foreach (var sc in services.OrderBy(s => s.DisplayName))
            {
                bool isAdded = _mainServices.Any(s => s.Name.Equals(sc.ServiceName, StringComparison.OrdinalIgnoreCase));
                ScannedServices.Add(new ScannedServiceItem
                {
                    Name = sc.ServiceName,
                    DisplayName = sc.DisplayName,
                    Status = sc.Status.ToString(),
                    IsAdded = isAdded
                });
            }

            UpdateStats();
            RefreshView();
        }

        private void UpdateStats()
        {
            TxtTotal.Text = ScannedServices.Count.ToString();
            TxtAdded.Text = ScannedServices.Count(s => s.IsAdded).ToString();
        }

        private void RefreshView()
        {
            var view = CollectionViewSource.GetDefaultView(ScannedServices);
            view.Refresh();
        }

        private void BtnRefresh_Click(object sender, RoutedEventArgs e)
        {
            LoadWindowsServices();
        }

        private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            string filterText = SearchBox.Text;
            ICollectionView view = CollectionViewSource.GetDefaultView(ScannedServices);
            
            if (string.IsNullOrEmpty(filterText))
            {
                view.Filter = null;
            }
            else
            {
                view.Filter = obj =>
                {
                    if (obj is ScannedServiceItem item)
                    {
                        return item.Name.Contains(filterText, StringComparison.OrdinalIgnoreCase) || 
                               item.DisplayName.Contains(filterText, StringComparison.OrdinalIgnoreCase);
                    }
                    return false;
                };
            }
        }

        private void BtnAddService_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn && btn.DataContext is ScannedServiceItem item)
            {
                if (!item.IsAdded)
                {
                    // Create new ServiceItem
                    var newItem = new ServiceItem
                    {
                        Name = item.Name,
                        StartupType = ServiceControlManager.GetStartupType(item.Name),
                        OriginalStartupType = ServiceControlManager.GetStartupType(item.Name),
                        Category = "Uncategorized",
                        Enabled = true
                    };
                    
                    // Add to Main Window
                    _mainServices.Add(newItem);
                    _configData.Services.Add(newItem);
                    
                    // Save Config
                    ConfigService.Save(_configData);

                    // Update UI state
                    item.IsAdded = true;
                    UpdateStats();
                }
            }
        }

        private void BtnRemoveService_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn && btn.DataContext is ScannedServiceItem item)
            {
                if (item.IsAdded)
                {
                    // Find and remove from main services
                    var mainItem = _mainServices.FirstOrDefault(s => s.Name.Equals(item.Name, StringComparison.OrdinalIgnoreCase));
                    if (mainItem != null)
                    {
                        _mainServices.Remove(mainItem);
                        _configData.Services.Remove(mainItem);
                        
                        // Save Config
                        ConfigService.Save(_configData);

                        // Update UI state
                        item.IsAdded = false;
                        UpdateStats();
                    }
                }
            }
        }
    }
}
