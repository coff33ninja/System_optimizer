package modules

import (
	"encoding/json"
	"fmt"
	"os"
)

type ModuleEntry struct {
	Version      string   `json:"version"`
	File         string   `json:"file"`
	SHA256       string   `json:"sha256"`
	Admin        bool     `json:"admin"`
	Dependencies []string `json:"dependencies"`
}

type Registry struct {
	Schema  int                    `json:"schema"`
	Modules map[string]ModuleEntry `json:"modules"`
}

func LoadRegistry(path string) (*Registry, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read registry: %w", err)
	}

	var reg Registry
	if err := json.Unmarshal(data, &reg); err != nil {
		return nil, fmt.Errorf("parse registry: %w", err)
	}

	if reg.Modules == nil {
		reg.Modules = make(map[string]ModuleEntry)
	}
	return &reg, nil
}

func (r *Registry) Save(path string) error {
	data, err := json.MarshalIndent(r, "", "    ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

func (r *Registry) Get(name string) (ModuleEntry, bool) {
	entry, ok := r.Modules[name]
	return entry, ok
}

func (r *Registry) Set(name string, entry ModuleEntry) {
	r.Modules[name] = entry
}
