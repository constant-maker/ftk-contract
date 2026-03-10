package onlineconfig

import (
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

func getListCardUpdate(sheetName string, dataConfig common.DataConfig) ([]common.Item, error) {
	l := zap.S().With("func", "getListToolUpdate")
	rawData, err := getSheetRawData(sheetName)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	cards := make([]common.Item, 0)
	var (
		idIndex, rarityIndex, nameIndex, descIndex, topIndex, rightIndex, bottomIndex, leftIndex int
	)
	for i := range rawData {
		record := rawData[i]
		if len(record) == 0 {
			continue
		}
		if record[0] == "" { // empty row
			l.Warnw("invalid card data format", "data", record)
			continue
		}

		if strings.EqualFold(record[0], "id") { // header
			if rarityIndex != 0 && nameIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			idIndex = findIndex(record, "id")
			nameIndex = findIndex(record, "name")
			rarityIndex = findIndex(record, "rarity")
			topIndex = findIndex(record, "top")
			rightIndex = findIndex(record, "right")
			bottomIndex = findIndex(record, "bottom")
			leftIndex = findIndex(record, "left")
			descIndex = findIndex(record, "desc")
			continue
		}
		id := mustStringToInt(record[idIndex], idIndex)
		// fmt.Println("ID", id, record)
		rarity := getRarity(record[rarityIndex])
		weight := 0
		cards = append(cards, common.Item{
			Id:       id,
			Type:     27,
			Category: 2,
			Tier:     rarity,
			Weight:   weight,
			Name:     removeRedundantText(record[nameIndex]),
			Desc:     removeRedundantText(record[descIndex]),
			CardInfo: &common.CardInfo{
				Top:    mustStringToInt(record[topIndex], topIndex),
				Right:  mustStringToInt(record[rightIndex], rightIndex),
				Bottom: mustStringToInt(record[bottomIndex], bottomIndex),
				Left:   mustStringToInt(record[leftIndex], leftIndex),
			},
		})
	}
	return cards, nil
}
