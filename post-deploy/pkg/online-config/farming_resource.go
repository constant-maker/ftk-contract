package onlineconfig

import (
	"io"
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

const (
	listResourceUpdate = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=1713114657#gid=1713114657"
)

// getListFarmingResourceUpdate farming resource
func getListFarmingResourceUpdate() ([]common.Item, error) {
	l := zap.S().With("func", "getListFarmingResourceUpdate")
	reader, err := getRawCsvReader(listResourceUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	result := make([]common.Item, 0)
	var (
		idIndex, tierIndex, weightIndex, nameIndex, typeIndex, descIndex int
	)
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		} else if err != nil {
			l.Errorw("cannot read data", "err", err)
			return nil, err
		}
		if record[0] == "" { // empty row
			l.Infow("invalid data, skip ...", "data", record)
			continue
		}
		if strings.EqualFold(record[0], "id") { // header
			if tierIndex != 0 && nameIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			idIndex = findIndex(record, "id")
			tierIndex = findIndex(record, "tier")
			weightIndex = findIndex(record, "weight")
			nameIndex = findIndex(record, "name")
			typeIndex = findIndex(record, "type")
			descIndex = findIndex(record, "desc")
			continue
		}
		// if len(record) != 6 {
		// 	l.Warnw("invalid resource data format", "len(record)", len(record))
		// 	return nil, fmt.Errorf("invalid data format len record = %d", len(record))
		// }
		id := mustStringToInt(record[idIndex], idIndex)
		tier := mustStringToInt(record[tierIndex], tierIndex)
		weight := mustStringToInt(record[weightIndex], weightIndex)
		result = append(result, common.Item{
			Id:       int(id),
			Type:     23,
			Category: 2,
			Tier:     int(tier),
			Weight:   int(weight),
			Name:     removeRedundantText(record[nameIndex]),
			Desc:     removeRedundantText(record[descIndex]),
			ResourceInfo: &common.ResourceInfo{
				ResourceType: getResourceType(record[typeIndex]),
			},
		})
	}
	return result, nil
}
