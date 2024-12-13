package gentile

import (
	"math/rand"
	"strconv"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

func genMonsterInfos(
	kingdomId int,
	rawSortedAllTiles []common.Location,
	monsterIds []int,
	mapMonster map[string]common.Monster,
	customMonsterLocations []common.MonsterLocation, // this custom will set the whole tile monster data
) []common.MonsterLocation {
	var (
		l = zap.S().With("func", "genMonsterInfos", "kingdomId", kingdomId)
	)
	if len(monsterIds) == 0 {
		l.Panic("invalid monster ids len 0")
	} else {
		l.Infow("list monster", "value", monsterIds)
	}
	mapCustomMonsterLocation := make(map[common.Location]bool)
	for _, cml := range customMonsterLocations {
		for _, l := range cml.Locations {
			mapCustomMonsterLocation[l] = true
		}
	}
	sortedAllTiles := make([]common.Location, 0)
	for _, tile := range rawSortedAllTiles {
		if !mapCustomMonsterLocation[tile] {
			sortedAllTiles = append(sortedAllTiles, tile)
		}
	}
	l.Infow("len tiles", "sortedAllTiles", len(sortedAllTiles), "rawSortedAllTiles", len(rawSortedAllTiles))
	// distribute
	allMonsterLocations := make([]common.MonsterLocation, 0)
	tilesMonsters := buildTilesMonsters(sortedAllTiles, monsterIds, mapMonster)
	for _, tm := range tilesMonsters {
		monsterLocations := distributeMonsterLocation(tm.Tiles, tm.MonsterIds, tm.MonsterRangeLevel)
		l.Infow("distributed monster location", "monsterLocations", len(monsterLocations), "tm.Tiles", len(tm.Tiles))
		allMonsterLocations = append(allMonsterLocations, monsterLocations...)
	}
	return allMonsterLocations
}

func buildTilesMonsters(sortedAllTiles []common.Location, monsterIds []int, mapMonster map[string]common.Monster) []TilesMonsters {
	l := zap.S().With("func", "buildTilesMonsters")
	result := []TilesMonsters{}
	splitNum := len(monsterIds) - 1
	splitTiles := splitAllTiles(sortedAllTiles, splitNum, -0.07)
	for i := 0; i < splitNum; i++ {
		m1IdString := strconv.FormatInt(int64(monsterIds[i]), 10)
		m1Info, ok := mapMonster[m1IdString]
		if !ok {
			l.Panicw("no monster data", "m1IdString", m1IdString)
		}
		m2IdString := strconv.FormatInt(int64(monsterIds[i+1]), 10)
		m2Info, ok := mapMonster[m2IdString]
		if !ok {
			l.Panicw("no monster data", "m2IdString", m2IdString)
		}
		m1LowLevel := (m1Info.Levels[0] + m1Info.Levels[1]) / 2
		m1HighLevel := m1Info.Levels[1]
		m2LowLevel := m2Info.Levels[0]
		m2HighLevel := (m2Info.Levels[0] + m2Info.Levels[1]) / 2
		if i == 0 {
			m1LowLevel = m1Info.Levels[0]
		}
		if i == splitNum-1 {
			m2HighLevel = m2Info.Levels[1]
		}
		element := TilesMonsters{
			Tiles:      splitTiles[i],
			MonsterIds: [2]int{monsterIds[i], monsterIds[i+1]},
			MonsterRangeLevel: [2][2]int{
				{
					m1LowLevel, m1HighLevel,
				},
				{
					m2LowLevel, m2HighLevel,
				},
			},
		}
		l.Infow("element tilesMonsters", "monster Ids", element.MonsterIds, "MonsterRangeLevel", element.MonsterRangeLevel)
		result = append(result, element)
	}
	// l.Panicw("data", "value", result)
	if len(result) != splitNum {
		l.Panicw("invalid tilesMonsters", "splitNum", splitNum, "len(result)", len(result))
	}
	return result
}

type TilesMonsters struct {
	Tiles             []common.Location
	MonsterIds        [2]int
	MonsterRangeLevel [2][2]int
}

type EasyMonster struct {
	ID    int
	Level int
	Adv   int
}

func generateArrAdvantageType(len int) []int {
	return generateArrRandomValue(len, 4)
}

func generateArrRandomValue(len int, value int) []int {
	arr := make([]int, len)
	for i := range arr {
		arr[i] = rand.Intn(value)
	}
	return arr
}

func distributeMonsterLocation(sortedAllTiles []common.Location,
	monsterIds [2]int, monsterRangeLevels [2][2]int) []common.MonsterLocation {
	l := zap.S().With("func", "distributeMonsterLocation")
	rawMonsters := [][]EasyMonster{}
	lenAllTiles := len(sortedAllTiles)
	for index, monsterId := range monsterIds {
		eMonsterArr := createEasyMonsterArr(lenAllTiles, monsterRangeLevels[index], monsterId)
		rawMonsters = append(rawMonsters, eMonsterArr)
	}

	// all eMonsterArr must has same len
	eMonsterLen := len(rawMonsters[0])
	for _, v := range rawMonsters {
		if len(v) != eMonsterLen {
			l.Panicw("wrong raw monsters data", "eMonsterLen", eMonsterLen, "actual len", len(v))
		}
	}

	// remove random monster
	rArr := generateArrRandomValue(eMonsterLen, len(rawMonsters)*4)
	l.Infow("rArr", "value", rArr, "eMonsterLen", eMonsterLen)
	for index, rArrV := range rArr {
		if rArrV < len(rawMonsters) {
			rawMonsters[rArrV][index].Level = 0
		}
	}

	result := make([]common.MonsterLocation, 0)
	for _, rawMonster := range rawMonsters {
		mapEMLocation := make(map[EasyMonster][]common.Location)
		arrAdv := generateArrAdvantageType(len(rawMonster))
		for index, rMon := range rawMonster {
			rMon.Adv = arrAdv[index]
			mapEMLocation[rMon] = append(mapEMLocation[rMon], sortedAllTiles[index])
		}
		// test len and build data
		pieceData := make([]common.MonsterLocation, 0)
		sumLen := 0
		for k, v := range mapEMLocation {
			cv := make([]common.Location, len(v))
			copy(cv, v)
			// rand.Shuffle(len(cv), func(i, j int) {
			// 	cv[i], cv[j] = cv[j], cv[i]
			// })
			// startIndex := len(cv) / 6 // remove some items to make less monster in location 15%
			// cv = cv[startIndex:]
			sumLen += len(cv)
			if k.Level > 0 {
				pieceData = append(pieceData, common.MonsterLocation{
					Locations:     cv,
					MonsterId:     k.ID,
					Level:         k.Level,
					AdvantageType: k.Adv,
				})
			} else {
				l.Infow("remove", "len", len(cv))
			}
		}
		l.Infow("len map monster", "value", len(mapEMLocation), "total element", sumLen)
		result = append(result, pieceData...)
	}
	l.Infow("final result", "data", len(result))
	return result
}

// createEasyMonsterArr create array of monster with id, level, adv
func createEasyMonsterArr(totalLen int, levels [2]int, monsterId int) []EasyMonster {
	l := zap.S().With("func", "createEasyMonsterArr", "monsterId", monsterId, "levels", levels)
	if levels[1]-levels[0] == 0 {
		l.Panicw("invalid levels", "monsterId", monsterId)
	}
	repeatsPerLevel := totalLen / (levels[1] - levels[0] + 1)
	if repeatsPerLevel == 0 {
		l.Panicw("repeatsPerLevel is zero", "monsterId", monsterId)
	}
	remain := totalLen % (levels[1] - levels[0] + 1)
	// l.Infow("data", "totalLen", totalLen, "repeatsPerLevel", repeatsPerLevel, "remain", remain)

	// Create an array with the specified size
	rawResult := make([]EasyMonster, 0, totalLen)

	// Fill the array
	for level := levels[0]; level <= levels[1]; level++ {
		for count := 0; count < repeatsPerLevel; count++ {
			rawResult = append(rawResult, EasyMonster{
				ID:    monsterId,
				Level: level,
			})
			if remain > 0 {
				rawResult = append(rawResult, EasyMonster{
					ID:    monsterId,
					Level: level,
				})
				remain--
			}
		}
	}
	// shuffle
	result := make([]EasyMonster, 0)
	subArrays := splitEasyMonsterArr(rawResult, 4)
	for _, subArr := range subArrays {
		cSubArr := make([]EasyMonster, len(subArr))
		copy(cSubArr, subArr)
		rand.Shuffle(len(cSubArr), func(i, j int) {
			cSubArr[i], cSubArr[j] = cSubArr[j], cSubArr[i]
		})
		result = append(result, cSubArr...)
	}
	l.Infow("monster arr len", "value", len(result))
	return result
}

// splitEasyMonsterArr splits an array
func splitEasyMonsterArr(arr []EasyMonster, numPart int) [][]EasyMonster {
	totalLength := len(arr)
	partSize := totalLength / numPart
	remainder := totalLength % numPart

	result := make([][]EasyMonster, numPart)
	startIndex := 0

	for i := 0; i < numPart; i++ {
		// Calculate the end index for the current part
		endIndex := startIndex + partSize
		if remainder > 0 {
			// Distribute remainder one by one to each part until exhausted
			endIndex++
			remainder--
		}

		// Assign the subArray to the result
		result[i] = arr[startIndex:endIndex]
		startIndex = endIndex
	}

	return result
}
