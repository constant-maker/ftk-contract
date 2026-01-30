package onlineconfig

import (
	"io"
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

const (
	listHealingItemUpdate = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=1307646345#gid=1307646345"

	healingItemType int = 25
)

func getListHealingItemUpdate(dataConfig *common.DataConfig) ([]common.Item, []common.ItemRecipe, error) {
	l := zap.S().With("func", "getListHealingItemUpdate")
	reader, err := getRawCsvReader(listHealingItemUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, nil, err
	}
	healingItems := make([]common.Item, 0)
	recipes := make([]common.ItemRecipe, 0)
	var (
		idIndex, tierIndex, weightIndex, nameIndex, descIndex, goldCostIndex, recipeIndex, hpRestoreIndex int
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
			goldCostIndex = findIndex(record, "gold_cost")
			hpRestoreIndex = findIndex(record, "heal")
			recipeIndex = findIndex(record, "recipe")
			descIndex = findIndex(record, "desc")
			continue
		}

		id := mustStringToInt(record[idIndex], idIndex)
		tier := mustStringToInt(record[tierIndex], tierIndex)
		weight := mustStringToInt(record[weightIndex], weightIndex)
		hpRestore := mustStringToInt(record[hpRestoreIndex], hpRestoreIndex)

		healingItems = append(healingItems, common.Item{
			Id:       id,
			Type:     healingItemType,
			Category: 2,
			Tier:     tier,
			Weight:   weight,
			Name:     removeRedundantText(record[nameIndex]),
			Desc:     removeRedundantText(record[descIndex]),
			HealingInfo: &common.HealingInfo{
				HpRestore: uint16(hpRestore),
			},
		})
		recipes = append(recipes, common.ItemRecipe{
			ItemId:      id,
			Ingredients: getMaterialList(record, record[recipeIndex], dataConfig),
			GoldCost:    mustStringToInt(record[goldCostIndex], goldCostIndex),
		})
	}
	return healingItems, recipes, nil
}
