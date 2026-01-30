package onlineconfig

import (
	"reflect"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

// updateItemDataConfig update item data config, also the item recipes
// - monster resource
// - farming resource
// - equipment
// - healing item
// - scroll item
// - tool
// - card
// - skin
func updateItemDataConfig(dataConfig *common.DataConfig, basePath string) {
	l := zap.S().With("func", "updateItemDataConfig")
	shouldRewriteFile := false
	// update list monster resource
	l.Infow("GET LIST MONSTER RESOURCE")
	listMonsterResourceUpdate, err := getListMonsterResourceUpdate()
	if err != nil {
		l.Errorw("cannot get list monster resource update", "err", err)
		panic(err)
	}
	for _, monsterResource := range listMonsterResourceUpdate {
		currentResource, ok := dataConfig.Items[intToString(monsterResource.Id)]
		monsterResource.Weight = currentResource.Weight // keep old weight
		if reflect.DeepEqual(monsterResource, currentResource) {
			// l.Infow("monster resource data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new monster resource", "data", monsterResource)
		} else {
			l.Infow("detect monster resource update", "data", monsterResource)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(monsterResource.Id)] = monsterResource // add or update
	}

	// update list farming resource
	l.Infow("GET LIST FARMING RESOURCE")
	listFarmingResourceUpdate, err := getListFarmingResourceUpdate()
	if err != nil {
		l.Errorw("cannot get list farming resource update", "err", err)
		panic(err)
	}
	for _, farmingResource := range listFarmingResourceUpdate {
		currentResource, ok := dataConfig.Items[intToString(farmingResource.Id)]
		farmingResource.Weight = currentResource.Weight // keep old weight
		if reflect.DeepEqual(farmingResource, currentResource) {
			// l.Infow("farming resource data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new farming resource", "data", farmingResource)
		} else {
			l.Infow("detect farming resource update", "data", farmingResource)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(farmingResource.Id)] = farmingResource // add or update
	}

	// update list equipment
	l.Infow("GET LIST EQUIPMENT")
	listEquipmentUpdate, listEquipmentRecipeUpdate, err := getListEquipmentUpdate(dataConfig)
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
			// no need to keep old weight for equipment
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(equipment.Id)] = equipment // add or update
	}

	// update list healing item
	l.Infow("GET LIST HEALING ITEM")
	listHealingItemUpdate, listHealingItemRecipeUpdate, err := getListHealingItemUpdate(dataConfig)
	if err != nil {
		l.Errorw("cannot get list healing item update", "err", err)
		panic(err)
	}
	for _, healingItem := range listHealingItemUpdate {
		currentItem, ok := dataConfig.Items[intToString(healingItem.Id)]
		healingItem.Weight = currentItem.Weight // keep old weight
		if reflect.DeepEqual(healingItem, currentItem) {
			l.Infow("healing item data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new healing item", "data", healingItem)
		} else {
			l.Infow("detect healing item update", "data", healingItem)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(healingItem.Id)] = healingItem // add or update
	}

	// update list scroll item
	l.Infow("GET LIST SCROLL ITEM")
	listScrollItemUpdate, listScrollItemRecipeUpdate, err := getListScrollUpdate(dataConfig)
	if err != nil {
		l.Errorw("cannot get list scroll item update", "err", err)
		panic(err)
	}
	for _, scrollItem := range listScrollItemUpdate {
		currentItem, ok := dataConfig.Items[intToString(scrollItem.Id)]
		scrollItem.Weight = currentItem.Weight // keep old weight
		if reflect.DeepEqual(scrollItem, currentItem) {
			l.Infow("scroll item data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new scroll item", "data", scrollItem)
		} else {
			l.Infow("detect scroll item update", "data", scrollItem)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(scrollItem.Id)] = scrollItem // add or update
	}

	// update list tool
	l.Infow("GET LIST TOOL")
	listToolUpdate, listToolRecipeUpdate, err := getListToolUpdate(dataConfig)
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
		dataConfig.Items[intToString(tool.Id)] = tool // add or update
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
		card.Weight = currentCard.Weight // keep old weight
		if reflect.DeepEqual(card, currentCard) {
			// l.Infow("card data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new card", "data", card)
		} else {
			l.Infow("detect card update", "data", card)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(card.Id)] = card // add or update
	}

	// update list skin
	l.Infow("GET LIST SKIN")
	listSkinUpdate, _, err := getListSkinUpdate(dataConfig)
	if err != nil {
		l.Errorw("cannot get list skin update", "err", err)
		panic(err)
	}
	for _, skin := range listSkinUpdate {
		currentSkin, ok := dataConfig.Items[intToString(skin.Id)]
		if reflect.DeepEqual(skin, currentSkin) {
			// l.Infow("skin data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new skin", "data", skin)
		} else {
			l.Infow("detect skin update", "data", skin)
		}
		shouldRewriteFile = true
		dataConfig.Items[intToString(skin.Id)] = skin // add or update
	}

	// write item if needed
	validateItemConfig(*dataConfig)
	if shouldRewriteFile {
		if err := common.WriteSortedJsonFile(basePath+"/data-config/items.json", "items", dataConfig.Items); err != nil {
			l.Errorw("cannot update items.json file", "err", err)
		} else {
			l.Infow("update items.json successfully")
		}
	}

	// check and write item recipes if needed
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
		if err := common.WriteSortedJsonFile(basePath+"/data-config/itemRecipes.json", "itemRecipes", dataConfig.ItemRecipes); err != nil {
			l.Errorw("cannot update itemRecipes.json file", "err", err)
		} else {
			l.Infow("update itemRecipes.json successfully")
		}
	}
}
