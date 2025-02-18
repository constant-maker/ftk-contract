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
	listHealingItemUpdate  = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=1307646345#gid=1307646345"

	healingItemType int = 25
)

func UpdateDataConfig(dataConfig *DataConfig, basePath string) {
	l := zap.S().With("func", "updateData")
	shouldRewriteFile := false
	// update list monsterResource
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

	// update list tool
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
	// validate items id
	validateItemConfig(*dataConfig)
	if shouldRewriteFile {
		newItems := struct {
			Items map[string]Item `json:"items"`
		}{
			Items: dataConfig.Items,
		}
		if err := WriteJSONFile(newItems, basePath+"/data-config/items.json"); err != nil {
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
		newItemRecipes := struct {
			ItemRecipes map[string]ItemRecipe `json:"itemRecipes"`
		}{
			ItemRecipes: dataConfig.ItemRecipes,
		}
		if err := WriteJSONFile(newItemRecipes, basePath+"/data-config/itemRecipes.json"); err != nil {
			l.Errorw("cannot update itemRecipes.json file", "err", err)
		} else {
			l.Infow("update itemRecipes.json successfully")
		}
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
		id := mustStringToInt(record[idIndex])
		tier := mustStringToInt(record[tierIndex])
		weight := mustStringToInt(record[weightIndex])
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
		id := mustStringToInt(record[idIndex])
		tier := mustStringToInt(record[tierIndex])
		weight := mustStringToInt(record[weightIndex])
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
		atkIndex, defIndex, agiIndex, hpIndex, msIndex, goldCostIndex, recipeIndex int
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
			slotTypeIndex = findIndex(record, "slotType")
			advantageTypeIndex = findIndex(record, "advantageType")
			twoHandedIndex = findIndex(record, "twoHanded")
			tierIndex = findIndex(record, "tier")
			weightIndex = findIndex(record, "weight")
			atkIndex = findIndex(record, "atk")
			defIndex = findIndex(record, "def")
			agiIndex = findIndex(record, "agi")
			hpIndex = findIndex(record, "hp")
			msIndex = findIndex(record, "ms")
			goldCostIndex = findIndex(record, "goldCost")
			recipeIndex = findIndex(record, "recipe")
			descIndex = findIndex(record, "desc")
			continue
		}

		id := mustStringToInt(record[idIndex])
		tier := mustStringToInt(record[tierIndex])
		weight := mustStringToInt(record[weightIndex])
		atk := mustStringToInt(record[atkIndex])
		def := mustStringToInt(record[defIndex])
		agi := mustStringToInt(record[agiIndex])
		hp := mustStringToInt(record[hpIndex])
		ms := mustStringToInt(record[msIndex])

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
		equipments = append(equipments, Item{
			Id:       id,
			Type:     equipmentType,
			Category: 1,
			Tier:     tier,
			Weight:   weight,
			Name:     removeRedundantText(record[nameIndex]),
			Desc:     removeRedundantText(record[descIndex]),
			EquipmentInfo: &EquipmentInfo{
				SlotType:      slotType,
				AdvantageType: advantageType,
				TwoHanded:     twoHanded,
				Atk:           atk,
				Def:           def,
				Agi:           agi,
				Hp:            hp,
				Ms:            ms,
			},
		})
		recipes = append(recipes, ItemRecipe{
			ItemId:      id,
			Ingredients: getMaterialList(record, record[recipeIndex], dataConfig),
			GoldCost:    mustStringToInt(record[goldCostIndex]),
		})
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

		id := mustStringToInt(record[idIndex])
		tier := mustStringToInt(record[tierIndex])
		weight := mustStringToInt(record[weightIndex])
		hpRestore := mustStringToInt(record[hpRestoreIndex])

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
			GoldCost:    mustStringToInt(record[goldCostIndex]),
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
		id := mustStringToInt(record[idIndex])
		tier := mustStringToInt(record[tierIndex])
		weight := mustStringToInt(record[weightIndex])
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
			GoldCost:    mustStringToInt(record[goldCostIndex]),
		})
	}
	return tool, recipes, nil
}

func getMaterialList(rawRecord []string, rawS string, dataConfig DataConfig) []Ingredient {
	l := zap.S().With("func", "getMaterialList", "raw record", rawRecord)
	arr := strings.Split(rawS, "\n")
	if len(arr) < 2 {
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
		amount := mustStringToInt(removeRedundantText(rawAmount))
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

func mustStringToInt(s string) int {
	num, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
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
	switch strings.ToLower(resourceType) {
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
		panic("invalid resource type")
	}
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
