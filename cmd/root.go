package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/coff33ninja/System_optimizer/internal/version"
)

var rootCmd = &cobra.Command{
	Use:   "system-optimizer",
	Short: "Windows 10/11 Optimization Toolkit",
	Long:  "A comprehensive Windows optimization toolkit with Go TUI and PowerShell modules.",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("System Optimizer %s\n", version.Version)
		fmt.Println("Run without arguments to start the TUI.")
	},
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print version information",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Version:    %s\n", version.Version)
		fmt.Printf("Build Date: %s\n", version.BuildDate)
		fmt.Printf("Commit:     %s\n", version.Commit)
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
