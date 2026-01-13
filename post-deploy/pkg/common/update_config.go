package common

import (
	"bytes"
	"encoding/csv"
	"fmt"
	"io"
	"net/http"
	"reflect"
	"strconv"
	"strings"

	"go.uber.org/zap"
)

const (
	listDropResourceUpdate = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=507192015#gid=507192015"
	listResourceUpdate     = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=1713114657#gid=1713114657"
	listEquipmentUpdate    = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=2048021285#gid=2048021285"
	listToolUpdate         = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=1372566467#gid=1372566467"
	listCardUpdate         = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=604813635#gid=604813635"
	listHealingItemUpdate  = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=1307646345#gid=1307646345"
	listSkillUpdate        = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=1359260272#gid=1359260272"

	healingItemType int = 25
)

func UpdateDataConfig(dataConfig *DataConfig, basePath string) {
	l := zap.S().With("func", "updateData")
	shouldRewriteFile := false
	// update list monsterResource
	l.Infow("GET LIST MONSTER RESOURCE")
	listMonsterResourceUpdate, err := getListMonsterResourceUpdate()
	if err != nil {
		l.Errorw("cannot get list monsterResource update", "err", err)
		panic(err)
	}
	for _, monsterResource := range listMonsterResourceUpdate {
		currentResource, ok := dataConfig.Items[intToString(monsterResource.Id)]
		if reflect.DeepEqual(monsterResource, currentResource) {
			// l.Infow("monsterResource data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new monsterResource", "data", monsterResource)
		} else {
			l.Infow("detect monsterResource update", "data", monsterResource)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(monsterResource.Id)] = monsterResource // add
	}

	// update list farm resource
	l.Infow("GET LIST FARM RESOURCE")
	listFarmResourceUpdate, err := getListFarmResourceUpdate()
	if err != nil {
		l.Errorw("cannot get list monsterResource update", "err", err)
		panic(err)
	}
	for _, farmResource := range listFarmResourceUpdate {
		currentResource, ok := dataConfig.Items[intToString(farmResource.Id)]
		if reflect.DeepEqual(farmResource, currentResource) {
			// l.Infow("farmResource data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new farmResource", "data", farmResource)
		} else {
			l.Infow("detect farmResource update", "data", farmResource)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(farmResource.Id)] = farmResource // add
	}

	// update list equipment
	l.Infow("GET LIST EQUIPMENT")
	listEquipmentUpdate, listEquipmentRecipeUpdate, err := getListEquipmentUpdate(*dataConfig)
	if err != nil {
		l.Errorw("cannot get list equipment update", "err", err)
		panic(err)
	}
	for _, equipment := range listEquipmentUpdate {
		currentEquipment, ok := dataConfig.Items[intToString(equipment.Id)]
		if reflect.DeepEqual(equipment, currentEquipment) {
			// l.Infow("equipment data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new equipment", "data", equipment)
		} else {
			l.Infow("detect equipment update", "data", equipment)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(equipment.Id)] = equipment // add
	}

	// update list healing item
	l.Infow("GET LIST HEALING ITEM")
	listHealingItemUpdate, listHealingItemRecipeUpdate, err := getListHealingItemUpdate(*dataConfig)
	if err != nil {
		l.Errorw("cannot get list healing item update", "err", err)
		panic(err)
	}
	for _, healingItem := range listHealingItemUpdate {
		currentItem, ok := dataConfig.Items[intToString(healingItem.Id)]
		if reflect.DeepEqual(healingItem, currentItem) {
			l.Infow("healingItem data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new healingItem", "data", healingItem)
		} else {
			l.Infow("detect healingItem update", "data", healingItem)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(healingItem.Id)] = healingItem // add
	}

	// update list scroll item
	l.Infow("GET LIST SCROLL ITEM")
	listScrollItemUpdate, listScrollItemRecipeUpdate, err := getListScrollUpdate(*dataConfig)
	if err != nil {
		l.Errorw("cannot get list scroll item update", "err", err)
		panic(err)
	}
	for _, scrollItem := range listScrollItemUpdate {
		currentItem, ok := dataConfig.Items[intToString(scrollItem.Id)]
		if reflect.DeepEqual(scrollItem, currentItem) {
			l.Infow("scrollItem data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new scrollItem", "data", scrollItem)
		} else {
			l.Infow("detect scrollItem update", "data", scrollItem)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(scrollItem.Id)] = scrollItem // add
	}

	// update list tool
	l.Infow("GET LIST TOOL")
	listToolUpdate, listToolRecipeUpdate, err := getListToolUpdate(*dataConfig)
	if err != nil {
		l.Errorw("cannot get list tool update", "err", err)
		panic(err)
	}
	for _, tool := range listToolUpdate {
		currentTool, ok := dataConfig.Items[intToString(tool.Id)]
		if reflect.DeepEqual(tool, currentTool) {
			// l.Infow("tool data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new tool", "data", tool)
		} else {
			l.Infow("detect tool update", "data", tool)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(tool.Id)] = tool // add
	}

	// update list card
	l.Infow("GET LIST CARD")
	listCardUpdate, err := getListCardUpdate(*dataConfig)
	if err != nil {
		l.Errorw("cannot get list card update", "err", err)
		panic(err)
	}
	for _, card := range listCardUpdate {
		currentCard, ok := dataConfig.Items[intToString(card.Id)]
		if reflect.DeepEqual(card, currentCard) {
			// l.Infow("tool data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new card", "data", card)
		} else {
			l.Infow("detect card update", "data", card)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(card.Id)] = card // add
	}
	// update list item exchange
	l.Infow("GET LIST ITEM EXCHANGE")
	listItemExUpdate, err := getItemExUpdate(*dataConfig)
	if err != nil {
		l.Errorw("cannot get list item exchange update", "err", err)
		panic(err)
	}

	// update list skill
	shouldRewriteSkillFile := false
	l.Infow("GET LIST SKILL")
	listSkillUpdate, err := getListSkillUpdate()
	if err != nil {
		l.Errorw("cannot get list skill update", "err", err)
		panic(err)
	}
	for _, skill := range listSkillUpdate {
		currentSkill, ok := dataConfig.Skills[intToString(skill.Id)]
		if reflect.DeepEqual(skill, currentSkill) {
			l.Infow("skill data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new skill", "data", skill)
		} else {
			l.Infow("detect skill update", "data", skill)
		}
		shouldRewriteSkillFile = true
		dataConfig.Skills[intToString(skill.Id)] = skill // add
	}
	if shouldRewriteSkillFile {
		// newSkills := struct {
		// 	Skills map[string]Skill `json:"skills"`
		// }{
		// 	Skills: dataConfig.Skills,
		// }
		// if err := WriteJSONFile(newSkills, basePath+"/data-config/skills.json"); err != nil {
		// 	l.Errorw("cannot update skill.json file", "err", err)
		// } else {
		// 	l.Infow("update skill.json successfully")
		// }
		if err := WriteSortedJsonFile(basePath+"/data-config/skills.json", "skills", dataConfig.Skills); err != nil {
			l.Errorw("cannot update skill.json file", "err", err)
		} else {
			l.Infow("update skill.json successfully")
		}
	}

	// validate items id
	validateItemConfig(*dataConfig)
	if shouldRewriteFile {
		// newItems := struct {
		// 	Items map[string]Item `json:"items"`
		// }{
		// 	Items: dataConfig.Items,
		// }
		// if err := WriteJSONFile(newItems, basePath+"/data-config/items.json"); err != nil {
		// 	l.Errorw("cannot update items.json file", "err", err)
		// } else {
		// 	l.Infow("update items.json successfully")
		// }
		if err := WriteSortedJsonFile(basePath+"/data-config/items.json", "items", dataConfig.Items); err != nil {
			l.Errorw("cannot update items.json file", "err", err)
		} else {
			l.Infow("update items.json successfully")
		}
	}
	// reset shouldRewriteFile to check recipe
	shouldRewriteFile = false
	for _, recipe := range listEquipmentRecipeUpdate {
		currentRecipe, ok := dataConfig.ItemRecipes[intToString(recipe.ItemId)]
		if reflect.DeepEqual(recipe, currentRecipe) {
			// l.Infow("recipe data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new recipe", "data", recipe)
		} else {
			l.Infow("detect recipe update", "data", recipe)
		}
		shouldRewriteFile = true
		dataConfig.ItemRecipes[intToString(recipe.ItemId)] = recipe // add
	}
	for _, recipe := range listHealingItemRecipeUpdate {
		currentRecipe, ok := dataConfig.ItemRecipes[intToString(recipe.ItemId)]
		if reflect.DeepEqual(recipe, currentRecipe) {
			// l.Infow("recipe data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new recipe", "data", recipe)
		} else {
			l.Infow("detect recipe update", "data", recipe)
		}
		shouldRewriteFile = true
		dataConfig.ItemRecipes[intToString(recipe.ItemId)] = recipe // add
	}
	for _, recipe := range listScrollItemRecipeUpdate {
		currentRecipe, ok := dataConfig.ItemRecipes[intToString(recipe.ItemId)]
		if reflect.DeepEqual(recipe, currentRecipe) {
			// l.Infow("recipe data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new recipe", "data", recipe)
		} else {
			l.Infow("detect recipe update", "data", recipe)
		}
		shouldRewriteFile = true
		dataConfig.ItemRecipes[intToString(recipe.ItemId)] = recipe // add
	}
	for _, recipe := range listToolRecipeUpdate {
		currentRecipe, ok := dataConfig.ItemRecipes[intToString(recipe.ItemId)]
		if reflect.DeepEqual(recipe, currentRecipe) {
			// l.Infow("recipe data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new recipe", "data", recipe)
		} else {
			l.Infow("detect recipe update", "data", recipe)
		}
		shouldRewriteFile = true
		dataConfig.ItemRecipes[intToString(recipe.ItemId)] = recipe // add
	}
	if shouldRewriteFile {
		// newItemRecipes := struct {
		// 	ItemRecipes map[string]ItemRecipe `json:"itemRecipes"`
		// }{
		// 	ItemRecipes: dataConfig.ItemRecipes,
		// }
		// if err := WriteJSONFile(newItemRecipes, basePath+"/data-config/itemRecipes.json"); err != nil {
		// 	l.Errorw("cannot update itemRecipes.json file", "err", err)
		// } else {
		// 	l.Infow("update itemRecipes.json successfully")
		// }
		if err := WriteSortedJsonFile(basePath+"/data-config/itemRecipes.json", "itemRecipes", dataConfig.ItemRecipes); err != nil {
			l.Errorw("cannot update itemRecipes.json file", "err", err)
		} else {
			l.Infow("update itemRecipes.json successfully")
		}
	}

	// reset shouldRewriteFile to check item exchange
	for _, itemEx := range listItemExUpdate {
		currentItemEx, ok := dataConfig.ItemExchanges[intToString(itemEx.ItemId)]
		if reflect.DeepEqual(itemEx, currentItemEx) {
			l.Infow("item exchange data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new item exchange", "data", itemEx)
		} else {
			l.Infow("detect item exchange update", "data", itemEx)
		}
		shouldRewriteFile = true
		dataConfig.ItemExchanges[intToString(itemEx.ItemId)] = itemEx // add
	}
	if err := WriteSortedJsonFile(basePath+"/data-config/itemExchanges.json", "itemExchanges", dataConfig.ItemExchanges); err != nil {
		l.Errorw("cannot update itemExchanges.json file", "err", err)
	} else {
		l.Infow("update itemExchanges.json successfully")
	}
}

