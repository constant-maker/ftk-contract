package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
	"go.uber.org/zap"
)

func ItemRecipeCallData(recipe common.ItemRecipe) ([]byte, error) {
	staticData, err := encodePacked(uint32(recipe.GoldCost))
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(recipe.ItemId)))),
	}
	encodedLength := mud.EncodeLengths([]int{
		len(recipe.PerkItemTypes), len(recipe.RequiredPerkLevels),
		len(recipe.Ingredients) * 32, len(recipe.Ingredients) * 4})
	var (
		itemIds            []*big.Int
		amounts            []uint32
		perkTypes          []uint8
		requiredPerkLevels []uint8
	)
	for _, i := range recipe.Ingredients {
		itemIds = append(itemIds, big.NewInt(int64(i.ItemId)))
		amounts = append(amounts, uint32(i.Amount))
	}
	if len(recipe.PerkItemTypes) != len(recipe.RequiredPerkLevels) {
		zap.S().Panicw("invalidate recipe data", "data", recipe)
	}
	for index := range recipe.PerkItemTypes {
		perkTypes = append(perkTypes, uint8(recipe.PerkItemTypes[index]))
		requiredPerkLevels = append(requiredPerkLevels, uint8(recipe.RequiredPerkLevels[index]))
	}

	dynamicData, err := encodePacked(perkTypes, requiredPerkLevels, itemIds, amounts)
	if err != nil {
		return nil, err
	}

	mt := mud.NewMudTable("ItemRecipeV2", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
