package onlineconfig

import (
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

const (
	listSkinUpdate = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=1074969628#gid=1074969628"

	skinItemType = 31
)

func getListSkinUpdate(sheetName string, dataConfig *common.DataConfig) ([]common.Item, []common.ItemRecipe, error) {
	l := zap.S().With("func", "getListSkinUpdate")
	rawData, err := getSheetRawData(sheetName)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, nil, err
	}
	skinItems := make([]common.Item, 0)
	var (
		idIndex, tierIndex, weightIndex, nameIndex, descIndex, skinSlotIndex, weaponTypeIndex int
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
			tierIndex = findIndex(record, "tier")
			weightIndex = findIndex(record, "weight")
			skinSlotIndex = findIndex(record, "slot_type")
			weaponTypeIndex = findIndex(record, "weapon_type")
			descIndex = findIndex(record, "desc")
			continue
		}

		id := mustStringToInt(record[idIndex], idIndex)
		tier := mustStringToInt(record[tierIndex], tierIndex)
		weight := mustStringToInt(record[weightIndex], weightIndex)
		skinSlot := getEnumType(record[skinSlotIndex], record)

		var weaponTypePtr *int
		if skinSlot == 0 { // weapon slot only
			weaponType := getEnumType(record[weaponTypeIndex], record)
			weaponTypePtr = &weaponType
		}

		skinItems = append(skinItems, common.Item{
			Id:       id,
			Type:     skinItemType,
			Category: otherItemCategory,
			Tier:     tier,
			Weight:   weight,
			Name:     removeRedundantText(record[nameIndex]),
			Desc:     removeRedundantText(record[descIndex]),
			SkinInfo: &common.SkinInfo{
				SlotType:   skinSlot,
				WeaponType: weaponTypePtr,
			},
		})
	}
	return skinItems, nil, nil
}
