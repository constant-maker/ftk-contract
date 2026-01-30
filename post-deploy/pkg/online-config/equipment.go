package onlineconfig

import (
	"io"
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

const (
	listEquipmentUpdate = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=2048021285#gid=2048021285"
)

func getListEquipmentUpdate(dataConfig *common.DataConfig) ([]common.Item, []common.ItemRecipe, error) {
	l := zap.S().With("func", "getListEquipmentUpdate")
	reader, err := getRawCsvReader(listEquipmentUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, nil, err
	}
	equipments := make([]common.Item, 0)
	recipes := make([]common.ItemRecipe, 0)
	var (
		idIndex, tierIndex, weightIndex, nameIndex, descIndex, typeIndex, slotTypeIndex, advantageTypeIndex, twoHandedIndex,
		atkIndex, defIndex, agiIndex, hpIndex, msIndex, goldCostIndex, recipeIndex, oldWeightIndex, bonusWeightIndex, shieldBarrierIndex,
		perkRequireToCraftIndex, fameCostIndex, untradableIndex int
	)
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		} else if err != nil {
			l.Errorw("cannot read data", "err", err)
			return nil, nil, err
		}
		if record[0] == "" || record[1] == "" || record[2] == "" { // empty row
			l.Warnw("invalid equipment data format", "data", record)
			continue
		}
		// l.Infow("record", "value", record)
		if strings.EqualFold(record[0], "id") { // header
			if tierIndex != 0 && nameIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			idIndex = findIndex(record, "id")
			nameIndex = findIndex(record, "name")
			typeIndex = findIndex(record, "type")
			slotTypeIndex = findIndex(record, "slot_type")
			advantageTypeIndex = findIndex(record, "advantage_type")
			twoHandedIndex = findIndex(record, "two_handed")
			tierIndex = findIndex(record, "tier")
			weightIndex = findIndex(record, "new_weight")
			oldWeightIndex = findIndex(record, "old_weight")
			bonusWeightIndex = findIndex(record, "bonus_weight")
			atkIndex = findIndex(record, "atk")
			defIndex = findIndex(record, "def")
			agiIndex = findIndex(record, "agi")
			hpIndex = findIndex(record, "hp")
			msIndex = findIndex(record, "ms")
			goldCostIndex = findIndex(record, "gold_cost")
			recipeIndex = findIndex(record, "recipe")
			descIndex = findIndex(record, "desc")
			shieldBarrierIndex = findIndex(record, "shield_barrier")
			perkRequireToCraftIndex = findIndex(record, "perk_require")
			fameCostIndex = findIndex(record, "fame_spent")
			untradableIndex = findIndex(record, "untradable")

			l.Infow(
				"list index",
				"idIndex", idIndex,
				"nameIndex", nameIndex,
				"typeIndex", typeIndex,
				"slotTypeIndex", slotTypeIndex,
				"advantageTypeIndex", advantageTypeIndex,
				"twoHandedIndex", twoHandedIndex,
				"tierIndex", tierIndex,
				"weightIndex", weightIndex,
				"atkIndex", atkIndex,
				"defIndex", defIndex,
				"agiIndex", agiIndex,
				"hpIndex", hpIndex,
				"msIndex", msIndex,
				"goldCostIndex", goldCostIndex,
				"recipeIndex", recipeIndex,
				"descIndex", descIndex,
				"shieldBarrierIndex", shieldBarrierIndex,
				"perkRequireToCraftIndex", perkRequireToCraftIndex,
				"fameCostIndex", fameCostIndex,
				"untradableIndex", untradableIndex,
			)
			continue
		}

		id := mustStringToInt(record[idIndex], idIndex)
		tier := mustStringToInt(record[tierIndex], tierIndex)
		weight := mustStringToInt(record[weightIndex], weightIndex)
		oldWeigh := mustStringToInt(record[oldWeightIndex], oldWeightIndex)
		bonusWeight := mustStringToInt(record[bonusWeightIndex], bonusWeightIndex)
		atk := mustStringToInt(record[atkIndex], atkIndex)
		def := mustStringToInt(record[defIndex], defIndex)
		agi := mustStringToInt(record[agiIndex], agiIndex)
		hp := mustStringToInt(record[hpIndex], hpIndex)
		ms := mustStringToInt(record[msIndex], msIndex)
		untradable := false
		if strings.EqualFold(record[untradableIndex], "TRUE") {
			untradable = true
		}
		shieldBarrierIndex := mustStringToInt(record[shieldBarrierIndex], shieldBarrierIndex)
		rawPerkRequireToCraft := record[perkRequireToCraftIndex]
		perkItemTypes := make([]int, 0)
		requiredPerkLevels := make([]int, 0)
		if rawPerkRequireToCraft != "" {
			perkRequireToCraft := strings.Split(rawPerkRequireToCraft, " - ")
			if len(perkRequireToCraft) != 2 {
				l.Panicw("Invalid perk require to craft", "data", record, "perkRequireToCraft", rawPerkRequireToCraft)
			}
			perkType := getItemType(dataConfig, removeRedundantText(perkRequireToCraft[0]))
			perkItemTypes = append(perkItemTypes, perkType)
			perkLevel := mustStringToInt(removeRedundantText(perkRequireToCraft[1]), 1)
			requiredPerkLevels = append(requiredPerkLevels, perkLevel)
		}

		twoHanded := false
		if strings.EqualFold(record[twoHandedIndex], "TRUE") {
			twoHanded = true
		}
		equipmentType := getEnumType(record[typeIndex], record)
		slotType := getEnumType(record[slotTypeIndex], record)
		advantageType := 0
		if slotType == 0 {
			advantageType = getEnumType(record[advantageTypeIndex], record)
		}
		item := common.Item{
			Id:         id,
			Type:       equipmentType,
			Category:   equipmentCategory,
			Tier:       tier,
			Weight:     weight,
			OldWeight:  oldWeigh,
			Untradable: untradable,
			Name:       removeRedundantText(record[nameIndex]),
			Desc:       removeRedundantText(record[descIndex]),
			EquipmentInfo: &common.EquipmentInfo{
				SlotType:      slotType,
				AdvantageType: advantageType,
				TwoHanded:     twoHanded,
				Atk:           atk,
				Def:           def,
				Agi:           agi,
				Hp:            hp,
				Ms:            ms,
				BonusWeight:   bonusWeight,
				ShieldBarrier: shieldBarrierIndex,
			},
		}
		equipments = append(equipments, item)
		equipmentRecipe := common.ItemRecipe{
			ItemId:      id,
			Ingredients: getMaterialList(record, record[recipeIndex], dataConfig),
			GoldCost:    mustStringToInt(record[goldCostIndex], goldCostIndex),
			FameCost:    mustStringToInt(record[fameCostIndex], fameCostIndex),
		}
		if equipmentRecipe.FameCost == 0 && equipmentRecipe.GoldCost == 0 && len(equipmentRecipe.Ingredients) == 0 {
			l.Warnw("equipment recipe is empty, skip", "data", record)
			continue
		}
		if len(perkItemTypes) > 0 {
			equipmentRecipe.PerkItemTypes = perkItemTypes
			equipmentRecipe.RequiredPerkLevels = requiredPerkLevels
		}
		recipes = append(recipes, equipmentRecipe)
	}
	return equipments, recipes, nil
}
