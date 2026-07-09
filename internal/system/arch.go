package system

import (
	"os/exec"
	"runtime"
	"strings"
)

type Arch string

const (
	ArchAMD64 Arch = "amd64"
	ArchARM64 Arch = "arm64"
	ArchX86   Arch = "x86"
)

func DetectArch() Arch {
	switch runtime.GOARCH {
	case "arm64":
		return ArchARM64
	case "386":
		return ArchX86
	default:
		return ArchAMD64
	}
}

func DetectPSVersion() (string, bool) {
	cmd := exec.Command("powershell.exe", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()")
	out, err := cmd.Output()
	if err != nil {
		return "", false
	}
	return strings.TrimSpace(string(out)), true
}

func HasPS7() bool {
	_, err := exec.LookPath("pwsh.exe")
	return err == nil
}
