package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

func SkillCallData(skill common.Skill) ([]byte, error) {
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(skill.Id)))),
	}
	staticData, err := encodePacked(
		uint8(skill.Sp),
		uint8(skill.Tier),
		uint16(skill.Damage),
	)
	if err != nil {
		return nil, err
	}
	encodedLength := mud.EncodeLengths([]int{len(stringToBytes(skill.Name))})
	dynamicData := simpleEncodePacked(stringToBytes(skill.Name))
	mt := mud.NewMudTable("Skill", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
