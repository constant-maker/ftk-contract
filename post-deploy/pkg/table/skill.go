package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
	"go.uber.org/zap"
)

func SkillCallData(skill common.Skill) ([]byte, error) {
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(skill.Id)))),
	}
	staticData, err := encodePacked(
		uint8(skill.Sp),
		uint16(skill.Damage),
		skill.HasEffect,
	)
	if err != nil {
		return nil, err
	}
	encodedLength := mud.EncodeLengths([]int{
		len(stringToBytes(skill.Name)),
		len(skill.PerkItemTypes),
		len(skill.RequiredPerkLevels)})
	if len(skill.PerkItemTypes) != len(skill.RequiredPerkLevels) {
		panic("invalid perk and perk level len in skill")
	}
	scPerkItemTypes := make([]uint8, 0, len(skill.PerkItemTypes))
	for _, pit := range skill.PerkItemTypes {
		scPerkItemTypes = append(scPerkItemTypes, uint8(pit))
	}
	scRequiredPerkLevels := make([]uint8, 0, len(skill.RequiredPerkLevels))
	for _, rpl := range skill.RequiredPerkLevels {
		rpl -= 1
		if rpl < 0 {
			zap.S().Panicw("invalid required perk level", "data", skill)
		}
		scRequiredPerkLevels = append(scRequiredPerkLevels, uint8(rpl))
	}
	rawDynamicData, err := encodePacked(scPerkItemTypes, scRequiredPerkLevels)
	if err != nil {
		return nil, err
	}
	dynamicData := simpleEncodePacked(stringToBytes(skill.Name), rawDynamicData)
	mt := mud.NewMudTable("SkillV2", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func SkillEffectCallData(skillID int, skillEffect common.SkillEffect) ([]byte, error) {
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(skillID)))),
	}
	staticData, err := encodePacked(
		uint8(skillEffect.EffectType),
		uint16(skillEffect.Damage),
		uint8(skillEffect.Turns),
	)
	if err != nil {
		return nil, err
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("SkillEffect", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
