package onlineconfig

import (
	"io"
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

const (
	listCardUpdate = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=604813635#gid=604813635"
)

func getListCardUpdate(dataConfig common.DataConfig) ([]common.Item, error) {
	l := zap.S().With("func", "getListToolUpdate")
	reader, err := getRawCsvReader(listCardUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	cards := make([]common.Item, 0)
	var (
		idIndex, rarityIndex, nameIndex, descIndex, topIndex, rightIndex, bottomIndex, leftIndex int
	)
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		} else if err != nil {
			l.Errorw("cannot read data", "err", err)
			return nil, err
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
