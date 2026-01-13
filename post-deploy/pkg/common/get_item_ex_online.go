package common

import (
	"io"
	"strings"

	"go.uber.org/zap"
)

const (
	listItemExUpdate = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=78299081#gid=78299081"
)

func getItemExUpdate(dataConfig DataConfig) ([]ItemExchange, error) {
	l := zap.S().With("func", "getItemExUpdate")
	reader, err := getRawCsvReader(listItemExUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	result := make([]ItemExchange, 0)
	var (
		outputItemIndex, inputResourceIndex int
	)
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		} else if err != nil {
			l.Errorw("cannot read data", "err", err)
			return nil, err
		}
		if record[1] == "" || record[2] == "" { // empty row
			l.Warnw("invalid item exchange format", "data", record)
			continue
		}
		// l.Infow("record", "value", record)
		if strings.EqualFold(record[1], "Input Resource") { // header
			if outputItemIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			inputResourceIndex = 1 // no need to find index, fixed position
			outputItemIndex = findIndex(record, "Output Item")

			l.Infow(
				"list index",
				"inputResourceIndex", inputResourceIndex,
				"outputItemIndex", outputItemIndex,
			)
			continue
		}

		ingredients := getMaterialList(record, record[inputResourceIndex], dataConfig)
		itemEx := ItemExchange{
			ItemId:      findItemIDByName(record[outputItemIndex], dataConfig),
			Ingredients: ingredients,
		}
		result = append(result, itemEx)
	}
	return result, nil
}
