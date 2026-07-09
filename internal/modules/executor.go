package modules

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type Executor struct {
	psExec string
}

func NewExecutor(psPath string) *Executor {
	if psPath == "" {
		psPath = "powershell.exe"
	}
	return &Executor{psExec: psPath}
}

func (e *Executor) RunFunction(modulePath, functionName string) error {
	cmd := exec.Command(e.psExec,
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-Command", fmt.Sprintf(
			"Import-Module '%s' -Force; %s",
			modulePath, functionName,
		),
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

func (e *Executor) RunScript(scriptPath string, args ...string) error {
	psArgs := append([]string{
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-File", scriptPath,
	}, args...)

	cmd := exec.Command(e.psExec, psArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

func (e *Executor) RunCommand(command string) (string, error) {
	cmd := exec.Command(e.psExec,
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-Command", command,
	)
	out, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

func (e *Executor) RunCommandQuiet(command string) (string, error) {
	cmd := exec.Command(e.psExec,
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-Command", command,
	)
	out, err := cmd.Output()
	return strings.TrimSpace(string(out)), err
}
