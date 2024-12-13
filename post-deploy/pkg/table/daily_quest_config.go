package table

import (
	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

func DailyQuestConfigCallData(dqc common.DailyQuestConfig) ([]byte, error) {
	keyTuple := make([][32]byte, 0)
	staticData, err := encodePacked(dqc.MoveNum, dqc.FarmNum, dqc.PvpNum, dqc.PveNum, dqc.RewardExp, dqc.RewardGold)
	if err != nil {
		return nil, err
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("DailyQuestConfig", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