func intToString(i int) string {
	return strconv.FormatInt(int64(i), 10)
}

func getListMonsterResourceUpdate() ([]Item, error) {
	l := zap.S().With("func", "getListMonsterResourceUpdate")
	reader, err := getRawCsvReader(listDropResourceUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	result := make([]Item, 0)
	var (
		idIndex, tierIndex, weightIndex, nameIndex, descIndex int
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
			l.Infow("invalid data, skip ...", "data", record)
			continue
		}
		if strings.EqualFold(record[0], "id") { // header
			if tierIndex != 0 && nameIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			idIndex = findIndex(record, "ID")
			tierIndex = findIndex(record, "Tier")
			weightIndex = findIndex(record, "Weight")
			nameIndex = findIndex(record, "Resource Name")
			descIndex = findIndex(record, "Description")
			continue
		}
		// if len(record) != 6 {
		// 	l.Warnw("invalid resource data format", "len(record)", len(record))
		// 	return nil, fmt.Errorf("invalid data format len record = %d", len(record))
		// }
		id := mustStringToInt(record[idIndex], idIndex)
		tier := mustStringToInt(record[tierIndex], tierIndex)
		weight := mustStringToInt(record[weightIndex], weightIndex)
		result = append(result, Item{
			Id:       int(id),
			Type:     23,
			Category: 2,
			Tier:     int(tier),
			Weight:   int(weight),
			Name:     removeRedundantText(record[nameIndex]),
			Desc:     removeRedundantText(record[descIndex]),
			ResourceInfo: &ResourceInfo{
				ResourceType: 6,
			},
		})
	}
	return result, nil
}

