package main

import (
	"fmt"
	"math"
	"sort"

	calldata "github.com/ftk/post-deploy/call-data"
	"github.com/ftk/post-deploy/pkg/common"
	gentile "github.com/ftk/post-deploy/pkg/gen-tile"
	"github.com/ftk/post-deploy/pkg/table"
	"go.uber.org/zap"
)

func getAllCachedDeployData(kingdoms []gentile.KingdomMap) ([]common.TileInfo, []common.MonsterLocation, error) {
	l := zap.S().With("func", "getAllCachedDeployData")
	tileInfos := make([]common.TileInfo, 0)
	monsterLocations := make([]common.MonsterLocation, 0)
	for _, kingdom := range kingdoms {
		cTileInfos, err := loadTileInfos(kingdom.ID)
		if err != nil {
			l.Errorw("cannot get tile info", "err", err)
			return nil, nil, err
		}
		tileInfos = append(tileInfos, cTileInfos...)

		// load monster location
		// if kingdom.ID < 5 {
		// 	continue
		// }
		cMonsterLocations, err := loadMonsterLocations(kingdom.ID)
		if err != nil {
			l.Errorw("cannot get monster location", "err", err)
			return nil, nil, err
		}
		monsterLocations = append(monsterLocations, cMonsterLocations...)
	}
	return tileInfos, monsterLocations, nil
}

// splitDeployData split tile infos and monster location in to 2 part
// return small part to deploy and the second one will be update later
func splitDeployData(
	kingdoms []gentile.KingdomMap, dataConfig common.DataConfig, reserveOutPutPath string, buildReserveData bool, dataPercent int64) (
	[]common.TileInfo, []common.MonsterLocation, error) {
	l := zap.S().With("func", "splitDeployData")
	processRatio := float64(dataPercent) / 100
	processTileInfos := make([]common.TileInfo, 0)
	processMonsterLocations := make([]common.MonsterLocation, 0)
	// reserve data will be write to different file
	reserveTileInfos := make([]common.TileInfo, 0)
	reserveMonsterLocations := make([]common.MonsterLocation, 0)
	for _, kingdom := range kingdoms {
		cTileInfos, err := loadTileInfos(kingdom.ID)
		if err != nil {
			l.Errorw("cannot get tile info", "err", err)
			return nil, nil, err
		}
		if len(cTileInfos) == 0 {
			// no cache
			return nil, nil, nil
		}
		index := int(float64(len(cTileInfos)) * processRatio)
		processTileInfos = append(processTileInfos, cTileInfos[:index]...)
		reserveTileInfos = append(reserveTileInfos, cTileInfos[index:]...)
		l.Infow("split tile infos", "kingdom", kingdom.ID, "len full", len(cTileInfos),
			"len process", len(cTileInfos[:index]))
		// load monster location
		cMonsterLocations, err := loadMonsterLocations(kingdom.ID)
		if err != nil {
			l.Errorw("cannot get monster location", "err", err)
			return nil, nil, err
		}
		if len(cMonsterLocations) == 0 {
			// no cache
			return nil, nil, nil
		}
		capital := dataConfig.Cities[fmt.Sprintf("%d", kingdom.ID)]
		if capital.Id == 0 {
			panic("wrong capital")
		}
		cProcessMonsterLocations, cReserveMonsterLocations := splitMonster(common.Location{
			X: capital.X,
			Y: capital.Y,
		}, cMonsterLocations, processRatio)
		processMonsterLocations = append(processMonsterLocations, cProcessMonsterLocations...)
		reserveMonsterLocations = append(reserveMonsterLocations, cReserveMonsterLocations...)
	}
	if buildReserveData {
		writeReserveData(reserveTileInfos, reserveMonsterLocations, dataConfig, reserveOutPutPath)
	}
	return processTileInfos, processMonsterLocations, nil
}

func writeReserveData(
	tileInfos []common.TileInfo,
	monsterLocations []common.MonsterLocation,
	dataConfig common.DataConfig,
	reserveOutPutPath string) error {
	var (
		callData [][]byte
		l        = zap.S().With("func", "writeReserveData")
	)
	for _, ti := range tileInfos {
		tileInfoCallData, err := table.TileInfoCallData(ti, dataConfig)
		if err != nil {
			l.Errorw("cannot build TileInfo call data", "err", err)
			return err
		}
		callData = append(callData, tileInfoCallData)
	}

	monsterLocationData, err := calldata.BuildMonsterLocationData(l, monsterLocations)
	if err != nil {
		l.Errorw("cannot build monsterLocationData", "err", err)
		return err
	}
	callData = append(callData, monsterLocationData...)
	return writeLineToFile(reserveOutPutPath, callData)
}

func splitMonster(
	capital common.Location,
	cMonsterLocations []common.MonsterLocation,
	processRatio float64) (
	[]common.MonsterLocation,
	[]common.MonsterLocation) {
	dmlArr := make([]DistanceMonsterLocation, 0)
	for _, ml := range cMonsterLocations {
		for _, l := range ml.Locations {
			dmlArr = append(dmlArr, DistanceMonsterLocation{
				Distance:      calculateDistance(l, capital),
				Location:      l,
				MonsterId:     ml.MonsterId,
				Level:         ml.Level,
				AdvantageType: ml.AdvantageType,
			})
		}
	}
	sort.Slice(dmlArr, func(i, j int) bool {
		return dmlArr[i].Distance < dmlArr[j].Distance
	})
	index := int(float64(len(dmlArr)) * processRatio)
	processDml := dmlArr[:index]
	reserveDml := dmlArr[index:]
	zap.S().Infow("split monster locations", "len full", len(dmlArr),
		"len process", len(processDml))
	return arrDmlToArrMl(processDml), arrDmlToArrMl(reserveDml)
}

type DistanceMonsterLocation struct {
	Distance      float64
	Location      common.Location
	MonsterId     int
	Level         int
	AdvantageType int
}

type MonsterL struct {
	MonsterId     int
	Level         int
	AdvantageType int
}

func arrDmlToArrMl(arrDml []DistanceMonsterLocation) []common.MonsterLocation {
	mapMonsterLocation := make(map[MonsterL][]common.Location)
	for _, dml := range arrDml {
		ml := MonsterL{
			MonsterId:     dml.MonsterId,
			Level:         dml.Level,
			AdvantageType: dml.AdvantageType,
		}
		mapMonsterLocation[ml] = append(mapMonsterLocation[ml], dml.Location)
	}
	result := make([]common.MonsterLocation, 0)
	for ml, ls := range mapMonsterLocation {
		result = append(result, common.MonsterLocation{
			Locations:     ls,
			MonsterId:     ml.MonsterId,
			Level:         ml.Level,
			AdvantageType: ml.AdvantageType,
		})
	}
	return result
}

func calculateDistance(tile, capital common.Location) float64 {
	return math.Sqrt(math.Pow(float64(tile.X-capital.X), 2) + math.Pow(float64(tile.Y-capital.Y), 2))
}
