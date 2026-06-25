using System;
using System.Drawing;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace ServiceEditor.Utils
{
    public static class ToastHelper
    {
        public static void ShowToast(string title, string message, ToolTipIcon icon = ToolTipIcon.Info)
        {
            try
            {
                // Fire and forget — avoid blocking the calling thread
                Task.Run(async () =>
                {
                    using var notifyIcon = new NotifyIcon
                    {
                        Icon = SystemIcons.Information,
                        Visible = true
                    };
                    notifyIcon.ShowBalloonTip(5000, title, message, icon);
                    await Task.Delay(5000);
                    notifyIcon.Visible = false;
                });
            }
            catch {}
        }
    }
}
