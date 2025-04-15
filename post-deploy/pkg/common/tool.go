package common

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strconv"

	"go.uber.org/zap"
)

func ParseFile(filePath string, data interface{}) error {
	f, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(f, &data); err != nil {
		return err
	}
	return nil
}

func WriteJSONFile(data interface{}, path string) error {
	l := zap.S().With("func", "WriteJSONFile")
	fileContent, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		l.Panicw("cannot marshalIndent data", "err", err)
	}
	if err := os.WriteFile(path, fileContent, 0644); err != nil {
		l.Panicw("cannot write data", "err", err)
	}
	return nil
}

func WriteSortedJsonFile[T any](filePath string, mainKey string, data map[string]T) error {
	// Collect and sort keys numerically
	keys := make([]string, 0, len(data))
	for k := range data {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		ki, err := strconv.Atoi(keys[i])
		if err != nil {
			zap.S().Panicw("invalid number", "err", err, "value", keys[i])
		}
		kj, err := strconv.Atoi(keys[j])
		if err != nil {
			zap.S().Panicw("invalid number", "err", err, "value", keys[j])
		}
		return ki < kj
	})

	// Open file
	file, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer file.Close()

	// Write JSON content
	if mainKey != "" {
		_, _ = file.WriteString("{\n")
		_, _ = file.WriteString(fmt.Sprintf("  \"%s\": {\n", mainKey))
		for i, k := range keys {
			val, _ := json.MarshalIndent(data[k], "    ", "  ")
			line := fmt.Sprintf("    \"%s\": %s", k, val)
			if i < len(keys)-1 {
				line += ","
			}
			line += "\n"
			_, _ = file.WriteString(line)
		}
		_, _ = file.WriteString("  }\n}\n")
	} else {
		_, _ = file.WriteString("{\n")
		for i, k := range keys {
			val, _ := json.MarshalIndent(data[k], "    ", "  ")
			line := fmt.Sprintf("  \"%s\": %s", k, val)
			if i < len(keys)-1 {
				line += ","
			}
			line += "\n"
			_, _ = file.WriteString(line)
		}
		_, _ = file.WriteString("}\n")
	}

	return nil
}