// getListFarmResourceUpdate farming resource
func getListFarmResourceUpdate() ([]Item, error) {
	l := zap.S().With("func", "getListFarmResourceUpdate")
	reader, err := getRawCsvReader(listResourceUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	result := make([]Item, 0)
	var (
		idIndex, tierIndex, weightIndex, nameIndex, typeIndex, descIndex int
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
			l.Infow("invalid data, skip ...", "data", record)
			continue
		}
		if strings.EqualFold(record[0], "id") { // header
			if tierIndex != 0 && nameIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			idIndex = findIndex(record, "id")
			tierIndex = findIndex(record, "tier")
			weightIndex = findIndex(record, "weight")
			nameIndex = findIndex(record, "name")
			typeIndex = findIndex(record, "type")
			descIndex = findIndex(record, "desc")
			continue
		}
		// if len(record) != 6 {
		// 	l.Warnw("invalid resource data format", "len(record)", len(record))
		// 	return nil, fmt.Errorf("invalid data format len record = %d", len(record))
		// }
		id := mustStringToInt(record[idIndex], idIndex)
		tier := mustStringToInt(record[tierIndex], tierIndex)
		weight := mustStringToInt(record[weightIndex], weightIndex)
		result = append(result, Item{
			Id:       int(id),
			Type:     23,
			Category: 2,
			Tier:     int(tier),
			Weight:   int(weight),
			Name:     removeRedundantText(record[nameIndex]),
			Desc:     removeRedundantText(record[descIndex]),
			ResourceInfo: &ResourceInfo{
				ResourceType: getResourceType(record[typeIndex]),
			},
		})
	}
	return result, nil
}

