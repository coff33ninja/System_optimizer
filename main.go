package main

import (
	"os"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/coff33ninja/System_optimizer/internal/config"
	"github.com/coff33ninja/System_optimizer/internal/tui"
)

func main() {
	if err := config.EnsureDirs(); err != nil {
		os.Exit(1)
	}

	p := tea.NewProgram(tui.NewApp(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		os.Exit(1)
	}
}
