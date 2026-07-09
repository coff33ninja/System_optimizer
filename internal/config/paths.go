package config

import (
	"os"
	"path/filepath"
)

const (
	BaseDir     = `C:\System_Optimizer`
	ModulesDir  = BaseDir + `\modules`
	LogsDir     = BaseDir + `\logs`
	ConfigDir   = BaseDir + `\config`
	TempDir     = BaseDir + `\temp`
	ConfigFile  = ConfigDir + `\settings.json`
	ModulesJSON = ModulesDir + `\modules.json`
)

func EnsureDirs() error {
	dirs := []string{BaseDir, ModulesDir, LogsDir, ConfigDir, TempDir}
	for _, d := range dirs {
		if err := os.MkdirAll(d, 0755); err != nil {
			return err
		}
	}
	return nil
}

func ModulePath(name string) string {
	return filepath.Join(ModulesDir, name+".psm1")
}