func getListEquipmentUpdate(dataConfig DataConfig) ([]Item, []ItemRecipe, error) {
	l := zap.S().With("func", "getListEquipmentUpdate")
	reader, err := getRawCsvReader(listEquipmentUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, nil, err
	}
	equipments := make([]Item, 0)
	recipes := make([]ItemRecipe, 0)
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
			slotTypeIndex = findIndex(record, "slotType")
			advantageTypeIndex = findIndex(record, "advantageType")
			twoHandedIndex = findIndex(record, "twoHanded")
			tierIndex = findIndex(record, "tier")
			weightIndex = findIndex(record, "new_weight")
			oldWeightIndex = findIndex(record, "old_weight")
			bonusWeightIndex = findIndex(record, "bonus_weight")
			atkIndex = findIndex(record, "atk")
			defIndex = findIndex(record, "def")
			agiIndex = findIndex(record, "agi")
			hpIndex = findIndex(record, "hp")
			msIndex = findIndex(record, "ms")
			goldCostIndex = findIndex(record, "goldCost")
			recipeIndex = findIndex(record, "recipe")
			descIndex = findIndex(record, "desc")
			shieldBarrierIndex = findIndex(record, "shieldBarrier")
			perkRequireToCraftIndex = findIndex(record, "perkRequireToCraft")
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
			perkType := getItemType(removeRedundantText(perkRequireToCraft[0]))
			perkItemTypes = append(perkItemTypes, perkType)
			perkLevel := mustStringToInt(removeRedundantText(perkRequireToCraft[1]), 1)
			requiredPerkLevels = append(requiredPerkLevels, perkLevel)
		}

		twoHanded := false
		if strings.EqualFold(record[twoHandedIndex], "TRUE") {
			twoHanded = true
		}
		equipmentType := getSpecialNum(record[typeIndex], record)
		slotType := getSpecialNum(record[slotTypeIndex], record)
		advantageType := 0
		if slotType == 0 {
			advantageType = getSpecialNum(record[advantageTypeIndex], record)
		}
		item := Item{
			Id:         id,
			Type:       equipmentType,
			Category:   1,
			Tier:       tier,
			Weight:     weight,
			OldWeight:  oldWeigh,
			Untradable: untradable,
			Name:       removeRedundantText(record[nameIndex]),
			Desc:       removeRedundantText(record[descIndex]),
			EquipmentInfo: &EquipmentInfo{
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
		equipmentRecipe := ItemRecipe{
			ItemId:      id,
			Ingredients: getMaterialList(record, record[recipeIndex], dataConfig),
			GoldCost:    mustStringToInt(record[goldCostIndex], goldCostIndex),
			FameCost:    mustStringToInt(record[fameCostIndex], fameCostIndex),
		}
		if len(perkItemTypes) > 0 {
			equipmentRecipe.PerkItemTypes = perkItemTypes
			equipmentRecipe.RequiredPerkLevels = requiredPerkLevels
		}
		recipes = append(recipes, equipmentRecipe)
	}
	return equipments, recipes, nil
}

