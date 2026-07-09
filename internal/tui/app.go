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

	breadcrumbStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("241")).
			MarginBottom(1)

	menuItemStyle = lipgloss.NewStyle().
			PaddingLeft(2)

	selectedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("229")).
			Bold(true)

	helpStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("241")).
			MarginTop(1)

	confirmStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("62")).
			Padding(1, 2).
			MarginTop(1)

	statusOK = lipgloss.NewStyle().Foreground(lipgloss.Color("42"))
	statusErr = lipgloss.NewStyle().Foreground(lipgloss.Color("196"))
)

type MenuItemType int

const (
	ActionItem  MenuItemType = iota
	SubmenuItem
)

type MenuItem struct {
	ID       string
	Label    string
	Type     MenuItemType
	Module   string
	Function string
	Admin    bool
	Children []MenuItem
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
	state    viewState
	cursor   int
	stack    []menuFrame
	choices  []MenuItem
	width    int
	height   int
	quit     bool
	confirm  bool

	mgr      *modules.Manager
	executor *modules.Executor
	psVer    string
	hasPS7   bool
	status   string
	statusOK bool
}

type menuFrame struct {
	title  string
	items  []MenuItem
	cursor int
}

func NewApp() App {
	psVer, _ := system.DetectPSVersion()
	hasPS7 := system.HasPS7()

	mgr := modules.NewManager(config.ModulesDir)
	mgr.Init()

	executor := modules.NewExecutor(mgr.FindPowershell())

	mainMenu := buildMainMenu()

	return App{
		state: stateMenu,
		stack: []menuFrame{{title: "Main Menu", items: mainMenu}},
		mgr:   mgr,
		executor: executor,
		psVer:  psVer,
		hasPS7: hasPS7,
	}
}

