package common

import "go.uber.org/zap"

// GetAllTilesByLocation returns all tile by given location
// locations must be in order top-left, top-right, bottom-right, bottom-left
func GetAllTilesByLocation(locations [4]Location) []Location {
	var allTiles []Location
	if locations[0].X < locations[1].X {
		for i := locations[0].X; i <= locations[1].X; i++ {
			if locations[3].Y < locations[0].Y {
				for j := locations[3].Y; j <= locations[0].Y; j++ {
					allTiles = append(allTiles, Location{
						X: i,
						Y: j,
					})
				}
			} else {
				zap.S().Panicw("wrong order of zone location config, locations[3].Y > locations[0].Y", "locations", locations)
				// for j := rangeValueY[1]; j <= rangeValueY[0]; j++ {
				// 	allTiles = append(allTiles, Location{
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
		// 			allTiles = append(allTiles, Location{
		// 				X: i,
		// 				Y: j,
		// 			})
		// 		}
		// 	} else {
		// 		for j := rangeValueY[1]; j <= rangeValueY[0]; j++ {
		// 			allTiles = append(allTiles, Location{
		// 				X: i,
		// 				Y: j,
		// 			})
		// 		}
		// 	}
		// }
	}
	return allTiles
}

func RemoveTile(allTiles []Location, rTile Location) []Location {
	newArr := make([]Location, 0)
	for _, tile := range allTiles {
		if tile.X == rTile.X && tile.Y == rTile.Y {
			continue
		}
		newArr = append(newArr, tile)
	}
	return newArr
}

func RemoveDupTile(allTiles []Location) []Location {
	newArr := make([]Location, 0)
	mapTile := make(map[Location]bool)
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