func getListHealingItemUpdate(dataConfig DataConfig) ([]Item, []ItemRecipe, error) {
	l := zap.S().With("func", "getListHealingItemUpdate")
	reader, err := getRawCsvReader(listHealingItemUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, nil, err
	}
	healingItems := make([]Item, 0)
	recipes := make([]ItemRecipe, 0)
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
			goldCostIndex = findIndex(record, "goldCost")
			hpRestoreIndex = findIndex(record, "heal")
			recipeIndex = findIndex(record, "recipe")
			descIndex = findIndex(record, "desc")
			continue
		}

		id := mustStringToInt(record[idIndex], idIndex)
		tier := mustStringToInt(record[tierIndex], tierIndex)
		weight := mustStringToInt(record[weightIndex], weightIndex)
		hpRestore := mustStringToInt(record[hpRestoreIndex], hpRestoreIndex)

		healingItems = append(healingItems, Item{
			Id:       id,
			Type:     healingItemType,
			Category: 2,
			Tier:     tier,
			Weight:   weight,
			Name:     removeRedundantText(record[nameIndex]),
			Desc:     removeRedundantText(record[descIndex]),
			HealingInfo: &HealingInfo{
				HpRestore: uint16(hpRestore),
			},
		})
		recipes = append(recipes, ItemRecipe{
			ItemId:      id,
			Ingredients: getMaterialList(record, record[recipeIndex], dataConfig),
			GoldCost:    mustStringToInt(record[goldCostIndex], goldCostIndex),
		})
	}
	return healingItems, recipes, nil
}