func buildMainMenu() []MenuItem {
	return []MenuItem{
		{ID: "run-all", Label: "Run ALL Optimizations", Type: ActionItem, Module: "Core", Function: "Start-AllOptimization"},
		{ID: "full-setup", Label: "Full Setup", Type: ActionItem, Module: "Core", Function: "Start-FullSetup"},
		{ID: "core", Label: "Core Optimizations", Type: SubmenuItem, Children: []MenuItem{
			{ID: "telemetry", Label: "Telemetry", Type: ActionItem, Module: "Telemetry", Function: "Disable-Telemetry"},
			{ID: "services", Label: "Services", Type: SubmenuItem, Module: "Services", Children: []MenuItem{
				{ID: "services-menu", Label: "Services Menu", Type: ActionItem, Module: "Services", Function: "Show-ServicesMenu"},
				{ID: "services-winutil", Label: "WinUtil Sync", Type: ActionItem, Module: "Services", Function: "Sync-WinUtilServices"},
			}},
			{ID: "bloatware", Label: "Bloatware", Type: SubmenuItem, Module: "Bloatware", Children: []MenuItem{
				{ID: "bloatware-blacklist", Label: "Debloat (Blacklist)", Type: ActionItem, Module: "Bloatware", Function: "DebloatBlacklist"},
				{ID: "bloatware-all", Label: "Full Debloat", Type: ActionItem, Module: "Bloatware", Function: "DebloatAll"},
			}},
			{ID: "tasks", Label: "Scheduled Tasks", Type: ActionItem, Module: "Tasks", Function: "Disable-ScheduledTasks"},
			{ID: "registry", Label: "Registry", Type: ActionItem, Module: "Registry", Function: "Set-RegistryOptimizations"},
			{ID: "vbs", Label: "VBS / Memory Integrity", Type: ActionItem, Module: "VBS", Function: "Disable-VBS"},
			{ID: "network", Label: "Network", Type: ActionItem, Module: "Network", Function: "Start-NetworkMenu"},
			{ID: "onedrive", Label: "OneDrive", Type: ActionItem, Module: "OneDrive", Function: "Remove-OneDrive"},
			{ID: "maintenance", Label: "Maintenance", Type: ActionItem, Module: "Maintenance", Function: "Start-MaintenanceMenu"},
		}},
		{ID: "software", Label: "Software & Tools", Type: SubmenuItem, Children: []MenuItem{
			{ID: "software-install", Label: "Software Install", Type: ActionItem, Module: "Software", Function: "Start-PatchMyPC"},
			{ID: "office", Label: "Office Tool Plus", Type: ActionItem, Module: "Software", Function: "Start-OfficeTool"},
			{ID: "activation", Label: "MAS Activation", Type: ActionItem, Module: "Software", Function: "Start-MAS"},
			{ID: "wifi", Label: "Wi-Fi Passwords", Type: ActionItem, Module: "Utilities", Function: "Get-WifiPasswords"},
			{ID: "verify", Label: "Verify Status", Type: ActionItem, Module: "Utilities", Function: "Test-OptimizationStatus"},
		}},
		{ID: "advanced", Label: "Advanced", Type: SubmenuItem, Children: []MenuItem{
			{ID: "power", Label: "Power Plan", Type: ActionItem, Module: "Power", Function: "Set-PowerPlan"},
			{ID: "shutup10", Label: "O&O ShutUp10", Type: ActionItem, Module: "Privacy", Function: "Start-OOShutUp10"},
			{ID: "updates", Label: "Windows Update", Type: SubmenuItem, Module: "WindowsUpdate", Children: []MenuItem{
				{ID: "updates-control", Label: "Update Control", Type: ActionItem, Module: "WindowsUpdate", Function: "Set-WindowsUpdateControl"},
				{ID: "updates-repair", Label: "Repair Updates", Type: ActionItem, Module: "WindowsUpdate", Function: "Repair-WindowsUpdate"},
			}},
			{ID: "drivers", Label: "Driver Management", Type: ActionItem, Module: "Drivers", Function: "Start-SnappyDriverInstaller"},
			{ID: "privacy-tweaks", Label: "Privacy Tweaks", Type: ActionItem, Module: "UITweaks", Function: "Start-DISMStyleTweaks"},
			{ID: "image-tool", Label: "Image Tool", Type: ActionItem, Module: "ImageTool", Function: "Start-ImageToolMenu"},
		}},
		{ID: "management", Label: "Management", Type: SubmenuItem, Children: []MenuItem{
			{ID: "antivirus", Label: "Antivirus", Type: SubmenuItem, Module: "Antivirus", Children: []MenuItem{
				{ID: "av-eset", Label: "ESET Install", Type: SubmenuItem, Module: "Antivirus", Children: []MenuItem{
					{ID: "eset-eav", Label: "ESET Antivirus", Type: ActionItem, Module: "Antivirus", Function: "Install-EsetProduct -Product EAV"},
					{ID: "eset-eis", Label: "ESET Internet Security", Type: ActionItem, Module: "Antivirus", Function: "Install-EsetProduct -Product EIS"},
					{ID: "eset-essp", Label: "ESET Premium", Type: ActionItem, Module: "Antivirus", Function: "Install-EsetProduct -Product ESSP"},
					{ID: "eset-esu", Label: "ESET Ultimate", Type: ActionItem, Module: "Antivirus", Function: "Install-EsetProduct -Product ESU"},
					{ID: "eset-esbs", Label: "ESET Smart Security", Type: ActionItem, Module: "Antivirus", Function: "Install-EsetProduct -Product ESBS"},
					{ID: "eset-essv", Label: "ESET Security", Type: ActionItem, Module: "Antivirus", Function: "Install-EsetProduct -Product ESSV"},
					{ID: "eset-compare", Label: "Compare Products", Type: ActionItem, Module: "Antivirus", Function: "Show-EsetComparison"},
				}},
				{ID: "defender", Label: "Defender Control", Type: ActionItem, Module: "Security", Function: "Set-DefenderControl"},
				{ID: "av-scan", Label: "Installed AV Products", Type: ActionItem, Module: "Antivirus", Function: "Get-InstalledAvProducts"},
			}},
			{ID: "shutdown", Label: "Shutdown Options", Type: ActionItem, Module: "Shutdown", Function: "Show-ShutdownMenu"},
			{ID: "backup", Label: "Profile Backup", Type: ActionItem, Module: "Backup", Function: "Show-UserBackupMenu"},
			{ID: "rollback", Label: "Undo / Rollback", Type: ActionItem, Module: "Rollback", Function: "Show-RollbackMenu"},
			{ID: "hardware", Label: "Hardware Detection", Type: ActionItem, Module: "Hardware", Function: "Show-HardwareSummary"},
			{ID: "profiles", Label: "Optimization Profiles", Type: ActionItem, Module: "Profiles", Function: "Show-ProfileMenu"},
		}},
	}
}

