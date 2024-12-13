package common

import (
	"encoding/json"
	"os"

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
