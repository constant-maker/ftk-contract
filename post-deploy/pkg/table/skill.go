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
		uint8(skill.PerkItemType),
		skill.RequiredPerkLevel,
		skill.HasEffect,
	)
	if err != nil {
		return nil, err
	}
	encodedLength := mud.EncodeLengths([]int{len(stringToBytes(skill.Name))})
	dynamicData := simpleEncodePacked(stringToBytes(skill.Name))
	mt := mud.NewMudTable("Skill", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func SkillEffectCallData(skillID int, skillEffect common.SkillEffect) ([]byte, error) {
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(skillID)))),
	}
	staticData, err := encodePacked(
		uint8(skillEffect.EffectType),
		uint8(skillEffect.Damage),
		uint16(skillEffect.Turns),
	)
	if err != nil {
		return nil, err
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("SkillEffect", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
