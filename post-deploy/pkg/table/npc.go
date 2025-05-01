package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

func NpcCallData(npc common.Npc) ([]byte, error) {
	staticData, err := encodePacked(big.NewInt(npc.CityId), npc.X, npc.Y)
	if err != nil {
		return nil, err
	}
	encodedLength := mud.EncodeLengths([]int{
		len(stringToBytes(npc.Name)),
	})
	dynamicData := simpleEncodePacked(stringToBytes(npc.Name))
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(npc.Id))),
	}
	mt := mud.NewMudTable("Npc", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func NpcShopCallData(city common.City) ([]byte, error) {
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(city.Id)))),
	}
	staticData, err := encodePacked(uint32(100_000))
	if err != nil {
		return nil, err
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("NpcShop", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func NpcCardCallData(npc common.Npc) ([]byte, error) {
	var staticData []byte
	encodedLength := mud.EncodeLengths([]int{
		len(npc.Cards) * 32, len(npc.Cards),
	})
	cardIds := make([]*big.Int, 0, len(npc.Cards))
	cardAmounts := make([]uint8, 0, len(npc.Cards))
	for _, card := range npc.Cards {
		cardIds = append(cardIds, big.NewInt(card.Id))
		cardAmounts = append(cardAmounts, uint8(card.Amount))
	}
	cardIdsData := encodeUint256Array(cardIds)
	cardAmountsData, err := encodePacked(cardAmounts)
	if err != nil {
		return nil, err
	}
	dynamicData := simpleEncodePacked(cardIdsData, cardAmountsData)
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(npc.CityId))),
	}
	mt := mud.NewMudTable("NpcShop2", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
