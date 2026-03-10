package onlineconfig

import (
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

func getListToolUpdate(sheetName string, dataConfig *common.DataConfig) ([]common.Item, []common.ItemRecipe, error) {
	l := zap.S().With("func", "getListToolUpdate")
	rawData, err := getSheetRawData(sheetName)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, nil, err
	}
	tools := make([]common.Item, 0)
	recipes := make([]common.ItemRecipe, 0)
	var (
		idIndex, tierIndex, weightIndex, nameIndex, descIndex, typeIndex, goldCostIndex, recipeIndex int
	)
	for i := range rawData {
		record := rawData[i]
		if len(record) == 0 {
			continue
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
			typeIndex = findIndex(record, "type")
			tierIndex = findIndex(record, "tier")
			weightIndex = findIndex(record, "weight")
			goldCostIndex = findIndex(record, "gold_cost")
			recipeIndex = findIndex(record, "recipe")
			descIndex = findIndex(record, "desc")
			continue
		}
		id := mustStringToInt(record[idIndex], idIndex)
		tier := mustStringToInt(record[tierIndex], tierIndex)
		weight := mustStringToInt(record[weightIndex], weightIndex)
		toolType := getToolType(record[typeIndex])
		tools = append(tools, common.Item{
			Id:       id,
			Type:     toolType,
			Category: toolCategory,
			Tier:     tier,
			Weight:   weight,
			Name:     removeRedundantText(record[nameIndex]),
			Desc:     removeRedundantText(record[descIndex]),
		})
		recipes = append(recipes, common.ItemRecipe{
			ItemId:      id,
			Ingredients: getMaterialList(record, record[recipeIndex], dataConfig),
			GoldCost:    mustStringToInt(record[goldCostIndex], goldCostIndex),
		})
	}
	return tools, recipes, nil
}
