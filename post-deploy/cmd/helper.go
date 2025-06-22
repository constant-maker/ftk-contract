package main

import (
	"fmt"
	"os"

	"github.com/ftk/post-deploy/pkg/common"
	gentile "github.com/ftk/post-deploy/pkg/gen-tile"
	"go.uber.org/zap"
)

// loadTileInfos load tileInfo from cache file
func loadTileInfos(kingdomId int) ([]common.TileInfo, error) {
	var (
		result []common.TileInfo
		l      = zap.S().With("func", "loadTileInfos")
	)
	fileName := fmt.Sprintf("./tileInfos_%d.json", kingdomId)
	if _, err := os.Stat(fileName); os.IsNotExist(err) {
		fmt.Println("file does not exist.")
		return nil, nil
	}
	if err := common.ParseFile(fileName, &result); err != nil {
		l.Errorw("cannot parse mapConfig", "err", err)
		return result, err
	}
	return result, nil
}

// // loadTileResources load resource from cache file
// func loadTileResources(kingdomId int) ([][]gentile.Resource, error) {
// 	var (
// 		result [][]gentile.Resource
// 		l      = zap.S().With("func", "loadTileResources")
// 	)
// 	fileName := fmt.Sprintf("./resourceDistribution_%d.json", kingdomId)
// 	if _, err := os.Stat(fileName); os.IsNotExist(err) {
// 		fmt.Println("file does not exist.")
// 		return nil, nil
// 	}
// 	if err := common.ParseFile(fileName, &result); err != nil {
// 		l.Errorw("cannot parse mapConfig", "err", err)
// 		return result, err
// 	}
// 	return result, nil
// }

// loadMonsterLocations load monster location from cache file
func loadMonsterLocations(kingdomId int) ([]common.MonsterLocation, error) {
	var (
		result []common.MonsterLocation
		l      = zap.S().With("func", "loadTileResources")
	)
	fileName := fmt.Sprintf("./monsterLocations_%d.json", kingdomId)
	if _, err := os.Stat(fileName); os.IsNotExist(err) {
		fmt.Println("file does not exist.")
		return nil, nil
	}
	if err := common.ParseFile(fileName, &result); err != nil {
		l.Errorw("cannot parse mapConfig", "err", err)
		return result, err
	}
	return result, nil
}

func getMapConfig() ([]gentile.KingdomMap, error) {
	var (
		result []gentile.KingdomMap
		l      = zap.S().With("func", "getMapConfig")
	)
	if err := common.ParseFile("./mapConfig.json", &result); err != nil {
		l.Errorw("cannot parse mapConfig", "err", err)
		return result, err
	}
	return result, nil
}

func getDataConfig(isTest bool) (common.DataConfig, error) {
	var (
		dataConfig common.DataConfig
		l          = zap.S().With("func", "getDataConfig")
		dir        = "../../data-config"
		files      = []string{
			"characterQuestions.json", "items.json", "itemRecipes.json", "map.json", "quests.json",
			"tileInfos.json", "types.json", "welcomeConfig.json", "skills.json",
			"monsters.json", "monsterLocationsCache.json", "monsterLocationsOverride.json", "monsterLocationsBoss.json",
			"achievements.json",
		}
	)
	if isTest {
		dir = "../../data-config-test"
	}
	for _, f := range files {
		filePath := fmt.Sprintf("%s/%s", dir, f)
		if err := common.ParseFile(filePath, &dataConfig); err != nil {
			l.Errorw("cannot parse config", "err", err, "file", filePath)
			return dataConfig, err
		}
	}
	return dataConfig, nil
}
