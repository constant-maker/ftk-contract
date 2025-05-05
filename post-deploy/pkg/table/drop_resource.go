package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
	"go.uber.org/zap"
)

func DropResourceCallData(config common.DataConfig, minTier int) ([]byte, error) {
	resourceIds := make([]*big.Int, 0)
	for _, item := range config.Items {
		if item.ResourceInfo == nil {
			// exclude non-resource items
			continue
		}
		if item.ResourceInfo.ResourceType == 6 {
			// exclude hunting-resource items
			continue
		}
		zap.S().Infow("drop item", "item", item.Name)
		if item.Tier >= minTier {
			resourceIds = append(resourceIds, big.NewInt(int64(item.Id)))
		}
	}
	dynamicData := encodeUint256Array(resourceIds)
	keyTuple := [][32]byte{}
	mt := mud.NewMudTable("DropResource", "app", "")
	return mt.SetDynamicFieldRawCalldata(keyTuple, 0, dynamicData)
}
