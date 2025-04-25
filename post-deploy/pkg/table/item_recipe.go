package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

func ItemRecipeCallData(recipe common.ItemRecipe) ([]byte, error) {
	staticData, err := encodePacked(uint32(recipe.GoldCost))
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(recipe.ItemId)))),
	}
	encodedLength := mud.EncodeLengths([]int{len(recipe.Ingredients) * 32, len(recipe.Ingredients) * 4})
	var (
		itemIds []*big.Int
		amounts []uint32
	)
	for _, i := range recipe.Ingredients {
		itemIds = append(itemIds, big.NewInt(int64(i.ItemId)))
		amounts = append(amounts, uint32(i.Amount))
	}

	dynamicData, err := encodePacked(itemIds, amounts)
	if err != nil {
		return nil, err
	}

	mt := mud.NewMudTable("ItemRecipe", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
