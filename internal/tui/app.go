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

	sectionHeader = lipgloss.NewStyle().
			Foreground(lipgloss.Color("241")).
			Bold(true)

	menuItemStyle = lipgloss.NewStyle().
			PaddingLeft(2)

	selectedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("229")).
			Bold(true)

	normalStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("252"))

	grayStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("241"))

	helpStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("241")).
			MarginTop(1)

	confirmStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("62")).
			Padding(1, 2).
			MarginTop(1)

	statusOK   = lipgloss.NewStyle().Foreground(lipgloss.Color("42"))
	statusErr  = lipgloss.NewStyle().Foreground(lipgloss.Color("196"))
)

type MenuItem struct {
	Num      string
	Label    string
	Module   string
	Function string
}

var menuItems = []MenuItem{
	{Num: "1", Label: "Run ALL Optimizations", Module: "Core", Function: "Run-AllOptimizations"},
	{Num: "2", Label: "Disable Telemetry", Module: "Telemetry", Function: "Disable-Telemetry"},
	{Num: "3", Label: "Disable Services", Module: "Services", Function: "Show-ServicesMenu"},
	{Num: "4", Label: "Remove Bloatware", Module: "Bloatware", Function: "DebloatBlacklist"},
	{Num: "5", Label: "Disable Scheduled Tasks", Module: "Tasks", Function: "Disable-ScheduledTasks"},
	{Num: "6", Label: "Registry Optimizations", Module: "Registry", Function: "Set-RegistryOptimizations"},
	{Num: "7", Label: "Disable VBS/Memory", Module: "VBS", Function: "Disable-VBS"},
	{Num: "8", Label: "Network Tools", Module: "Network", Function: "Start-NetworkMenu"},
	{Num: "9", Label: "Remove OneDrive", Module: "OneDrive", Function: "Remove-OneDrive"},
	{Num: "10", Label: "Maintenance Tools", Module: "Maintenance", Function: "Start-MaintenanceMenu"},
	{Num: "11", Label: "Software Install", Module: "Software", Function: "Start-PatchMyPC"},
	{Num: "12", Label: "Office Tool Plus", Module: "Software", Function: "Start-OfficeTool"},
	{Num: "13", Label: "MAS Activation", Module: "Software", Function: "Start-MAS"},
	{Num: "14", Label: "Wi-Fi Passwords", Module: "Utilities", Function: "Get-WifiPasswords"},
	{Num: "15", Label: "Verify Status", Module: "Utilities", Function: "Test-OptimizationStatus"},
	{Num: "16", Label: "Full Setup", Module: "Core", Function: "Run-FullSetup"},
	{Num: "17", Label: "Power Plan", Module: "Power", Function: "Set-PowerPlan"},
	{Num: "18", Label: "O&O ShutUp10", Module: "Privacy", Function: "Start-OOShutUp10"},
	{Num: "19", Label: "Windows Update", Module: "WindowsUpdate", Function: "Set-WindowsUpdateControl"},
	{Num: "20", Label: "Driver Management", Module: "Drivers", Function: "Start-SnappyDriverInstaller"},
	{Num: "21", Label: "Repair Updates", Module: "WindowsUpdate", Function: "Repair-WindowsUpdate"},
	{Num: "22", Label: "Defender Control", Module: "Security", Function: "Set-DefenderControl"},
	{Num: "23", Label: "Full Debloat", Module: "Bloatware", Function: "DebloatAll"},
	{Num: "24", Label: "WinUtil Sync", Module: "Services", Function: "Sync-WinUtilServices"},
	{Num: "25", Label: "Privacy Tweaks", Module: "UITweaks", Function: "Start-DISMStyleTweaks"},
	{Num: "26", Label: "Image Tool", Module: "ImageTool", Function: "Start-ImageToolMenu"},
	{Num: "27", Label: "View Logs", Module: "Utilities", Function: "Show-LogViewer"},
	{Num: "28", Label: "Profile Backup", Module: "Backup", Function: "Show-UserBackupMenu"},
	{Num: "29", Label: "Shutdown Options", Module: "Shutdown", Function: "Show-ShutdownMenu"},
	{Num: "30", Label: "VHD Native Boot", Module: "VHDDeploy", Function: "Start-VHDMenu"},
	{Num: "31", Label: "Windows Installer", Module: "Installer", Function: "Start-InstallerMenu"},
	{Num: "32", Label: "Undo/Rollback", Module: "Rollback", Function: "Show-RollbackMenu"},
	{Num: "33", Label: "Hardware Detection", Module: "Hardware", Function: "Show-HardwareSummary"},
	{Num: "34", Label: "Optimization Profiles", Module: "Profiles", Function: "Show-ProfileMenu"},
	{Num: "35", Label: "Antivirus", Module: "Antivirus", Function: "Show-AntivirusMenu"},
	{Num: "W", Label: "First-Run Warning", Module: "Warning", Function: "Show-FirstRunWarning"},
}

type viewState int

const (
	stateMenu viewState = iota
	stateConfirm
	stateExecuting
)

type statusMsg struct {
	text string
	err  error
}

