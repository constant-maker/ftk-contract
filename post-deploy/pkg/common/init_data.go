package common

func InitMapEnums(dataConfig DataConfig) {
	for enumValue, num := range dataConfig.ResourceTypes {
		MapResourceTypes[num] = enumValue
	}
	for enumValue, num := range dataConfig.ItemCategoryTypes {
		MapItemCategoryTypes[num] = enumValue
	}
	for enumValue, num := range dataConfig.ItemTypes {
		MapItemTypes[num] = enumValue
	}
	for enumValue, num := range dataConfig.EquipmentSlotTypes {
		MapEquipmentSlotTypes[num] = enumValue
	}
	for enumValue, num := range dataConfig.CharacterStates {
		MapCharacterStateTypes[num] = enumValue
	}
	for enumValue, num := range dataConfig.QuestTypes {
		MapQuestTypes[num] = enumValue
	}
	for enumValue, num := range dataConfig.ZoneTypes {
		MapZoneTypes[num] = enumValue
	}
	for enumValue, num := range dataConfig.TerrainTypes {
		MapTerrainTypes[num] = enumValue
	}
	for enumValue, num := range dataConfig.AdvantageTypes {
		MapAdvantageTypes[num] = enumValue
	}
	for enumValue, num := range dataConfig.RarityTypes {
		MapRarityTypes[num] = enumValue
	}
	for enumValue, num := range dataConfig.SkinSlotTypes {
		MapSkinSlotTypes[num] = enumValue
	}
}
