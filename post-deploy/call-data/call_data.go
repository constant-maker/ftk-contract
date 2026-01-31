package calldata

import (
	"fmt"
	"sort"
	"strconv"
	"sync"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/table"
	"go.uber.org/zap"
)

func BuildKingdomData(l *zap.SugaredLogger, dataConfig common.DataConfig) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len Kingdoms", "value", len(dataConfig.Kingdoms))
	var (
		kingdoms []common.Kingdom
	)
	for k, kingdom := range dataConfig.Kingdoms {
		if k != strconv.FormatInt(int64(kingdom.Id), 10) {
			l.Errorw("wrong kingdom key and id", "key", k, "id", kingdom.Id)
			return nil, fmt.Errorf("wrong kingdom key and id %s %d", k, kingdom.Id)
		}
		kingdoms = append(kingdoms, kingdom)
	}
	sort.Slice(kingdoms, func(i, j int) bool {
		return kingdoms[i].Id < kingdoms[j].Id
	})
	for _, kingdom := range kingdoms {
		kingdomCallData, err := table.KingdomCallData(kingdom)
		if err != nil {
			l.Errorw("cannot build Kingdom call data", "err", err)
			return nil, err
		}
		callData = append(callData, kingdomCallData)
	}
	return callData, nil
}

func BuildCityData(l *zap.SugaredLogger, dataConfig common.DataConfig) ([][]byte, []common.City, error) {
	callData := make([][]byte, 0)
	l.Infow("len Cities", "value", len(dataConfig.Cities))
	var (
		// cityLocations []common.Location
		cities []common.City
	)
	for k, city := range dataConfig.Cities {
		if k != strconv.FormatInt(int64(city.Id), 10) {
			l.Errorw("wrong city key and id", "key", k, "id", city.Id)
			return nil, nil, fmt.Errorf("wrong city key and id %s %d", k, city.Id)
		}
		cities = append(cities, city)
	}
	sort.Slice(cities, func(i, j int) bool {
		return cities[i].Id < cities[j].Id
	})
	for _, city := range cities {
		// cityLocations = append(cityLocations, common.Location{
		// 	X: city.X,
		// 	Y: city.Y,
		// })
		cityCallData, err := table.CityCallData(city)
		if err != nil {
			l.Errorw("cannot build City call data", "err", err)
			return nil, nil, err
		}
		callData = append(callData, cityCallData)
	}
	return callData, cities, nil
}

func BuildNpcShopData(l *zap.SugaredLogger, dataConfig common.DataConfig) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len Cities", "value", len(dataConfig.Cities))
	var (
		// cityLocations []common.Location
		cities []common.City
	)
	for k, city := range dataConfig.Cities {
		if k != strconv.FormatInt(int64(city.Id), 10) {
			l.Errorw("wrong city key and id", "key", k, "id", city.Id)
			return nil, fmt.Errorf("wrong city key and id %s %d", k, city.Id)
		}
		cities = append(cities, city)
	}
	sort.Slice(cities, func(i, j int) bool {
		return cities[i].Id < cities[j].Id
	})
	for _, city := range cities {
		npcShopData, err := table.NpcShopCallData(city)
		if err != nil {
			l.Errorw("cannot build npcShop call data", "err", err)
			return nil, err
		}
		callData = append(callData, npcShopData)
	}
	return callData, nil
}

func BuildItemData(l *zap.SugaredLogger, dataConfig common.DataConfig, fromItemID int) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len Items", "value", len(dataConfig.Items))
	// make array and sort by itemId so the call data in post-deploy will be ordered by itemId
	items := make([]common.Item, 0)
	for k, item := range dataConfig.Items {
		if k != strconv.FormatInt(int64(item.Id), 10) {
			l.Errorw("wrong item key and id", "key", k, "id", item.Id)
			return nil, fmt.Errorf("wrong item key and id %s %d", k, item.Id)
		}
		items = append(items, item)
	}
	sort.Slice(items, func(i, j int) bool {
		return items[i].Id < items[j].Id
	})
	once := sync.Once{}
	for _, item := range items {
		if item.Id < fromItemID {
			continue
		}
		once.Do(func() {
			l.Infow("Item Info starts from ID", "value", fromItemID)
		})
		itemCallData, err := table.ItemCallData(item)
		if err != nil {
			l.Errorw("cannot build Item Detail call data", "err", err)
			return nil, err
		}
		callData = append(callData, itemCallData)
	}
	return callData, nil
}

