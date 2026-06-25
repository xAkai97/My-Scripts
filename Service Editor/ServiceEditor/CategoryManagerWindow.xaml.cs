using System.Collections.ObjectModel;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using ServiceEditor.Models;

namespace ServiceEditor
{
    public partial class CategoryManagerWindow : Wpf.Ui.Controls.FluentWindow
    {
        private ConfigData _config;
        private ObservableCollection<ServiceItem> _services;
        private ObservableCollection<string> _categoriesList;

        public CategoryManagerWindow(ConfigData config, ObservableCollection<ServiceItem> services)
        {
            InitializeComponent();
            _config = config;
            _services = services;
            
            _categoriesList = new ObservableCollection<string>(_config.Categories);
            LstCategories.ItemsSource = _categoriesList;
        }

        private void LstCategories_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (LstCategories.SelectedItem is string selectedCategory && selectedCategory != "Uncategorized")
            {
                DetailsPanel.IsEnabled = true;
                TxtRename.Text = selectedCategory;
            }
            else
            {
                // Uncategorized is protected
                DetailsPanel.IsEnabled = false;
                TxtRename.Text = "";
            }
        }

        private void BtnAddCategory_Click(object sender, RoutedEventArgs e)
        {
            string newCat = TxtNewCategory.Text.Trim();
            if (!string.IsNullOrEmpty(newCat) && !_categoriesList.Contains(newCat))
            {
                _categoriesList.Add(newCat);
                _config.Categories.Add(newCat);
                TxtNewCategory.Text = "";
            }
        }

        private void BtnRename_Click(object sender, RoutedEventArgs e)
        {
            if (LstCategories.SelectedItem is string oldName)
            {
                string newName = TxtRename.Text.Trim();
                if (!string.IsNullOrEmpty(newName) && oldName != newName && !_categoriesList.Contains(newName))
                {
                    // Update list
                    int idx = _categoriesList.IndexOf(oldName);
                    _categoriesList[idx] = newName;
                    
                    int configIdx = _config.Categories.IndexOf(oldName);
                    if (configIdx >= 0) _config.Categories[configIdx] = newName;

                    // Update all services using this category
                    foreach (var svc in _services.Where(s => s.Category == oldName))
                    {
                        svc.Category = newName;
                    }
                    
                    LstCategories.SelectedItem = newName;
                }
            }
        }

        private void BtnDelete_Click(object sender, RoutedEventArgs e)
        {
            if (LstCategories.SelectedItem is string catToDelete && catToDelete != "Uncategorized")
            {
                var result = System.Windows.MessageBox.Show($"Are you sure you want to delete '{catToDelete}'? All services in this category will be moved to 'Uncategorized'.", "Confirm Delete", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (result == MessageBoxResult.Yes)
                {
                    _categoriesList.Remove(catToDelete);
                    _config.Categories.Remove(catToDelete);

                    if (!_config.Categories.Contains("Uncategorized"))
                    {
                        _config.Categories.Insert(0, "Uncategorized");
                    }

                    // Move services to Uncategorized
                    foreach (var svc in _services.Where(s => s.Category == catToDelete))
                    {
                        svc.Category = "Uncategorized";
                    }
                }
            }
        }

        private void BtnClose_Click(object sender, RoutedEventArgs e)
        {
            DialogResult = true;
            Close();
        }
    }
}
