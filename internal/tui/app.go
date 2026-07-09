package tui

import (
	"fmt"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/coff33ninja/System_optimizer/internal/config"
	"github.com/coff33ninja/System_optimizer/internal/modules"
	"github.com/coff33ninja/System_optimizer/internal/system"
)

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("170")).
			MarginBottom(1)

	headerStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("241")).
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

	statusOK = lipgloss.NewStyle().Foreground(lipgloss.Color("42"))
	statusWarn = lipgloss.NewStyle().Foreground(lipgloss.Color("214"))
)

type MenuItem struct {
	ID       string
	Label    string
	Module   string
	Function string
	Admin    bool
}

type statusMsg struct {
	text string
	err  error
}

type App struct {
	cursor  int
	choices []MenuItem
	width   int
	height  int
	quit    bool

	mgr      *modules.Manager
	executor *modules.Executor
	psVer    string
	hasPS7   bool
	status   string
	exec     bool
}

func NewApp() App {
	psVer, _ := system.DetectPSVersion()
	hasPS7 := system.HasPS7()

	mgr := modules.NewManager(config.ModulesDir)
	mgr.Init()

	executor := modules.NewExecutor(mgr.FindPowershell())

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
		mgr:      mgr,
		executor: executor,
		psVer:    psVer,
		hasPS7:   hasPS7,
	}
}

func (m App) Init() tea.Cmd {
	return nil
}

func (m App) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if m.exec {
			return m, nil
		}
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
			return m, m.executeModule(choice)
		}
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case statusMsg:
		m.exec = false
		if msg.err != nil {
			m.status = fmt.Sprintf("Error: %v", msg.err)
		} else {
			m.status = msg.text
		}
	}
	return m, nil
}

func (m App) executeModule(item MenuItem) tea.Cmd {
	return func() tea.Msg {
		path, err := m.mgr.EnsureModule(item.Module)
		if err != nil {
			return statusMsg{err: fmt.Errorf("download %s: %w", item.Module, err)}
		}

		if err := m.executor.RunFunction(path, item.Function); err != nil {
			return statusMsg{err: fmt.Errorf("run %s: %w", item.Function, err)}
		}
		return statusMsg{text: fmt.Sprintf("Completed: %s", item.Label)}
	}
}

func (m App) View() string {
	if m.quit {
		return ""
	}

	arch := system.DetectArch()
	header := fmt.Sprintf("SYSTEM OPTIMIZER v2.0.0-dev  |  %s  |  PS %s", arch, m.psVer)
	if m.hasPS7 {
		header += "  |  PS7 available"
	}

	s := titleStyle.Render(header) + "\n"

	if m.status != "" {
		s += statusOK.Render(m.status) + "\n"
		m.status = ""
	}

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
