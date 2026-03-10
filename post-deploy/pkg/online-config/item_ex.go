package onlineconfig

import (
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

func getItemExUpdate(sheetName string, dataConfig *common.DataConfig) ([]common.ItemExchange, error) {
	l := zap.S().With("func", "getItemExUpdate")
	rawData, err := getSheetRawData(sheetName)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	result := make([]common.ItemExchange, 0)
	var (
		outputItemIndex, inputResourceIndex int
	)
	for i := range rawData {
		record := rawData[i]
		if len(record) == 0 {
			continue
		}
		if record[0] == "" { // empty row
			l.Warnw("invalid item exchange format", "data", record)
			continue
		}
		// l.Infow("record", "value", record)
		if strings.EqualFold(record[0], "input_resources") { // header
			if outputItemIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			inputResourceIndex = 0 // no need to find index, fixed position
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
