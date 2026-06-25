using System.Reflection;
using System.Windows;

namespace ServiceEditor
{
    public partial class AboutWindow : Wpf.Ui.Controls.FluentWindow
    {
        public AboutWindow()
        {
            InitializeComponent();
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            TxtVersion.Text = $"Version {version?.ToString() ?? "1.0.0"}";
        }

        private void BtnClose_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }
    }
}
