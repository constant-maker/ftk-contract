package gentile

import (
	"sort"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

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
