package onlineconfig

import (
	"io"
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

const (
	listItemExUpdate = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=78299081#gid=78299081"
)

func getItemExUpdate(dataConfig *common.DataConfig) ([]common.ItemExchange, error) {
	l := zap.S().With("func", "getItemExUpdate")
	reader, err := getRawCsvReader(listItemExUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	result := make([]common.ItemExchange, 0)
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
		if strings.EqualFold(record[1], "input_resources") { // header
			if outputItemIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			inputResourceIndex = 1 // no need to find index, fixed position
			outputItemIndex = findIndex(record, "output_item")

			l.Infow(
				"list index",
				"inputResourceIndex", inputResourceIndex,
				"outputItemIndex", outputItemIndex,
			)
			continue
		}

		ingredients := getMaterialList(record, record[inputResourceIndex], dataConfig)
		itemId, err := findItemIDByName(record[outputItemIndex], dataConfig)
		if err != nil {
			l.Errorw("cannot find item by name", "record", record, "name", record[outputItemIndex], "err", err)
			return nil, err
		}
		itemEx := common.ItemExchange{
			ItemId:      itemId,
			Ingredients: ingredients,
		}
		result = append(result, itemEx)
	}
	return result, nil
}
