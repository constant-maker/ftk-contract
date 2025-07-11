package common

import (
	"math"
	"sort"
)

type LocationExt struct {
	Tile     Location
	Distance float64
}

func SortTileByDistanceToCapital(allTiles []Location, capital Location) []Location {
	result := make([]Location, 0, len(allTiles))
	lExts := make([]LocationExt, 0, len(allTiles))
	for _, tile := range allTiles {
		lExts = append(lExts, LocationExt{
			Tile: tile,
			Distance: calculateDistance(tile, Location{
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

func calculateDistance(tile, capital Location) float64 {
	return math.Sqrt(math.Pow(float64(tile.X-capital.X), 2) + math.Pow(float64(tile.Y-capital.Y), 2))
}
