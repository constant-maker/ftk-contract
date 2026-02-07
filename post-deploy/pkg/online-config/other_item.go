package onlineconfig

import (
	"io"
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

const (
	listOtherItemUpdate = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=2130105937#gid=2130105937"
)

// getListOtherItemUpdate others other item
func getListOtherItemUpdate(dataConfig *common.DataConfig) ([]common.Item, []common.ItemRecipe, error) {
	l := zap.S().With("func", "getListOtherItemUpdate")
	reader, err := getRawCsvReader(listOtherItemUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, nil, err
	}
	otherItems := make([]common.Item, 0)
	var (
		idIndex, tierIndex, weightIndex, nameIndex, descIndex, otherItemTypeIndex, untradableIndex int
	)
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		} else if err != nil {
			l.Errorw("cannot read data", "err", err)
			return nil, nil, err
		}

		if record[0] == "" { // empty row
			l.Warnw("invalid equipment data format", "data", record)
			continue
		}

		if strings.EqualFold(record[0], "id") { // header
			if tierIndex != 0 && nameIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			idIndex = findIndex(record, "id")
			nameIndex = findIndex(record, "name")
			tierIndex = findIndex(record, "tier")
			weightIndex = findIndex(record, "weight")
			otherItemTypeIndex = findIndex(record, "item_type")
			descIndex = findIndex(record, "desc")
			untradableIndex = findIndex(record, "untradable")
			continue
		}

		id := mustStringToInt(record[idIndex], idIndex)
		tier := mustStringToInt(record[tierIndex], tierIndex)
		weight := mustStringToInt(record[weightIndex], weightIndex)
		otherItemType := getEnumType(record[otherItemTypeIndex], record)
		untradable := false
		if strings.EqualFold(record[untradableIndex], "true") {
			untradable = true
		}

		otherItems = append(otherItems, common.Item{
			Id:         id,
			Type:       otherItemType,
			Category:   otherItemCategory,
			Tier:       tier,
			Weight:     weight,
			Name:       removeRedundantText(record[nameIndex]),
			Desc:       removeRedundantText(record[descIndex]),
			Untradable: untradable,
		})
	}
	return otherItems, nil, nil
}
