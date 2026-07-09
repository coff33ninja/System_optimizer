package modules

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/coff33ninja/System_optimizer/internal/download"
)

const (
	rawGitHubBase = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/modules"
)

type Manager struct {
	dl       *download.Client
	cacheDir string
	registry *Registry
}

func NewManager(cacheDir string) *Manager {
	return &Manager{
		dl:       download.NewClient(),
		cacheDir: cacheDir,
	}
}

func (m *Manager) Init() error {
	if err := os.MkdirAll(m.cacheDir, 0755); err != nil {
		return err
	}

	regPath := filepath.Join(m.cacheDir, "modules.json")
	reg, err := LoadRegistry(regPath)
	if err != nil {
		reg = &Registry{
			Schema:  1,
			Modules: make(map[string]ModuleEntry),
		}
	}
	m.registry = reg
	return nil
}

func (m *Manager) Registry() *Registry {
	return m.registry
}

func (m *Manager) CheckForUpdates() (map[string][2]string, error) {
	remoteJSON, err := m.dl.DownloadToMemory(rawGitHubBase + "/modules.json")
	if err != nil {
		return nil, fmt.Errorf("fetch remote registry: %w", err)
	}

	var remote Registry
	if err := json.Unmarshal(remoteJSON, &remote); err != nil {
		return nil, fmt.Errorf("parse remote registry: %w", err)
	}

	updates := make(map[string][2]string)
	for name, remoteEntry := range remote.Modules {
		localEntry, ok := m.registry.Get(name)
		if !ok {
			updates[name] = [2]string{"", remoteEntry.Version}
			continue
		}
		if localEntry.Version != remoteEntry.Version {
			updates[name] = [2]string{localEntry.Version, remoteEntry.Version}
		}
	}
	return updates, nil
}

func (m *Manager) IsCached(name string) bool {
	path := filepath.Join(m.cacheDir, name+".psm1")
	_, err := os.Stat(path)
	return err == nil
}

func (m *Manager) LocalVersion(name string) string {
	entry, ok := m.registry.Get(name)
	if !ok {
		return ""
	}
	return entry.Version
}

func (m *Manager) GetModulePath(name string) string {
	return filepath.Join(m.cacheDir, name+".psm1")
}

func (m *Manager) DownloadModule(name string, progress download.ProgressFunc) error {
	url := fmt.Sprintf("%s/%s.psm1", rawGitHubBase, name)
	dest := filepath.Join(m.cacheDir, name+".psm1")

	if err := m.dl.DownloadToFile(url, dest, progress); err != nil {
		return fmt.Errorf("download %s: %w", name, err)
	}

	hash, err := download.SHA256File(dest)
	if err != nil {
		return fmt.Errorf("hash %s: %w", name, err)
	}

	m.registry.Set(name, ModuleEntry{
		Version: "latest",
		File:    name + ".psm1",
		SHA256:  hash,
	})

	regPath := filepath.Join(m.cacheDir, "modules.json")
	return m.registry.Save(regPath)
}

func (m *Manager) DownloadModuleWithMeta(name, version, expectedHash string, progress download.ProgressFunc) error {
	url := fmt.Sprintf("%s/%s.psm1", rawGitHubBase, name)
	dest := filepath.Join(m.cacheDir, name+".psm1")

	if err := m.dl.DownloadToFile(url, dest, progress); err != nil {
		return fmt.Errorf("download %s: %w", name, err)
	}

	if expectedHash != "" {
		if err := download.VerifyFile(dest, expectedHash); err != nil {
			os.Remove(dest)
			return fmt.Errorf("verify %s: %w", name, err)
		}
	}

	hash, _ := download.SHA256File(dest)

	m.registry.Set(name, ModuleEntry{
		Version: version,
		File:    name + ".psm1",
		SHA256:  hash,
	})

	regPath := filepath.Join(m.cacheDir, "modules.json")
	return m.registry.Save(regPath)
}

func (m *Manager) EnsureModule(name string) (string, error) {
	path := m.GetModulePath(name)
	if m.IsCached(name) {
		return path, nil
	}

	if err := m.DownloadModule(name, nil); err != nil {
		return "", err
	}
	return path, nil
}

func (m *Manager) ExtractEmbedded(embeddedDir string) error {
	entries, err := os.ReadDir(embeddedDir)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".psm1") {
			continue
		}
		src := filepath.Join(embeddedDir, entry.Name())
		dest := filepath.Join(m.cacheDir, entry.Name())

		if _, err := os.Stat(dest); err == nil {
			continue
		}

		data, err := os.ReadFile(src)
		if err != nil {
			continue
		}
		if err := os.WriteFile(dest, data, 0644); err != nil {
			continue
		}
	}
	return nil
}

func (m *Manager) FindPowershell() string {
	if _, err := exec.LookPath("pwsh.exe"); err == nil {
		return "pwsh.exe"
	}
	return "powershell.exe"
}
