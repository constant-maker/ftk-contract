package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

func QuestCallData(quest common.Quest2) ([]byte, error) {
	// zap.S().Infow("quest.TitleId", "value", quest.AchievementId)
	staticData, err := encodePacked(quest.Exp, quest.Gold, uint8(quest.QuestType),
		big.NewInt(quest.FromNpcId), big.NewInt(quest.ToNpcId), big.NewInt(quest.AchievementId))
	if err != nil {
		return nil, err
	}
	encodedLength := mud.EncodeLengths([]int{
		32 * len(quest.RequiredDoneQuestIds),
	})
	var requiredDoneQuestIds []*big.Int
	for _, id := range quest.RequiredDoneQuestIds {
		requiredDoneQuestIds = append(requiredDoneQuestIds, big.NewInt(id))
	}
	dynamicData := encodeUint256Array(requiredDoneQuestIds)
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(quest.Id))),
	}
	mt := mud.NewMudTable("Quest2", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func QuestLocateCallData(questId int64, locations []common.Location) ([]byte, error) {
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(questId)))),
	}
	staticData := []byte{}
	lengths := []int{len(locations) * 4, len(locations) * 4}
	encodedLength := mud.EncodeLengths(lengths)
	var (
		xs []int32
		ys []int32
	)
	for i := range locations {
		xs = append(xs, locations[i].X)
		ys = append(ys, locations[i].Y)
	}
	xsPacked, err := encodePacked(xs)
	if err != nil {
		return nil, err
	}
	ysPacked, err := encodePacked(ys)
	if err != nil {
		return nil, err
	}
	dynamicData := simpleEncodePacked(xsPacked, ysPacked)
	mt := mud.NewMudTable("QuestLocate", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func QuestContributeCallData(questId int64, details []common.ContributeDetail) ([]byte, error) {
	staticData := []byte{}
	encodedLength := mud.EncodeLengths([]int{len(details) * 32, len(details) * 4})
	var (
		itemIds []*big.Int
		amounts []uint32
	)
	for _, i := range details {
		itemIds = append(itemIds, big.NewInt(i.ItemId))
		amounts = append(amounts, i.Amount)
	}

	itemIdsEncodePacked := encodeUint256Array(itemIds)
	amountsEncodePacked, err := encodePacked(amounts)
	if err != nil {
		return nil, err
	}
	dynamicData := simpleEncodePacked(itemIdsEncodePacked, amountsEncodePacked)
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(questId))),
	}
	mt := mud.NewMudTable("QuestContribute", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