func BuildEquipmentItemData(l *zap.SugaredLogger, dataConfig common.DataConfig, fromItemID int) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len Items", "value", len(dataConfig.Items))
	// make array and sort by itemId so the call data in post-deploy will be ordered by itemId
	items := make([]common.Item, 0)
	for k, item := range dataConfig.Items {
		if k != strconv.FormatInt(int64(item.Id), 10) {
			l.Errorw("wrong item key and id", "key", k, "id", item.Id)
			return nil, fmt.Errorf("wrong item key and id %s %d", k, item.Id)
		}
		items = append(items, item)
	}
	sort.Slice(items, func(i, j int) bool {
		return items[i].Id < items[j].Id
	})
	once := sync.Once{}
	for _, item := range items {
		if item.Id < fromItemID {
			continue
		}
		if item.EquipmentInfo == nil {
			// skip all non-equipment items
			continue
		}
		once.Do(func() {
			l.Infow("Item Info starts from ID", "value", fromItemID)
		})
		itemCallData, err := table.ItemCallData(item)
		if err != nil {
			l.Errorw("cannot build Item Detail call data", "err", err)
			return nil, err
		}
		callData = append(callData, itemCallData)
	}
	return callData, nil
}

// BuildExtraItemInfoData includes equipment, healing, and resource item info
func BuildExtraItemInfoData(l *zap.SugaredLogger, dataConfig common.DataConfig, fromItemID int, equipmentOnly bool) ([][]byte, error) {
	callData := make([][]byte, 0)
	// l.Infow("len Items", "value", len(dataConfig.Items))
	// make array and sort by itemId so the call data in post-deploy will be ordered by itemId
	items := make([]common.Item, 0)
	for k, item := range dataConfig.Items {
		if k != strconv.FormatInt(int64(item.Id), 10) {
			l.Errorw("wrong item key and id", "key", k, "id", item.Id)
			return nil, fmt.Errorf("wrong item key and id %s %d", k, item.Id)
		}
		items = append(items, item)
	}
	sort.Slice(items, func(i, j int) bool {
		return items[i].Id < items[j].Id
	})
	once := sync.Once{}
	for _, item := range items {
		if item.Id < fromItemID {
			continue
		}
		once.Do(func() {
			l.Infow("Extra Item Info starts from ID", "value", fromItemID)
		})
		if equipmentOnly && item.Category != 1 {
			continue
		}
		switch {
		case item.EquipmentInfo != nil:
			equipmentItemInfoCallData, err := table.EquipmentItemInfoCallData(*item.EquipmentInfo, item.Id)
			if err != nil {
				l.Errorw("cannot build Equipment Item Info call data", "err", err)
				return nil, err
			}
			// l.Infow("equipment info", "itemId", item.Id)
			callData = append(callData, equipmentItemInfoCallData)
			equipmentItemInfo2V2CallData, err := table.EquipmentItemInfo2V2CallData(*item.EquipmentInfo, item.Id)
			if err != nil {
				l.Errorw("cannot build Equipment Item Info 2V2 call data", "err", err)
				return nil, err
			}
			callData = append(callData, equipmentItemInfo2V2CallData)
			// l.Infow("equipment info 2V2", "itemId", item.Id)
		case item.HealingInfo != nil:
			l.Infow("healing info", "value", item.HealingInfo)
			healingItemInfoCallData, err := table.HealingItemInfoCallData(*item.HealingInfo, item.Id)
			if err != nil {
				l.Errorw("cannot build Healing Item Info call data", "err", err)
				return nil, err
			}
			callData = append(callData, healingItemInfoCallData)
		case item.ResourceInfo != nil:
			// l.Infow("resource info", "value", item.ResourceInfo)
			resourceItemInfoCallData, err := table.ResourceItemInfoCallData(*item.ResourceInfo, item.Id)
			if err != nil {
				l.Errorw("cannot build Item Resource Info call data", "err", err)
				return nil, err
			}
			callData = append(callData, resourceItemInfoCallData)
		case item.SkinInfo != nil:
			l.Infow("skin info", "value", item.SkinInfo)
			skinItemInfoCallData, err := table.SkinInfoCallData(item)
			if err != nil {
				l.Errorw("cannot build Skin Info call data", "err", err)
				return nil, err
			}
			callData = append(callData, skinItemInfoCallData)
		case item.BuffInfo != nil:
			l.Infow("buff info", "value", item.BuffInfo)
			buffItemInfoCallData, err := table.BuffItemInfoCallData(*item.BuffInfo, item.Id)
			if err != nil {
				l.Errorw("cannot build Buff Item Info call data", "err", err)
				return nil, err
			}
			callData = append(callData, buffItemInfoCallData)
			if item.ExpAmplify != nil {
				if item.BuffInfo.Duration == 0 {
					l.Panicw("buff info duration is 0", "itemId", item.Id)
				}
				l.Infow("exp amplify info", "value", item.ExpAmplify)
				expAmplifyCallData, err := table.BuffExpCallData(*item.ExpAmplify, item.Id)
				if err != nil {
					l.Errorw("cannot build Buff Exp call data", "err", err)
					return nil, err
				}
				callData = append(callData, expAmplifyCallData)
			}
			if item.StatsModify != nil {
				if item.BuffInfo.Duration == 0 {
					l.Panicw("buff info duration is 0", "itemId", item.Id)
				}
				l.Infow("stats modify info", "value", item.StatsModify)
				statsModifyCallData, err := table.BuffStatCallData(*item.StatsModify, item.Id)
				if err != nil {
					l.Errorw("cannot build Stats Modify call data", "err", err)
					return nil, err
				}
				callData = append(callData, statsModifyCallData)
			}
			if item.InstantDamage != nil {
				l.Infow("instant damage info", "value", item.InstantDamage)
				dmgBuffInfoCallData, err := table.BuffDmgInfoCallData(*item.InstantDamage, item.Id)
				if err != nil {
					l.Errorw("cannot build Instant Damage call data", "err", err)
					return nil, err
				}
				callData = append(callData, dmgBuffInfoCallData)
			}
		default:
			continue
		}
	}
	return callData, nil
}

