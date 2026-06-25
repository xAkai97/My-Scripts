using System.Windows;

namespace ServiceEditor
{
    public partial class CloseDialogWindow : Wpf.Ui.Controls.FluentWindow
    {
        public string SelectedBehavior { get; private set; } = "Ask";
        
        public enum CloseAction { Minimize, Exit, Cancel }
        public CloseAction Result { get; private set; } = CloseAction.Cancel;

        public CloseDialogWindow()
        {
            InitializeComponent();
        }

        private void BtnMinimize_Click(object sender, RoutedEventArgs e)
        {
            if (ChkRemember.IsChecked == true) SelectedBehavior = "Minimize";
            else SelectedBehavior = "Ask";
            
            Result = CloseAction.Minimize;
            Close();
        }

        private void BtnExit_Click(object sender, RoutedEventArgs e)
        {
            if (ChkRemember.IsChecked == true) SelectedBehavior = "Exit";
            else SelectedBehavior = "Ask";

            Result = CloseAction.Exit;
            Close();
        }
    }
}
