package gentile

import (
	"math/rand"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

func getZone(index, totalLen int) uint8 {
	green := totalLen * 30 / 100
	orange := totalLen * 70 / 100
	switch {
	case index <= green:
		return 0
	case index <= orange:
		return 1
	default:
		return 2
	}
}

func genKingdomTileInfos(kingdomId int, sortedAllTiles []common.Location, mapResourceQty map[int64]int) []common.TileInfo {
	l := zap.S().With("func", "genKingdomTileInfos")
	arrTileResource := genTileResource(len(sortedAllTiles), mapResourceQty)
	if len(arrTileResource) != len(sortedAllTiles) {
		l.Panicw("invalid arrTileResource len", "len(sortedAllTiles)", len(sortedAllTiles), "len(arrTileResource)", len(arrTileResource))
	}
	// shuffle more fun
	rand.Shuffle(len(arrTileResource), func(i, j int) {
		arrTileResource[i], arrTileResource[j] = arrTileResource[j], arrTileResource[i]
	})
	l.Infow("len tiles", "len", len(sortedAllTiles), "len(arrTileResource)", len(arrTileResource))
	var result []common.TileInfo
	for index, tile := range sortedAllTiles {
		result = append(result, common.TileInfo{
			KingdomId:       0,
			X:               tile.X,
			Y:               tile.Y,
			ResourceItemIds: arrTileResource[index],
		})
	}
	// l.Infow("tiles info data", "data", result)
	l.Infow("len tiles info data", "len", len(result))
	return result
}

func genTileResource(zoneLen int, mapResourceQty map[int64]int) [][]int64 {
	l := zap.S().With("func", "genTileResource")
	l.Infow("mapResourceQty", "value", mapResourceQty)
	result := make([][]int64, zoneLen)
	// lenMapResourceQty := len(mapResourceQty)
	needReplace := false
	for i := 0; i < 10; i++ {
		mapResourceQtyReplace := make(map[int64]int)
		for rId, qty := range mapResourceQty {
			// if needReplace {
			// 	l.Infow("resource data", "rId", rId, "qty", qty)
			// }
			newQty := qty
			for i := range result {
				if needReplace {
					isDuplicate := false
					for _, rrID := range result[i] {
						if rrID == rId {
							isDuplicate = true
							break
						}
					}
					// if needReplace && !isDuplicate {
					// 	l.Infow("resource data 2", "result[i]", result[i])
					// }
					if !isDuplicate { // don't have resource
						replaceIndex := rand.Intn(len(result[i]))
						mapResourceQtyReplace[int64(result[i][replaceIndex])]++
						result[i][replaceIndex] = rId
						newQty--
						if newQty == 0 {
							break
						}
					}
				} else {
					if len(result[i]) >= rand.Intn(3)+1 {
						continue
					}
					isDuplicate := false
					for _, rrID := range result[i] {
						if rrID == rId {
							isDuplicate = true
							break
						}
					}
					if isDuplicate {
						continue
					}
					result[i] = append(result[i], rId)
					newQty--
					if newQty == 0 {
						break
					}
				}
			}
			mapResourceQty[rId] = newQty // update new qty
			rand.Shuffle(len(result), func(i, j int) {
				result[i], result[j] = result[j], result[i]
			})
		}
		for rId, qty := range mapResourceQty {
			if qty == 0 {
				delete(mapResourceQty, rId)
			}
		}
		for rId, qty := range mapResourceQtyReplace {
			mapResourceQty[rId] = qty
		}
		if len(mapResourceQty) == 0 { // fully distributed
			l.Infow("distribute resource done!!!!!!!!!!")
			break
		} else {
			if needReplace {
				needReplace = false
			} else {
				needReplace = true
			}
		}
		l.Infow("retry ...", "remain resource qty", mapResourceQty, "needReplace", needReplace)
	}

	// refill empty tile
	for index := range result {
		if len(result[index]) == 0 {
			for _, newResources := range result {
				if len(newResources) >= 2 {
					result[index] = append(result[index], newResources[rand.Intn(len(newResources))])
					break
				}
			}
		}
	}
	// validate data
	for _, resources := range result {
		if len(resources) == 0 {
			l.Panicw("empty resource in tile")
		}
		mapDup := make(map[int64]bool)
		for _, resourceId := range resources {
			if mapDup[resourceId] {
				l.Panicw("invalid resource data", "tile resource", resources)
			}
			mapDup[resourceId] = true
		}
	}
	return result
}
