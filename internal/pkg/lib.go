package pkg

import (
	"embed"
	"encoding/json"
	"errors"
	"github.com/google/go-jsonnet"
	"github.com/marcbran/devsonnet/internal/pkg/lib/imports"
	"github.com/marcbran/devsonnet/pkg/jsonnext"
	"os"
	"path/filepath"
)

//go:embed lib
var lib embed.FS

func vm() *jsonnet.VM {
	vm := jsonnet.MakeVM()
	vm.Importer(jsonnext.CompoundImporter{
		Importers: []jsonnet.Importer{
			&jsonnext.FSImporter{Fs: lib},
			&jsonnext.FSImporter{Fs: imports.Fs},
			&jsonnet.FileImporter{},
		},
	})
	return vm
}

type Config struct {
	Source      string      `json:"source"`
	Description string      `json:"description"`
	Coordinates Coordinates `json:"coordinates"`
	Usage       Usage       `json:"usage"`
}

type Coordinates struct {
	Branch string `json:"branch"`
	Path   string `json:"path"`
	Repo   string `json:"repo"`
}

type Usage struct {
	Name   string `json:"name"`
	Target string `json:"target"`
}

func ResolvePkgConfig(pkgDir string) (Config, error) {
	mainFile := filepath.Join(pkgDir, "main.libsonnet")
	pkgFile := filepath.Join(pkgDir, "pkg.libsonnet")

	_, err := os.Stat(mainFile)
	if err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			return Config{}, err
		}
		return Config{}, errors.New("main.libsonnet not found")
	}
	mainCode, err := os.ReadFile(mainFile)
	if err != nil {
		return Config{}, err
	}

	_, err = os.Stat(pkgFile)
	if err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			return Config{}, err
		}
		return Config{}, errors.New("pkg.libsonnet not found")
	}
	pkgCode, err := os.ReadFile(pkgFile)
	if err != nil {
		return Config{}, err
	}

	vm := vm()
	vm.Importer(jsonnext.CompoundImporter{
		Importers: []jsonnet.Importer{
			&jsonnext.FSImporter{Fs: lib},
			&jsonnext.FSImporter{Fs: imports.Fs},
			&jsonnet.MemoryImporter{Data: map[string]jsonnet.Contents{
				"input/lib.libsonnet": jsonnet.MakeContents(string(mainCode)),
				"input/pkg.libsonnet": jsonnet.MakeContents(string(pkgCode)),
			}},
		},
	})
	vm.TLACode("lib", "import 'input/lib.libsonnet'")
	vm.TLACode("pkg", "import 'input/pkg.libsonnet'")
	vm.TLACode("examples", "null")
	vm.TLACode("examplesString", "null")

	str, err := vm.EvaluateFile("./lib/resolve_pkg_config.libsonnet")
	if err != nil {
		return Config{}, err
	}
	var config Config
	err = json.Unmarshal([]byte(str), &config)
	if err != nil {
		return Config{}, err
	}
	return config, nil
}
