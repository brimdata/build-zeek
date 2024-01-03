// +build windows

// This tool executes zeek on windows, constructing the required ZEEK*
// environment variables.  It embeds knowledge of the locations of the zeek
// executable and zeek script locations in the expanded 'zdeps/zeek' directory
// inside a Brim installation.
package main

import (
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"
)

// These paths are relative to the zdeps/zeek directory.
var (
	zeekExecRelPath  = "bin/zeek.exe"
	zeekPathRelPaths = []string{
		"share/zeek",
		"share/zeek/policy",
		"share/zeek/site",
	}
)

func pathEnvVar(name, topDir string, subdirs []string) string {
	var s []string
	for _, d := range subdirs {
		s = append(s, path.Join(filepath.ToSlash(topDir), d))
	}
	val := strings.Join(s, ";")
	return name + "=" + val
}

var ExecScript = `
event zeek_init() {
       Log::disable_stream(PacketFilter::LOG);
       Log::disable_stream(LoadedScripts::LOG);
       Log::disable_stream(Telemetry::LOG);
}`

func launchZeek(zdepsZeekDir, zeekExecPath string) error {
	zeekPath := pathEnvVar("ZEEKPATH", zdepsZeekDir, zeekPathRelPaths)

	cmd := exec.Command(zeekExecPath, "-C", "-r", "-", "--exec", ExecScript, "local")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = append(os.Environ(), zeekPath)

	return cmd.Run()
}

// zdepsZeekDirectory returns the absolute path of the zdeps/zeek directory,
// based on the assumption that this executable is located directly in it.
func zdepsZeekDirectory() (string, error) {
	execFile, err := os.Executable()
	if err != nil {
		return "", err
	}

	return filepath.Dir(execFile), nil
}

func main() {
	zdepsZeekDir, err := zdepsZeekDirectory()
	if err != nil {
		log.Fatalln("zdepsZeekDirectory failed:", err)
	}

	zeekExecPath := filepath.Join(zdepsZeekDir, filepath.FromSlash(zeekExecRelPath))
	if _, err := os.Stat(zeekExecPath); err != nil {
		log.Fatalln("zeek executable not found at", zeekExecPath)
	}

	err = launchZeek(zdepsZeekDir, zeekExecPath)
	if err != nil {
		log.Fatalln("launchZeek failed", err)
	}
}
