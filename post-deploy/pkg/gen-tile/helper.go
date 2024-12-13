package gentile

import (
	"math"
	"sort"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

// locations must be in order top-left, top-right, bottom-right, bottom-left
func getAllTiles(locations [4]common.Location) []common.Location {
	var allTiles []common.Location
	if locations[0].X < locations[1].X {
		for i := locations[0].X; i <= locations[1].X; i++ {
			if locations[3].Y < locations[0].Y {
				for j := locations[3].Y; j <= locations[0].Y; j++ {
					allTiles = append(allTiles, common.Location{
						X: i,
						Y: j,
					})
				}
			} else {
				zap.S().Panicw("wrong order of zone location config, locations[3].Y > locations[0].Y", "locations", locations)
				// for j := rangeValueY[1]; j <= rangeValueY[0]; j++ {
				// 	allTiles = append(allTiles, common.Location{
				// 		X: i,
				// 		Y: j,
				// 	})
				// }
			}
		}
	} else {
		zap.S().Panicw("wrong order of zone location config, locations[0].X > locations[1].X", "locations", locations)
		// for i := rangeValueX[1]; i <= rangeValueX[0]; i++ {
		// 	if rangeValueY[0] < rangeValueY[1] {
		// 		for j := rangeValueY[0]; j <= rangeValueY[1]; j++ {
		// 			allTiles = append(allTiles, common.Location{
		// 				X: i,
		// 				Y: j,
		// 			})
		// 		}
		// 	} else {
		// 		for j := rangeValueY[1]; j <= rangeValueY[0]; j++ {
		// 			allTiles = append(allTiles, common.Location{
		// 				X: i,
		// 				Y: j,
		// 			})
		// 		}
		// 	}
		// }
	}
	return allTiles
}

func removeTile(allTiles []common.Location, rTile common.Location) []common.Location {
	newArr := make([]common.Location, 0)
	for _, tile := range allTiles {
		if tile.X == rTile.X && tile.Y == rTile.Y {
			continue
		}
		newArr = append(newArr, tile)
	}
	return newArr
}

func removeDupTile(allTiles []common.Location) []common.Location {
	newArr := make([]common.Location, 0)
	mapTile := make(map[common.Location]bool)
	dupCount := 0
	for _, tile := range allTiles {
		if mapTile[tile] {
			dupCount++
			continue
		}
		newArr = append(newArr, tile)
		mapTile[tile] = true
	}
	zap.S().Infow("dupCount", "value", dupCount)
	return newArr
}

func validateZoneLocations(kingdomId int, locations [4]common.Location) {
	l := zap.S().With("kingdomId", kingdomId, "locations", locations)
	if locations[0].X > locations[1].X {
		l.Panic("invalid location X - 0 1 ")
	}
	if locations[1].Y < locations[2].Y {
		l.Panic("invalid location Y - 1 2")
	}
	if locations[2].X < locations[3].X {
		l.Panic("invalid location X - 2 3")
	}
	if locations[0].Y != locations[1].Y {
		l.Panic("must equal Y - 0 1")
	}
	if locations[1].X != locations[2].X {
		l.Panic("must equal X - 1 2")
	}
	if locations[2].Y != locations[3].Y {
		l.Panic("must equal Y - 2 3")
	}
	if locations[3].X != locations[0].X {
		l.Panic("must equal X - 3 0")
	}
}

func sortTileByDistanceToCapital(allTiles []common.Location, capital common.Location) []common.Location {
	result := make([]common.Location, 0, len(allTiles))
	lExts := make([]locationExt, 0, len(allTiles))
	for _, tile := range allTiles {
		lExts = append(lExts, locationExt{
			Tile: tile,
			Distance: calculateDistance(tile, common.Location{
				X: capital.X,
				Y: capital.Y,
			}),
		})
	}
	sort.Slice(lExts, func(i, j int) bool {
		return lExts[i].Distance < lExts[j].Distance
	})
	for _, lExt := range lExts {
		result = append(result, lExt.Tile)
	}
	return result
}

func calculateDistance(tile, capital common.Location) float64 {
	return math.Sqrt(math.Pow(float64(tile.X-capital.X), 2) + math.Pow(float64(tile.Y-capital.Y), 2))
}

func sortItemByTier(mapItem map[string]common.Item) []common.Item {
	items := make([]common.Item, 0)
	for _, v := range mapItem {
		items = append(items, v)
	}
	sort.Slice(items, func(i, j int) bool {
		return items[i].Tier <= items[j].Tier
	})
	return items
}

// splitAllTiles splits an array
func splitAllTiles(arr []common.Location, numPart int, adjustRatio float64) [][]common.Location {
	result := make([][]common.Location, numPart)
	divisor := 0.0
	mulArr := make([]float64, 0)
	for i := numPart; i > 0; i-- {
		num := float64(i-1)*adjustRatio + 1
		divisor += num
		mulArr = append(mulArr, num)
	}
	index := 0
	minLen := float64(len(arr)) / divisor
	for i := 0; i < numPart; i++ {
		toIndex := index + int(minLen*mulArr[i])
		if i == numPart-1 {
			result[i] = arr[index:]
			break
		}
		result[i] = arr[index:toIndex]
		index = toIndex
	}
	return result
}