func getListToolUpdate(dataConfig DataConfig) ([]Item, []ItemRecipe, error) {
	l := zap.S().With("func", "getListToolUpdate")
	reader, err := getRawCsvReader(listToolUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, nil, err
	}
	tool := make([]Item, 0)
	recipes := make([]ItemRecipe, 0)
	var (
		idIndex, tierIndex, weightIndex, nameIndex, descIndex, typeIndex, goldCostIndex, recipeIndex int
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
			typeIndex = findIndex(record, "type")
			tierIndex = findIndex(record, "tier")
			weightIndex = findIndex(record, "weight")
			goldCostIndex = findIndex(record, "goldCost")
			recipeIndex = findIndex(record, "recipe")
			descIndex = findIndex(record, "desc")
			continue
		}
		id := mustStringToInt(record[idIndex], idIndex)
		tier := mustStringToInt(record[tierIndex], tierIndex)
		weight := mustStringToInt(record[weightIndex], weightIndex)
		toolType := getToolType(record[typeIndex])
		tool = append(tool, Item{
			Id:       id,
			Type:     toolType,
			Category: 0,
			Tier:     tier,
			Weight:   weight,
			Name:     removeRedundantText(record[nameIndex]),
			Desc:     removeRedundantText(record[descIndex]),
		})
		recipes = append(recipes, ItemRecipe{
			ItemId:      id,
			Ingredients: getMaterialList(record, record[recipeIndex], dataConfig),
			GoldCost:    mustStringToInt(record[goldCostIndex], goldCostIndex),
		})
	}
	return tool, recipes, nil
}

func getListCardUpdate(dataConfig DataConfig) ([]Item, error) {
	l := zap.S().With("func", "getListToolUpdate")
	reader, err := getRawCsvReader(listCardUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	cards := make([]Item, 0)
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
		cards = append(cards, Item{
			Id:       id,
			Type:     27,
			Category: 2,
			Tier:     rarity,
			Weight:   weight,
			Name:     removeRedundantText(record[nameIndex]),
			Desc:     removeRedundantText(record[descIndex]),
			CardInfo: &CardInfo{
				Top:    mustStringToInt(record[topIndex], topIndex),
				Right:  mustStringToInt(record[rightIndex], rightIndex),
				Bottom: mustStringToInt(record[bottomIndex], bottomIndex),
				Left:   mustStringToInt(record[leftIndex], leftIndex),
			},
		})
	}
	return cards, nil
}

func getListSkillUpdate() ([]Skill, error) {
	l := zap.S().With("func", "getListSkillUpdate")
	reader, err := getRawCsvReader(listSkillUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	skills := make([]Skill, 0)
	var (
		idIndex, perkIndex, perkLevelIndex, typeIndex,
		nameIndex, mainDamageIndex, dmgPerTurnIndex, turnActiveIndex,
		spIndex, descIndex int
	)
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		} else if err != nil {
			l.Errorw("cannot read data", "err", err)
			return nil, err
		}
		if record[0] == "END" {
			break
		}
		if record[0] == "" && record[4] == "" { // empty row
			// l.Warnw("invalid skill data format", "data", record)
			continue
		}

		if strings.EqualFold(record[0], "Id") { // header
			if typeIndex != 0 && nameIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			idIndex = findIndex(record, "id")
			perkIndex = findIndex(record, "perk")
			perkLevelIndex = findIndex(record, "perk lvl")
			typeIndex = findIndex(record, "type")
			nameIndex = findIndex(record, "name")
			mainDamageIndex = findIndex(record, "main damage")
			dmgPerTurnIndex = findIndex(record, "damage per turn")
			turnActiveIndex = findIndex(record, "turns active")
			spIndex = findIndex(record, "sp")
			descIndex = findIndex(record, "description")
			continue
		}

		if _, err := strconv.Atoi(record[0]); err != nil {
			// this may be the note in docs
			continue
		}

		id := mustStringToInt(record[idIndex], idIndex)
		perkItemTypes := getPerkItemTypes(record[perkIndex])
		perkLevels := getPerkLevels(record[perkLevelIndex])
		skillEffectType := getSkillEffectType(record[typeIndex])
		mainDamage := mustStringToInt(record[mainDamageIndex], mainDamageIndex)
		dmgPerTurn := mustStringToInt(record[dmgPerTurnIndex], dmgPerTurnIndex)
		turnActive := mustStringToInt(record[turnActiveIndex], turnActiveIndex)
		sp := mustStringToInt(record[spIndex], spIndex)
		hasEffect := false
		if turnActive > 0 {
			hasEffect = true
		}
		skill := Skill{
			Id:                 id,
			Name:               removeRedundantText(record[nameIndex]),
			Desc:               removeRedundantText(record[descIndex]),
			Damage:             mainDamage,
			Sp:                 sp,
			PerkItemTypes:      perkItemTypes,
			RequiredPerkLevels: perkLevels,
			HasEffect:          hasEffect,
		}
		if hasEffect {
			skill.Effect = &SkillEffect{
				Damage:     dmgPerTurn,
				EffectType: uint8(skillEffectType),
				Turns:      turnActive,
			}
		}
		skills = append(skills, skill)
	}
	return skills, nil
}

