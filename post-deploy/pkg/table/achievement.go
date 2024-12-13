package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

func AchievementCallData(achievement common.Achievement) ([]byte, error) {
	staticData, err := encodePacked(
		uint16(achievement.Stats.Atk),
		uint16(achievement.Stats.Def),
		uint16(achievement.Stats.Agi),
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(achievement.Id)))),
	}
	encodedLength := mud.EncodeLengths([]int{
		len(stringToBytes(achievement.Name)),
	})
	dynamicData := simpleEncodePacked(stringToBytes(achievement.Name))
	mt := mud.NewMudTable("Achievement", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