type App struct {
	state   viewState
	cursor  int
	width   int
	height  int
	quit    bool
	confirm bool

	mgr      *modules.Manager
	executor *modules.Executor
	psVer    string
	hasPS7   bool
	status   string
	statusOK bool
}

func NewApp() App {
	psVer, _ := system.DetectPSVersion()
	hasPS7 := system.HasPS7()

	mgr := modules.NewManager(config.ModulesDir)
	mgr.Init()

	executor := modules.NewExecutor(mgr.FindPowershell())

	return App{
		state:    stateMenu,
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
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case statusMsg:
		m.state = stateMenu
		if msg.err != nil {
			m.status = fmt.Sprintf("Error: %v", msg.err)
			m.statusOK = false
		} else {
			m.status = msg.text
			m.statusOK = true
		}
		return m, nil

	case tea.KeyMsg:
		if m.state == stateExecuting {
			return m, nil
		}
		return m.handleKey(msg)
	}
	return m, nil
}

func (m App) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		m.quit = true
		return m, tea.Quit

	case "q", "0":
		if m.state == stateConfirm {
			m.state = stateMenu
			return m, nil
		}
		m.quit = true
		return m, tea.Quit

	case "esc":
		if m.state == stateConfirm {
			m.state = stateMenu
			return m, nil
		}

	case "up", "k":
		if m.state == stateConfirm {
			m.confirm = !m.confirm
		} else {
			if m.cursor > 0 {
				m.cursor--
			}
		}

	case "down", "j":
		if m.state == stateConfirm {
			m.confirm = !m.confirm
		} else {
			if m.cursor < len(menuItems)-1 {
				m.cursor++
			}
		}

	case "enter":
		if m.state == stateConfirm {
			if m.confirm {
				m.state = stateExecuting
				item := menuItems[m.cursor]
				return m, m.executeModule(item)
			}
			m.state = stateMenu
			return m, nil
		}
		m.state = stateConfirm
		m.confirm = true
		return m, nil

	case "y":
		if m.state == stateConfirm && m.confirm {
			m.state = stateExecuting
			item := menuItems[m.cursor]
			return m, m.executeModule(item)
		}

	case "n":
		if m.state == stateConfirm {
			m.state = stateMenu
			return m, nil
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
		header += "  |  PS7"
	}
	s := titleStyle.Render(header) + "\n"

	if m.status != "" {
		if m.statusOK {
			s += statusOK.Render(m.status) + "\n"
		} else {
			s += statusErr.Render(m.status) + "\n"
		}
		m.status = ""
	}

	s += "\n"

	_ = []int{0, 15}
	coreCol := []int{1, 2, 3, 4, 5, 6, 7, 8, 9}
	softwareCol := []int{10, 11, 12, 13, 14}
	advCol := []int{16, 17, 18, 19, 20}
	mgmtCol := []int{26, 27, 28, 29, 30, 31, 32, 33}
	singleItems := []int{21, 22, 34}

	s += sectionHeader.Render("  Quick Actions:") + "\n"
	s += m.renderFullItem(0)
	s += m.renderFullItem(15)
	s += "\n"

	s += sectionHeader.Render("  Core Optimizations:           Software & Tools:") + "\n"
	for i := 0; i < len(coreCol) && i < len(softwareCol); i++ {
		left := m.renderCompactItem(coreCol[i])
		right := m.renderCompactItem(softwareCol[i])
		s += left + right + "\n"
	}
	s += "\n"

	s += sectionHeader.Render("  Advanced Tools:               Management:") + "\n"
	for i := 0; i < len(advCol) && i < len(mgmtCol); i++ {
		left := m.renderCompactItem(advCol[i])
		right := m.renderCompactItem(mgmtCol[i])
		s += left + right + "\n"
	}
	s += "\n"

	for _, idx := range singleItems {
		s += m.renderCompactItem(idx)
		s += "\n"
	}

	s += helpStyle.Render("  [?] Help  |  [W] Warning  |  j/k: navigate  |  enter: select  |  q: quit")

	return s
}

func (m App) renderFullItem(idx int) string {
	if idx >= len(menuItems) {
		return ""
	}
	item := menuItems[idx]
	cursor := "  "
	if m.state == stateConfirm && m.cursor == idx {
		cursor = selectedStyle.Render("> ")
	} else if m.cursor == idx {
		cursor = selectedStyle.Render("> ")
	}
	return menuItemStyle.Render(cursor+item.Num+". "+item.Label) + "\n"
}

func (m App) renderCompactItem(idx int) string {
	if idx >= len(menuItems) {
		return ""
	}
	item := menuItems[idx]
	cursor := " "
	if m.cursor == idx {
		cursor = selectedStyle.Render(">")
	}
	num := grayStyle.Render(fmt.Sprintf("[%s]", item.Num))
	text := normalStyle.Render(item.Label)

	pad := 38 - len(item.Num) - len(item.Label) - 4
	if pad < 1 {
		pad = 1
	}
	spaces := ""
	for i := 0; i < pad; i++ {
		spaces += " "
	}

	return menuItemStyle.Render(cursor + num + " " + text + spaces)
}