func BuildItemRecipeData(l *zap.SugaredLogger, dataConfig common.DataConfig, fromItemID int) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len ItemRecipes", "value", len(dataConfig.ItemRecipes))
	// make array and sort by itemId so the call data in post-deploy will be ordered by itemId
	itemRecipes := make([]common.ItemRecipe, 0)
	for k, itemRecipe := range dataConfig.ItemRecipes {
		if k != strconv.FormatInt(int64(itemRecipe.ItemId), 10) {
			l.Errorw("wrong itemRecipe key and id", "key", k, "id", itemRecipe.ItemId)
			return nil, fmt.Errorf("wrong itemRecipe key and id %s %d", k, itemRecipe.ItemId)
		}
		itemRecipes = append(itemRecipes, itemRecipe)
	}
	sort.Slice(itemRecipes, func(i, j int) bool {
		return itemRecipes[i].ItemId < itemRecipes[j].ItemId
	})
	once := sync.Once{}
	for _, recipe := range itemRecipes {
		if recipe.ItemId < fromItemID {
			continue
		}
		once.Do(func() {
			l.Infow("ItemRecipe starts from ID", "value", fromItemID)
		})
		itemRecipeCallData, err := table.ItemRecipeCallData(recipe)
		if err != nil {
			l.Errorw("cannot build Item Recipe call data", "err", err)
			return nil, err
		}
		callData = append(callData, itemRecipeCallData)
	}
	return callData, nil
}

func BuildNpcData(l *zap.SugaredLogger, dataConfig common.DataConfig) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len Npcs", "value", len(dataConfig.Npcs))
	var npcs []common.Npc
	for k, npc := range dataConfig.Npcs {
		if k != strconv.FormatInt(int64(npc.Id), 10) {
			l.Errorw("wrong npc key and id", "key", k, "id", npc.Id)
			return nil, fmt.Errorf("wrong npc key and id %s %d", k, npc.Id)
		}
		npcs = append(npcs, npc)
	}
	sort.Slice(npcs, func(i, j int) bool {
		return npcs[i].Id < npcs[j].Id
	})
	for _, npc := range npcs {
		npcCallData, err := table.NpcCallData(npc)
		if err != nil {
			l.Errorw("cannot build NPC call data", "err", err)
			return nil, err
		}
		callData = append(callData, npcCallData)
		// if len(npc.Cards) != 0 {
		// 	npcCardCallData, err := table.NpcCardCallData(npc)
		// 	if err != nil {
		// 		l.Errorw("cannot build NPC Card call data", "err", err)
		// 		return nil, err
		// 	}
		// 	callData = append(callData, npcCardCallData)
		// }
	}
	return callData, nil
}

