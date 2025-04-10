package main

import (
	"fmt"

	calldata "github.com/ftk/post-deploy/call-data"
	"github.com/ftk/post-deploy/pkg/common"
	gentile "github.com/ftk/post-deploy/pkg/gen-tile"
	"github.com/ftk/post-deploy/pkg/table"
	"go.uber.org/zap"
)

func buildCallData(
	dataConfig common.DataConfig,
	mapConfig []gentile.KingdomMap,
	cacheMonsterLocations []common.MonsterLocation,
	cacheTileInfos []common.TileInfo,
	isTest bool) ([][]byte, error) {
	l := zap.S().With("func", "buildCallData")

	// map config
	var callData [][]byte
	mapConfigCallData, err := table.MapConfigCallData()
	if err != nil {
		l.Errorw("cannot build MapConfig call data", "err", err)
		return nil, err
	}
	callData = append(callData, mapConfigCallData)

	// achievement ~
	l.Infow("len Achievements", "value", len(dataConfig.Achievements))
	achievementCallData, err := calldata.BuildAchievementData(l, dataConfig, 0)
	if err != nil {
		l.Errorw("cannot build achievementCallData", "err", err)
		return nil, err
	}
	callData = append(callData, achievementCallData...)

	// city ~ also npc shop
	cityCallData, cities, err := calldata.BuildCityData(l, dataConfig)
	if err != nil {
		l.Errorw("cannot build cityCallData", "err", err)
		return nil, err
	}
	callData = append(callData, cityCallData...)

	// npc shop
	npcShopCallData, err := calldata.BuildNpcShopData(l, dataConfig)
	if err != nil {
		l.Errorw("cannot build npcShopCallData", "err", err)
		return nil, err
	}
	callData = append(callData, npcShopCallData...)

	// kingdom
	kingdomCallData, err := calldata.BuildKingdomData(l, dataConfig)
	if err != nil {
		l.Errorw("cannot build kingdomCallData", "err", err)
		return nil, err
	}
	callData = append(callData, kingdomCallData...)

	/* gen tile info and resource location */
	var (
		tileInfos        []common.TileInfo
		monsterLocations []common.MonsterLocation
	)

	if isTest {
		// set data test
		tileInfos = dataConfig.TileInfos
		monsterLocations = dataConfig.MonsterLocationsOverride
		monsterLocations = append(monsterLocations, dataConfig.MonsterLocationsBoss...)
	} else {
		// regularMap := mapConfig[:4]
		regularMap := mapConfig[:]
		// random generate tile infos and resource location
		tileInfos, monsterLocations = gentile.GenMapData(
			dataConfig, regularMap, cities, cacheTileInfos, cacheMonsterLocations,
			dataConfig.MonsterLocationsOverride, dataConfig.MonsterLocationsBoss, dataConfig.Monsters)

		// middle map ~ done comment now
		// _, middleMonsterLocations := gentile.GenMapData(
		// 	dataConfig, mapConfig[4:], cities, nil, nil, nil, dataConfig.MonsterLocationsBoss, dataConfig.Monsters)
		// tileInfos = append(tileInfos, middleTileInfos...)
		// monsterLocations = middleMonsterLocations
		// monsterLocations = append(monsterLocations, middleMonsterLocations...)

		if len(cacheMonsterLocations) == 0 {
			// store cache file
			cacheData := struct {
				MonsterLocationsCache []common.MonsterLocation `json:"monsterLocationsCache"`
			}{
				MonsterLocationsCache: monsterLocations,
			}
			path := "../../data-config/monsterLocationsCache.json"
			if err := common.WriteJSONFile(cacheData, path); err != nil {
				l.Errorw("cannot write cache monster locations", "err", err)
			} else {
				l.Infow("write cache monster locations successfully")
			}
			// store for front-end
			mapLocationMonsters := make(map[common.Location][]common.MonsterLocationDetail)
			for _, mls := range monsterLocations {
				for _, location := range mls.Locations {
					mapLocationMonsters[location] = append(mapLocationMonsters[location], common.MonsterLocationDetail{
						MonsterId:     mls.MonsterId,
						Level:         mls.Level,
						AdvantageType: mls.AdvantageType,
					})
				}
			}
			mapLocationStringMonsters := make(map[string][]common.MonsterLocationDetail)
			for location, monsters := range mapLocationMonsters {
				mapLocationStringMonsters[fmt.Sprintf("%d_%d", location.X, location.Y)] = monsters
			}
			cacheFEData := struct {
				MonsterLocations map[string][]common.MonsterLocationDetail `json:"monsterLocations"`
			}{
				MonsterLocations: mapLocationStringMonsters,
			}
			if err := common.WriteJSONFile(cacheFEData, "../../data-config/monsterLocations.json"); err != nil {
				l.Errorw("cannot write monsterLocations", "err", err)
			} else {
				l.Infow("write monsterLocations successfully")
			}
		}
	}
	// remove all kingdom id ~ because now player need to occupy the tile
	for index := range tileInfos {
		tileInfos[index].KingdomId = 0
	}
	// add city back to tile info
	for _, city := range cities {
		tileInfos = append(tileInfos, common.TileInfo{
			KingdomId:       city.KingdomId,
			X:               city.X,
			Y:               city.Y,
			FarmSlot:        0,
			ZoneType:        0,
			ResourceItemIds: nil,
		})
	}

	// item
	itemCallData, err := calldata.BuildItemData(l, dataConfig, 0)
	if err != nil {
		l.Errorw("cannot build itemCallData", "err", err)
		return nil, err
	}
	callData = append(callData, itemCallData...)

	// extra item info (equipment info, consumable info)
	itemExtraInfoData, err := calldata.BuildExtraItemInfoData(l, dataConfig, 0)
	if err != nil {
		l.Errorw("cannot build itemExtraInfoData", "err", err)
		return nil, err
	}
	callData = append(callData, itemExtraInfoData...)

	// item recipe
	itemRecipeCallData, err := calldata.BuildItemRecipeData(l, dataConfig, 0)
	if err != nil {
		l.Errorw("cannot build itemRecipeCallData", "err", err)
		return nil, err
	}
	callData = append(callData, itemRecipeCallData...)

	// welcome config
	l.Infow("welcomeConfig", "value", dataConfig.WelcomeConfig)
	welcomeConfigCallData, err := table.WelcomeConfigCallData(dataConfig.WelcomeConfig)
	if err != nil {
		l.Errorw("cannot build Welcome Config call data", "err", err)
		return nil, err
	}
	callData = append(callData, welcomeConfigCallData)

	// npc
	npcCallData, err := calldata.BuildNpcData(l, dataConfig)
	if err != nil {
		l.Errorw("cannot build npcCallData", "err", err)
		return nil, err
	}
	callData = append(callData, npcCallData...)

	// quest
	questCallData, err := calldata.BuildQuestData(l, dataConfig, 0)
	if err != nil {
		l.Errorw("cannot build questCallData", "err", err)
		return nil, err
	}
	callData = append(callData, questCallData...)

	// skills
	skillCallData, err := calldata.BuildSkillData(l, dataConfig, 0)
	if err != nil {
		l.Errorw("cannot build skillCallData", "err", err)
		return nil, err
	}
	callData = append(callData, skillCallData...)

	// monsters
	monsterCallData, err := calldata.BuildMonsterData(l, dataConfig, 0)
	if err != nil {
		l.Errorw("cannot build monsterCallData", "err", err)
		return nil, err
	}
	callData = append(callData, monsterCallData...)

	// daily quest config
	l.Infow("DailyQuestConfig", "value", dataConfig.DailyQuestConfig)
	dailyQuestConfigData, err := table.DailyQuestConfigCallData(dataConfig.DailyQuestConfig)
	if err != nil {
		l.Errorw("cannot build MapConfig call data", "err", err)
		return nil, err
	}
	callData = append(callData, dailyQuestConfigData)

	// custom to update tile and monster location
	var customCallData [][]byte
	// tile infos
	var allTileInfoCallData [][]byte
	for _, ti := range tileInfos {
		tileInfoCallData, err := table.TileInfoCallData(ti, dataConfig)
		if err != nil {
			l.Errorw("cannot build TileInfo call data", "err", err)
			return nil, err
		}

		allTileInfoCallData = append(allTileInfoCallData, tileInfoCallData)
	}
	// return allTileInfoCallData, nil
	callData = append(callData, allTileInfoCallData...)
	// customCallData = append(customCallData, allTileInfoCallData...)

	// monster locations
	monsterLocationData, err := calldata.BuildMonsterLocationData(l, monsterLocations)
	if err != nil {
		l.Errorw("cannot build monsterLocationData", "err", err)
		return nil, err
	}
	callData = append(callData, monsterLocationData...)
	customCallData = append(customCallData, monsterLocationData...)

	// return customCallData, nil

	return callData, nil
}