func (m App) currentFrame() menuFrame {
	return m.stack[len(m.stack)-1]
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
	frame := m.currentFrame()

	switch msg.String() {
	case "ctrl+c":
		m.quit = true
		return m, tea.Quit

	case "q":
		if len(m.stack) <= 1 {
			m.quit = true
			return m, tea.Quit
		}
		return m, m.goBack()

	case "esc":
		if m.state == stateConfirm {
			m.state = stateMenu
			return m, nil
		}
		if len(m.stack) > 1 {
			return m, m.goBack()
		}
		return m, nil

	case "up", "k":
		if m.state == stateConfirm {
			m.confirm = !m.confirm
		} else {
			if frame.cursor > 0 {
				frame.cursor--
				m.stack[len(m.stack)-1] = frame
			}
		}

	case "down", "j":
		if m.state == stateConfirm {
			m.confirm = !m.confirm
		} else {
			if frame.cursor < len(frame.items)-1 {
				frame.cursor++
				m.stack[len(m.stack)-1] = frame
			}
		}

	case "enter":
		if m.state == stateConfirm {
			if m.confirm {
				m.state = stateExecuting
				item := frame.items[frame.cursor]
				return m, m.executeModule(item)
			}
			m.state = stateMenu
			return m, nil
		}

		item := frame.items[frame.cursor]
		if item.Type == SubmenuItem {
			m.stack = append(m.stack, menuFrame{
				title: item.Label,
				items: item.Children,
			})
			return m, nil
		}

		m.state = stateConfirm
		m.confirm = true
		m.stack[len(m.stack)-1] = frame
		return m, nil

	case "y":
		if m.state == stateConfirm && m.confirm {
			m.state = stateExecuting
			item := frame.items[frame.cursor]
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

func (m App) goBack() tea.Cmd {
	return func() tea.Msg {
		if len(m.stack) > 1 {
			m.stack = m.stack[:len(m.stack)-1]
		}
		return statusMsg{text: ""}
	}
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

	breadcrumb := ""
	for i, f := range m.stack {
		if i > 0 {
			breadcrumb += " > "
		}
		breadcrumb += f.title
	}
	s += breadcrumbStyle.Render(breadcrumb) + "\n"

	frame := m.currentFrame()

	if m.state == stateExecuting {
		s += "\n  Launching PowerShell...\n"
		s += helpStyle.Render("  (interact with the PowerShell menu, then return here)")
		return s
	}

	for i, item := range frame.items {
		cursor := "  "
		label := item.Label
		if item.Type == SubmenuItem {
			label += "/"
		}
		if m.state == stateConfirm && i == frame.cursor {
			if m.confirm {
				cursor = selectedStyle.Render("> ")
			} else {
				cursor = "  "
			}
		} else if i == frame.cursor {
			cursor = selectedStyle.Render("> ")
		}
		s += menuItemStyle.Render(cursor+label) + "\n"
	}

	if m.state == stateConfirm {
		item := frame.items[frame.cursor]
		confirmText := fmt.Sprintf("Run %s?", item.Label)
		if m.confirm {
			confirmText += "\n  [Y]es  n"
		} else {
			confirmText += "\n  y  [N]o"
		}
		s += confirmStyle.Render(confirmText) + "\n"
	}

	help := "  j/k: navigate  enter: select  "
	if len(m.stack) > 1 {
		help += "esc: back  "
	}
	help += "q: quit"
	s += helpStyle.Render(help)

	return s
}
