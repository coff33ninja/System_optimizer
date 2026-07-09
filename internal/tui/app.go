package tui

import (
	"fmt"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("170")).
			MarginBottom(1)

	menuStyle = lipgloss.NewStyle().
			PaddingLeft(2)

	selectedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("229")).
			Bold(true).
			PaddingLeft(0).
			MarginRight(2)

	helpStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("241")).
			MarginTop(1)
)

type MenuItem struct {
	ID       string
	Label    string
	Module   string
	Function string
	Admin    bool
}

type App struct {
	cursor  int
	choices []MenuItem
	width   int
	height  int
	quit    bool
}

func NewApp() App {
	return App{
		choices: []MenuItem{
			{ID: "run-all", Label: "Run ALL Optimizations", Module: "Core", Function: "Start-AllOptimization"},
			{ID: "full-setup", Label: "Full Setup", Module: "Core", Function: "Start-FullSetup"},
			{ID: "telemetry", Label: "Telemetry", Module: "Telemetry", Function: "Disable-Telemetry"},
			{ID: "services", Label: "Services", Module: "Services", Function: "Show-ServicesMenu"},
			{ID: "bloatware", Label: "Bloatware", Module: "Bloatware", Function: "DebloatBlacklist"},
			{ID: "tasks", Label: "Scheduled Tasks", Module: "Tasks", Function: "Disable-ScheduledTasks"},
			{ID: "registry", Label: "Registry", Module: "Registry", Function: "Set-RegistryOptimizations"},
			{ID: "vbs", Label: "VBS / Memory Integrity", Module: "VBS", Function: "Disable-VBS"},
			{ID: "network", Label: "Network", Module: "Network", Function: "Start-NetworkMenu"},
			{ID: "onedrive", Label: "OneDrive", Module: "OneDrive", Function: "Remove-OneDrive"},
			{ID: "maintenance", Label: "Maintenance", Module: "Maintenance", Function: "Start-MaintenanceMenu"},
			{ID: "software", Label: "Software Install", Module: "Software", Function: "Start-PatchMyPC"},
			{ID: "office", Label: "Office Tool Plus", Module: "Software", Function: "Start-OfficeTool"},
			{ID: "activation", Label: "MAS Activation", Module: "Software", Function: "Start-MAS"},
			{ID: "wifi", Label: "Wi-Fi Passwords", Module: "Utilities", Function: "Get-WifiPasswords"},
			{ID: "verify", Label: "Verify Status", Module: "Utilities", Function: "Test-OptimizationStatus"},
			{ID: "power", Label: "Power Plan", Module: "Power", Function: "Set-PowerPlan"},
			{ID: "shutup10", Label: "O&O ShutUp10", Module: "Privacy", Function: "Start-OOShutUp10"},
			{ID: "updates", Label: "Windows Update", Module: "WindowsUpdate", Function: "Set-WindowsUpdateControl"},
			{ID: "drivers", Label: "Driver Management", Module: "Drivers", Function: "Start-SnappyDriverInstaller"},
			{ID: "repair-updates", Label: "Repair Updates", Module: "WindowsUpdate", Function: "Repair-WindowsUpdate"},
			{ID: "full-debloat", Label: "Full Debloat", Module: "Bloatware", Function: "DebloatAll"},
			{ID: "winutil", Label: "WinUtil Sync", Module: "Services", Function: "Sync-WinUtilServices"},
			{ID: "privacy-tweaks", Label: "Privacy Tweaks", Module: "UITweaks", Function: "Start-DISMStyleTweaks"},
			{ID: "image-tool", Label: "Image Tool", Module: "ImageTool", Function: "Start-ImageToolMenu"},
			{ID: "antivirus", Label: "Antivirus", Module: "Antivirus", Function: "Show-AntivirusMenu"},
			{ID: "defender", Label: "Defender Control", Module: "Security", Function: "Set-DefenderControl"},
			{ID: "shutdown", Label: "Shutdown Options", Module: "Shutdown", Function: "Show-ShutdownMenu"},
			{ID: "backup", Label: "Profile Backup", Module: "Backup", Function: "Show-UserBackupMenu"},
			{ID: "rollback", Label: "Undo / Rollback", Module: "Rollback", Function: "Show-RollbackMenu"},
			{ID: "hardware", Label: "Hardware Detection", Module: "Hardware", Function: "Show-HardwareSummary"},
			{ID: "profiles", Label: "Optimization Profiles", Module: "Profiles", Function: "Show-ProfileMenu"},
		},
	}
}

func (m App) Init() tea.Cmd {
	return nil
}

func (m App) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			m.quit = true
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.choices)-1 {
				m.cursor++
			}
		case "enter":
		choice := m.choices[m.cursor]
			return m, tea.Printf("Selected: %s (%s)\n", choice.Label, choice.Module)
		}
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	}
	return m, nil
}

func (m App) View() string {
	if m.quit {
		return ""
	}

	s := titleStyle.Render("SYSTEM OPTIMIZER v" + "2.0.0-dev")
	s += "\n"

	for i, choice := range m.choices {
		cursor := "  "
		if m.cursor == i {
			cursor = selectedStyle.Render("> ")
			s += menuStyle.Render(cursor + choice.Label + "\n")
		} else {
			s += menuStyle.Render(cursor + choice.Label + "\n")
		}
	}

	s += helpStyle.Render(fmt.Sprintf("\n  %d items | j/k: navigate | enter: select | q: quit", len(m.choices)))
	return s
}
