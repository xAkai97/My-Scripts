using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using ServiceEditor.Models;
using ServiceEditor.Services;

namespace ServiceEditor.Utils
{
    public class SystemTrayManager : IDisposable
    {
        private readonly NotifyIcon _notifyIcon;
        private readonly MainWindow _mainWindow;

        public SystemTrayManager(MainWindow mainWindow)
        {
            _mainWindow = mainWindow;
            
            _notifyIcon = new NotifyIcon
            {
                Icon = SystemIcons.Shield, // Looks like a modern app/shield icon
                Text = "Windows Service Editor",
                Visible = true
            };

            _notifyIcon.DoubleClick += (s, e) => ToggleWindow();
            UpdateMenu();
        }

        public void UpdateMenu()
        {
            try
            {
                var menu = new ContextMenuStrip();

                // Header
                var header = new ToolStripMenuItem("Windows Service Editor") { Enabled = false };
                header.Font = new Font(header.Font, FontStyle.Bold);
                menu.Items.Add(header);
                menu.Items.Add(new ToolStripSeparator());

                // Add each enabled service
                var enabledServices = _mainWindow.Services.Where(s => s.Enabled).ToList();
                if (enabledServices.Count > 0)
                {
                    foreach (var item in enabledServices)
                    {
                        bool isRunning = item.CurrentStatus == "Running";
                        string statusMark = isRunning ? "●" : "○";
                        var itemMenu = new ToolStripMenuItem($"{statusMark} {item.Name}");
                        itemMenu.Font = new Font(itemMenu.Font, isRunning ? FontStyle.Bold : FontStyle.Regular);
                        
                        // Toggle service click action
                        itemMenu.Click += (s, e) =>
                        {
                            if (isRunning)
                            {
                                ServiceControlManager.Stop(item.Name);
                                LoggingService.Log($"Stopped service '{item.Name}' via System Tray.");
                            }
                            else
                            {
                                ServiceControlManager.Start(item.Name);
                                LoggingService.Log($"Started service '{item.Name}' via System Tray.");
                            }
                            
                            // Re-trigger GUI refresh
                            _mainWindow.Dispatcher.Invoke(async () => {
                                await _mainWindow.RefreshAllStatusesAsync();
                            });
                        };

                        menu.Items.Add(itemMenu);
                    }
                    menu.Items.Add(new ToolStripSeparator());
                }

                // Show/Hide
                string showHideText = _mainWindow.IsVisible ? "Minimize to Tray" : "Restore Dashboard";
                var showHideItem = new ToolStripMenuItem(showHideText);
                showHideItem.Click += (s, e) => ToggleWindow();
                menu.Items.Add(showHideItem);

                // Exit
                var exitItem = new ToolStripMenuItem("Exit Editor");
                exitItem.Click += (s, e) =>
                {
                    _mainWindow.ShutdownApp();
                };
                menu.Items.Add(exitItem);

                _notifyIcon.ContextMenuStrip = menu;
            }
            catch {}
        }

        private void ToggleWindow()
        {
            _mainWindow.Dispatcher.Invoke(() =>
            {
                if (_mainWindow.IsVisible)
                {
                    _mainWindow.Hide();
                }
                else
                {
                    _mainWindow.Show();
                    _mainWindow.WindowState = System.Windows.WindowState.Normal;
                    _mainWindow.Activate();
                }
                UpdateMenu();
            });
        }

        public void Dispose()
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }
    }
}