func BuildQuestData(l *zap.SugaredLogger, dataConfig common.DataConfig, fromQuestID int) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len Quests", "value", len(dataConfig.Quests))
	var quests []common.QuestV4
	for k, quest := range dataConfig.Quests {
		if k != strconv.FormatInt(int64(quest.Id), 10) {
			l.Errorw("wrong quest key and id", "key", k, "id", quest.Id)
			return nil, fmt.Errorf("wrong quest key and id %s %d", k, quest.Id)
		}
		quests = append(quests, quest)
	}
	sort.Slice(quests, func(i, j int) bool {
		return quests[i].Id < quests[j].Id
	})
	once := sync.Once{}
	for _, quest := range quests {
		if quest.Id < int64(fromQuestID) {
			continue
		}
		once.Do(func() {
			l.Infow("Quest starts from ID", "value", fromQuestID)
		})
		if quest.ToNpcId == 0 {
			quest.ToNpcId = quest.FromNpcId // same npc
		}
		if len(quest.LocateDetails) > 0 {
			quest.QuestType = dataConfig.QuestTypes[common.QuestLocate]
		} else {
			quest.QuestType = dataConfig.QuestTypes[common.QuestContribute]
		}
		if _, ok := dataConfig.Npcs[strconv.FormatInt(quest.FromNpcId, 10)]; !ok {
			l.Panicw("invalid from npc id", "id", quest.Id)
		}
		if _, ok := dataConfig.Npcs[strconv.FormatInt(quest.ToNpcId, 10)]; !ok {
			l.Panicw("invalid to npc id", "id", quest.Id)
		}
		questCallData, err := table.QuestCallData(quest)
		if err != nil {
			l.Errorw("cannot build QuestV4 call data", "err", err)
			return nil, err
		}
		callData = append(callData, questCallData)

		switch common.MapQuestTypes[quest.QuestType] {
		case common.QuestContribute:
			questContributeCallData, err := table.QuestContributeCallData(quest.Id, quest.ContributeDetails)
			if err != nil {
				l.Errorw("cannot build QuestContribute call data", "err", err)
				return nil, err
			}
			callData = append(callData, questContributeCallData)
		case common.QuestLocate:
			questLocateCallData, err := table.QuestLocateCallData(quest.Id, quest.LocateDetails)
			if err != nil {
				l.Errorw("cannot build QuestInventoryCheck call data", "err", err)
				return nil, err
			}
			callData = append(callData, questLocateCallData)
		default:
			l.Errorw("invalid quest type", "questType", quest.QuestType)
			return nil, fmt.Errorf("invalid quest type, value = %d", quest.QuestType)
		}
	}
	return callData, nil
}

func BuildSkillData(l *zap.SugaredLogger, dataConfig common.DataConfig, fromSkillID int) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len Skills", "value", len(dataConfig.Skills))
	var skills []common.Skill
	for k, skill := range dataConfig.Skills {
		if k != strconv.FormatInt(int64(skill.Id), 10) {
			l.Errorw("wrong skill key and id", "key", k, "id", skill.Id)
			return nil, fmt.Errorf("wrong skill key and id %s %d", k, skill.Id)
		}
		skills = append(skills, skill)
	}
	sort.Slice(skills, func(i, j int) bool {
		return skills[i].Id < skills[j].Id
	})
	once := sync.Once{}
	for _, skill := range skills {
		if skill.Id < fromSkillID {
			continue
		}
		once.Do(func() {
			l.Infow("Skill starts from ID", "value", fromSkillID)
		})
		skillCallData, err := table.SkillCallData(skill)
		if err != nil {
			l.Errorw("cannot build Skill call data", "err", err)
			return nil, err
		}
		callData = append(callData, skillCallData)
		if skill.Effect != nil {
			skillEffectCallData, err := table.SkillEffectCallData(skill.Id, *skill.Effect)
			if err != nil {
				l.Errorw("cannot build SkillEffect call data", "err", err)
				return nil, err
			}
			callData = append(callData, skillEffectCallData)
		}
	}
	return callData, nil
}

func BuildMonsterData(l *zap.SugaredLogger, dataConfig common.DataConfig, fromMonsterID int, resetBossData bool) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len Monsters", "value", len(dataConfig.Monsters))
	var monsters []common.Monster
	for k, monster := range dataConfig.Monsters {
		if k != strconv.FormatInt(int64(monster.Id), 10) {
			l.Errorw("wrong monster key and id", "key", k, "id", monster.Id)
			return nil, fmt.Errorf("wrong monster key and id %s %d", k, monster.Id)
		}
		monsters = append(monsters, monster)
	}
	sort.Slice(monsters, func(i, j int) bool {
		return monsters[i].Id < monsters[j].Id
	})
	once := sync.Once{}
	for _, monster := range monsters {
		if monster.Id < fromMonsterID {
			continue
		}
		once.Do(func() {
			l.Infow("Monster starts from ID", "value", fromMonsterID)
		})
		// monster info
		monsterCallData, err := table.MonsterCallData(monster)
		if err != nil {
			l.Errorw("cannot build Monster call data", "err", err)
			return nil, err
		}
		callData = append(callData, monsterCallData)
		// monster stats
		monsterStatsCallData, err := table.MonsterStatsCallData(monster.Id, monster.Stats)
		if err != nil {
			l.Errorw("cannot build MonsterStats call data", "err", err)
			return nil, err
		}
		callData = append(callData, monsterStatsCallData)

		// boss stats
		if monster.BossInfo != nil && resetBossData {
			for _, ml := range dataConfig.MonsterLocationsBoss {
				if ml.MonsterId == monster.Id {
					for _, location := range ml.Locations {
						// l.Infow("data", "value", location, "monster", monster.BossInfo)
						bossInfosCallData, err := table.BossInfosCallData(monster.Id, *monster.BossInfo, location.X, location.Y)
						if err != nil {
							l.Errorw("cannot build BossInfo call data", "err", err)
							return nil, err
						}
						callData = append(callData, bossInfosCallData)
					}
				}
			}
		}
	}
	return callData, nil
}

