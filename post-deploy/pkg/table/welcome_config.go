package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

func WelcomeConfigCallData(welcomeConfig common.WelcomeConfig) ([]byte, error) {
	keyTuple := make([][32]byte, 0)
	var itemIds []*big.Int
	for _, itemId := range welcomeConfig.ItemIds {
		itemIds = append(itemIds, big.NewInt(int64(itemId)))
	}
	dynamicData := encodeUint256Array(itemIds)
	mt := mud.NewMudTable("WelcomeConfig", "app", "")
	return mt.SetDynamicFieldRawCalldata(keyTuple, 0, dynamicData)
}
