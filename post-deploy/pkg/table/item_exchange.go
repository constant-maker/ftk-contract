package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

func CollectionExcCallData(itemEx common.ItemExchange) ([]byte, error) {
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(itemEx.ItemId)))),
	}
	inputItemIds := make([]*big.Int, 0)
	inputItemAmounts := make([]uint32, 0)
	for _, ingredient := range itemEx.Ingredients {
		inputItemIds = append(inputItemIds, big.NewInt(int64(ingredient.ItemId)))
		inputItemAmounts = append(inputItemAmounts, uint32(ingredient.Amount))
	}
	encodedLength := mud.EncodeLengths([]int{
		len(itemEx.Ingredients) * 32, len(itemEx.Ingredients) * 4})
	dynamicData, err := encodePacked(inputItemIds, inputItemAmounts)
	if err != nil {
		return nil, err
	}

	mt := mud.NewMudTable("CollectionExcV2", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, []byte{}, encodedLength, dynamicData)
}