func BuildMonsterLocationData(l *zap.SugaredLogger, monsterLocations []common.MonsterLocation) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len MonsterLocations", "value", len(monsterLocations))
	for _, monsterLocation := range monsterLocations {
		for _, location := range monsterLocation.Locations {
			// monster location
			monsterLocationCallData, err := table.MonsterLocationCallData(
				location, monsterLocation.MonsterId, monsterLocation.Level, monsterLocation.AdvantageType)
			if err != nil {
				l.Errorw("cannot build MonsterLocation call data", "err", err)
				return nil, err
			}
			callData = append(callData, monsterLocationCallData)
		}
	}
	return callData, nil
}

func BuildAchievementData(l *zap.SugaredLogger, dataConfig common.DataConfig, fromAchievementID int) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len Achievements", "value", len(dataConfig.Achievements))
	var (
		achievements []common.Achievement
	)
	for k, achievement := range dataConfig.Achievements {
		if k != strconv.FormatInt(int64(achievement.Id), 10) {
			l.Errorw("wrong achievement key and id", "key", k, "id", achievement.Id)
			return nil, fmt.Errorf("wrong achievement key and id %s %d", k, achievement.Id)
		}
		achievements = append(achievements, achievement)
	}
	sort.Slice(achievements, func(i, j int) bool {
		return achievements[i].Id < achievements[j].Id
	})
	once := sync.Once{}
	for _, achievement := range achievements {
		if achievement.Id < fromAchievementID {
			continue
		}
		once.Do(func() {
			l.Infow("Achievement starts from ID", "value", fromAchievementID)
		})
		achievementCallData, err := table.AchievementCallData(achievement)
		if err != nil {
			l.Errorw("cannot build Achievement call data", "err", err)
			return nil, err
		}
		callData = append(callData, achievementCallData)
	}
	return callData, nil
}

func BuildDailyQuestData(l *zap.SugaredLogger, dataConfig common.DataConfig, fromAchievementID int) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len DailyQuests", "value", dataConfig.DailyQuestConfig)
	data, err := table.DailyQuestConfigCallData(dataConfig.DailyQuestConfig)
	if err != nil {
		l.Errorw("cannot build DailyQuest call data", "err", err)
		return nil, err
	}
	callData = append(callData, data)
	return callData, nil
}

func BuildItemWeightCacheData(l *zap.SugaredLogger, dataConfig common.DataConfig) ([][]byte, error) {
	callData := make([][]byte, 0)
	l.Infow("len Items", "value", dataConfig.Items)
	for _, item := range dataConfig.Items {
		if item.EquipmentInfo != nil {
			data, err := table.ItemWeightCacheCallData(item)
			if err != nil {
				l.Errorw("cannot build ItemWeightCache call data", "err", err)
				return nil, err
			}
			callData = append(callData, data)
		}
	}
	return callData, nil
}

func BuildResourceDropData(l *zap.SugaredLogger, dataConfig common.DataConfig) ([][]byte, error) {
	data, err := table.DropResourceCallData(dataConfig, 5) // drop from tier 5
	if err != nil {
		l.Errorw("cannot build DropResource call data", "err", err)
		return nil, err
	}
	return [][]byte{data}, nil
}

func BuildCollectionExcData(l *zap.SugaredLogger, dataConfig common.DataConfig, fromItemExchangeID int) ([][]byte, error) {
	callData := make([][]byte, 0)
	for _, itemEx := range dataConfig.ItemExchanges {
		if itemEx.ItemId < fromItemExchangeID {
			continue
		}
		itemExCallData, err := table.CollectionExcCallData(itemEx)
		if err != nil {
			l.Errorw("cannot build ItemExchange call data", "err", err)
			return nil, err
		}
		callData = append(callData, itemExCallData)
	}
	return callData, nil
}