func getMaterialList(rawRecord []string, rawS string, dataConfig DataConfig) []Ingredient {
	l := zap.S().With("func", "getMaterialList", "raw record", rawRecord)
	if rawS == "" {
		return nil
	}
	arr := strings.Split(rawS, "\n")
	if len(arr) == 0 {
		panic("invalid recipe data enter")
	}
	result := make([]Ingredient, 0)
	for _, data := range arr {
		subArr := strings.Split(data, "-")
		if len(subArr) != 2 {
			l.Panic("invalid recipe data -")
		}
		rawItemName := subArr[0]
		rawAmount := subArr[1]
		itemName := removeRedundantText(rawItemName)
		var itemId int
		for _, item := range dataConfig.Items {
			if item.Type == 23 && item.Name == itemName {
				itemId = item.Id
				break
			}
		}
		if itemId == 0 {
			l.Panicw("invalid resource", "name", itemName)
		}
		amount := mustStringToInt(removeRedundantText(rawAmount), 0)
		result = append(result, Ingredient{
			ItemId: itemId,
			Amount: amount,
		})
	}
	return result
}

func removeRedundantText(s string) string {
	for i := 0; i < 3; i++ {
		s = strings.TrimSuffix(s, " ")
		s = strings.TrimSuffix(s, "\r")

		s = strings.TrimPrefix(s, " ")
		// s = strings.TrimPrefix(s, "\r")
	}
	return s
}

func mustStringToInt(s string, index int) int {
	if s == "" {
		return 0
	}
	num, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		fmt.Println("PARSE ERROR", s, index)
		panic(s + err.Error())
	}
	return int(num)
}

func getSpecialNum(s string, record []string) int {
	if s == "-" {
		return 0
	}
	arr := strings.Split(s, "#")
	if len(arr) != 2 {
		zap.S().Panicw("invalid # data", "data", s, "record", record)
	}
	numS := strings.TrimSuffix(arr[1], ")")
	num, err := strconv.ParseInt(numS, 10, 64)
	if err != nil {
		panic(err.Error())
	}
	return int(num)
}

func getRawCsvReader(url string) (*csv.Reader, error) {
	l := zap.S().With("func", "readCSV")
	resp, err := http.Get(url)
	if err != nil {
		l.Errorw("cannot get data", "err", err)
		return nil, err
	}
	body, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		l.Errorw("cannot read data", "err", err)
		return nil, err
	}
	reader := csv.NewReader(bytes.NewReader(body))
	reader.LazyQuotes = true
	return reader, nil
}

func getToolType(rawS string) int {
	splitS := strings.Split(rawS, "-")
	if len(splitS) != 2 {
		panic("invalid tool type")
	}
	toolType := removeRedundantText(splitS[1])
	switch strings.ToLower(toolType) {
	case "wood":
		return 0
	case "stone":
		return 1
	case "fish":
		return 2
	case "ore":
		return 3
	case "wheat":
		return 4
	case "berries":
		return 5
	default:
		panic("invalid tool type")
	}
}

func getResourceType(resourceType string) int {
	resourceTypes := map[string]int{
		"wood":    0,
		"stone":   1,
		"fish":    2,
		"ore":     3,
		"wheat":   4,
		"berries": 5,
	}

	key := strings.ToLower(resourceType)
	if val, ok := resourceTypes[key]; ok {
		return val
	}

	zap.S().Panicw("invalid skill type", "resourceType", resourceType)
	return -1
}

