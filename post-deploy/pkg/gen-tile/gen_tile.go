package gentile

import (
	"fmt"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

const (
	maxAutoGenResourceTier = 7
)

func GenMapData(
	dataConfig common.DataConfig,
	kingdomMaps []KingdomMap,
	cities []common.City,
	allTileInfosInZone []common.TileInfo, // this was provided as cached data
	allMonsterLocations []common.MonsterLocation, // this was provided as cached data
	overrideMonsterLocations []common.MonsterLocation, // this override the monster in tile
	customMonsterLocations []common.MonsterLocation, // this custom will set the whole tile monster data
	mapMonster map[string]common.Monster) (
	[]common.TileInfo,
	[]common.MonsterLocation) {
	l := zap.S().With("func", "GenMapData")
	// if no cache we need to generate
	shouldGenMonster := false
	if len(allMonsterLocations) == 0 { // no cache
		shouldGenMonster = true
		l.Infow("no cached monster locations, generating...")
	} else {
		l.Infow("we had cached monster locations")
	}
	shouldGenTileInfo := false
	if len(allTileInfosInZone) == 0 {
		shouldGenTileInfo = true
		l.Infow("no cached tile infos, generating...")
	} else {
		l.Infow("we had cached tile infos")
	}
	if !shouldGenMonster && !shouldGenTileInfo {
		l.Infow("we had all cached data and don't need to gen")
		// return allTileInfosInZone, allMonsterLocations
	} else {
		for _, kingdom := range kingdomMaps {
			var allTiles []common.Location
			for _, zone := range kingdom.Zones {
				validateZoneLocations(kingdom.ID, zone)
				allTiles = append(allTiles, getAllTiles(zone)...)
			}
			allTiles = removeDupTile(allTiles)
			l.Infow("all tiles", "kingdom", kingdom.ID, "len", len(allTiles))

			var capital common.City
			for _, city := range cities {
				if city.KingdomId == uint8(kingdom.ID) && city.IsCapital {
					capital = city
				}
				allTiles = removeTile(allTiles, common.Location{
					X: city.X,
					Y: city.Y,
				})
			}
			l.Infow("all tiles", "len", len(allTiles), "capital", capital)

			// sortedAllTiles is all tile in kingdom excludes the capital and city sorted by distance to capital
			sortedAllTiles := sortTileByDistanceToCapital(allTiles, common.Location{X: capital.X, Y: capital.Y})
			if len(sortedAllTiles) != len(allTiles) {
				l.Panicw("invalid sortedAllTiles len", "len sortedAllTiles", len(sortedAllTiles), "len allTiles", len(allTiles))
			}

			// mapResourceTypeIds map all resource type with its ids
			mapResourceTypeIds := getMapResourceTypeIds(kingdom, dataConfig)
			listResource := [6][]int64{}
			for i := range kingdom.Resources {
				listResource[i] = mapResourceTypeIds[kingdom.Resources[i]]
			}
			l.Infow("mapResourceTypeIds", "value", mapResourceTypeIds, "listResource", listResource)

			if shouldGenTileInfo {
				tilesMapResourceQty := buildTilesWithMapResourceQty(sortedAllTiles, listResource)
				kingdomTileInfos := make([]common.TileInfo, 0)
				for _, tm := range tilesMapResourceQty {
					subTileInfos := genKingdomTileInfos(kingdom.ID, tm.Tiles, tm.MapResourceQty)
					kingdomTileInfos = append(kingdomTileInfos, subTileInfos...)
				}
				// add zone
				lenSortedAllTiles := len(sortedAllTiles)
				for index := range kingdomTileInfos {
					kingdomTileInfos[index].ZoneType = getZone(index, lenSortedAllTiles)
				}
				// store file
				if err := writeTileInfosFile(kingdomTileInfos, kingdom.ID); err != nil {
					l.Panicw("cannot write file tile infos", "err", err)
				}
				allTileInfosInZone = append(allTileInfosInZone, kingdomTileInfos...)
			}

			if shouldGenMonster {
				monsterLocations := genMonsterInfos(
					kingdom.ID, sortedAllTiles, kingdom.MonsterIds,
					mapMonster, customMonsterLocations)
				if err := writeMonsterLocationsFile(monsterLocations, kingdom.ID); err != nil {
					l.Panicw("cannot write file monster locations", "err", err)
				}
				allMonsterLocations = append(allMonsterLocations, monsterLocations...)
			}
		}
	}

	// override data
	mapOverride := make(map[int][]common.Location)
	for _, ml := range overrideMonsterLocations {
		mapOverride[ml.MonsterId] = append(mapOverride[ml.MonsterId], ml.Locations...)
	}
	for index, aml := range allMonsterLocations {
		overrideLocations, ok := mapOverride[aml.MonsterId]
		if !ok {
			continue
		}
		overrideMap := make(map[common.Location]bool)
		for _, loc := range overrideLocations {
			overrideMap[loc] = true
		}
		newLocations := make([]common.Location, 0)
		for _, location := range aml.Locations {
			if !overrideMap[location] {
				newLocations = append(newLocations, location)
			}
		}
		allMonsterLocations[index].Locations = newLocations
	}
	allMonsterLocations = append(overrideMonsterLocations, allMonsterLocations...)

	// add custom monster location to result
	allMonsterLocations = append(customMonsterLocations, allMonsterLocations...)
	l.Infow("GenMapData data", "allTileInfosInZone len", len(allTileInfosInZone),
		"allMonsterLocations", len(allMonsterLocations))
	return allTileInfosInZone, allMonsterLocations
}

func writeMonsterLocationsFile(monsterLocations []common.MonsterLocation, kingdomId int) error {
	l := zap.S().With("func", "writeMonsterLocationsFile")
	path := fmt.Sprintf("monsterLocations_%d.json", kingdomId)
	if err := common.WriteJSONFile(monsterLocations, path); err != nil {
		l.Panicw("cannot write monster locations", "err", err)
	}
	l.Infow("write monster location file successfully")
	return nil
}

func writeTileInfosFile(tileInfos []common.TileInfo, kingdomId int) error {
	l := zap.S().With("func", "writeTileInfosFile")
	path := fmt.Sprintf("tileInfos_%d.json", kingdomId)
	if err := common.WriteJSONFile(tileInfos, path); err != nil {
		l.Panicw("cannot write tile infos", "err", err)
	}
	l.Infow("write tile infos file successfully")
	return nil
}

type TilesMapResourceQty struct {
	Tiles          []common.Location
	MapResourceQty map[int64]int
}

func buildTilesWithMapResourceQty(sortedAllTiles []common.Location, listResource [6][]int64) []TilesMapResourceQty {
	result := make([]TilesMapResourceQty, 0)
	l := zap.S().With("func", "buildTilesWithMapResourceQty")
	splitAllTiles := splitAllTiles(sortedAllTiles, 6, 0.05) // max is tier 7 and we group 2 each e.g (1,2), (2, 3)
	for index, sat := range splitAllTiles {
		mapResourceQty := make(map[int64]int)
		lenSat := len(sat)
		l.Infow("len split tile", "index", index, "len", lenSat)
		totalQty := float64(lenSat * 2)
		// ratio 4:3:2:1:1:1.
		mapResourceQty[listResource[0][index]] = int(totalQty / 12 * 4 * 0.8)
		mapResourceQty[listResource[0][index+1]] = int(totalQty / 12 * 4 * 0.2)
		mapResourceQty[listResource[1][index]] = int(totalQty / 12 * 3 * 0.8)
		mapResourceQty[listResource[1][index+1]] = int(totalQty / 12 * 3 * 0.2)
		mapResourceQty[listResource[2][index]] = int(totalQty / 12 * 2 * 0.8)
		mapResourceQty[listResource[2][index+1]] = int(totalQty / 12 * 2 * 0.2)
		mapResourceQty[listResource[3][index]] = int(totalQty / 12 * 1 * 0.8)
		mapResourceQty[listResource[3][index+1]] = int(totalQty / 12 * 1 * 0.2)
		mapResourceQty[listResource[4][index]] = int(totalQty / 12 * 1 * 0.8)
		mapResourceQty[listResource[4][index+1]] = int(totalQty / 12 * 1 * 0.2)
		mapResourceQty[listResource[5][index]] = int(totalQty / 12 * 1 * 0.8)
		mapResourceQty[listResource[5][index+1]] = int(totalQty / 12 * 1 * 0.2)
		l.Infow("mapResourceQty", "value", mapResourceQty)
		element := TilesMapResourceQty{
			Tiles:          sat,
			MapResourceQty: mapResourceQty,
		}
		result = append(result, element)
	}
	return result
}

func getMapResourceTypeIds(kingdom KingdomMap, dataConfig common.DataConfig) map[common.ResourceType][]int64 {
	l := zap.S().With("func", "getMapResourceTypeIds")
	mapResourceTypeIds := make(map[common.ResourceType][]int64)
	for _, r := range kingdom.Resources {
		valueEnum, ok := dataConfig.ResourceTypes[r]
		if !ok {
			l.Panicw("cannot get eum resource", "type", r)
		}
		listItems := sortItemByTier(dataConfig.Items)
		for _, item := range listItems {
			if item.ResourceInfo != nil && item.ResourceInfo.ResourceType == valueEnum {
				if item.Tier <= maxAutoGenResourceTier {
					mapResourceTypeIds[r] = append(mapResourceTypeIds[r], int64(item.Id))
				}
			}
		}
	}
	for k, v := range mapResourceTypeIds {
		if len(v) < 7 {
			l.Panicw("lack tier resource", "resource type", k)
		}
	}
	return mapResourceTypeIds
}