func getSkillEffectType(rawSkillType string) int {
	skillType := strings.ToLower(removeRedundantText(rawSkillType))

	skillTypes := map[string]int{
		"none":      0,
		"burn":      1,
		"poison":    2,
		"frostbite": 3,
		"stun":      4,
	}

	if val, ok := skillTypes[skillType]; ok {
		return val
	}

	zap.S().Panicw("invalid skill type", "rawSkillType", rawSkillType)
	return 0
}

func getItemType(rawTypeString string) int {
	itemTypes := map[string]int{
		"woodaxe":          0,
		"stonehammer":      1,
		"fishingrod":       2,
		"pickaxe":          3,
		"sickle":           4,
		"berryshears":      5,
		"sword":            6,
		"axe":              7,
		"spear":            8,
		"bow":              9,
		"staff":            10,
		"dagger":           11,
		"shield":           12,
		"clotharmor":       13,
		"clothheadgear":    14,
		"clothfootwear":    15,
		"leatherarmor":     16,
		"leatherheadgear":  17,
		"leatherfootwear":  18,
		"platearmor":       19,
		"plateheadgear":    20,
		"platefootwear":    21,
		"mount":            22,
		"resource":         23,
		"mapskillitem":     24,
		"healingitem":      25,
		"statmodifieritem": 26,
	}

	key := strings.ToLower(rawTypeString)
	if val, ok := itemTypes[key]; ok {
		return val
	}
	zap.S().Panicw("invalid item type", "rawTypeString", rawTypeString)
	return -1
}

func validateItemConfig(dataConfig DataConfig) {
	var (
		min, max int
	)
	for _, item := range dataConfig.Items {
		if min == 0 || item.Id < min {
			min = item.Id
		}
		if max < item.Id {
			max = item.Id
		}
	}
	zap.S().Infow("MIN MAX Item ID", "min", min, "max", max)
	for i := min; i <= max; i++ {
		if _, ok := dataConfig.Items[intToString(i)]; !ok {
			panic(fmt.Sprintf("lack id %d", i))
		}
	}
}

func findIndex(arr []string, element string) int {
	for index, e := range arr {
		e = removeRedundantText(e)
		if strings.EqualFold(e, element) {
			return index
		}
	}
	panic("cannot find index ~ header: " + element)
}

func getPerkItemTypes(rawText string) []int {
	var result []int
	splitText := strings.Split(rawText, ",")
	if len(splitText) == 1 {
		rawValue := removeRedundantText(splitText[0])
		result = append(result, int(getItemType(rawValue)))
		return result
	}
	for _, st := range splitText {
		rawValue := removeRedundantText(st)
		result = append(result, int(getItemType(rawValue)))
	}
	return result
}

func getPerkLevels(rawText string) []int {
	var result []int
	splitText := strings.Split(rawText, ",")
	if len(splitText) == 1 {
		rawValue := removeRedundantText(splitText[0])
		val := int(mustStringToInt(rawValue, 0))
		if val < 0 {
			zap.S().Panicw("invalid perk level", "value", val)
		}
		result = append(result, val)
		return result
	}
	for _, st := range splitText {
		rawValue := removeRedundantText(st)
		val := int(mustStringToInt(rawValue, 0))
		if val < 0 {
			zap.S().Panicw("invalid perk level", "value", val)
		}
		result = append(result, val)
	}
	return result
}

func getRarity(rawText string) int {
	switch strings.ToLower(rawText) {
	case "common":
		return 1
	case "uncommon":
		return 2
	case "rare":
		return 3
	case "epic":
		return 4
	case "legendary":
		return 5
	default:
		fmt.Println("rawText", rawText)
		zap.S().Panicw("invalid rarity", "rarity", rawText)
	}
	return -1
}

func findItemIDByName(name string, dataConfig DataConfig) int {
	for _, item := range dataConfig.Items {
		if item.Name == name {
			return item.Id
		}
	}
	zap.S().Panicw("cannot find item by name", "name", name)
	return 0
}
