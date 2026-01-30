package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

const (
	itemWeightCacheFieldLayout = "0x0004010004000000000000000000000000000000000000000000000000000000"
	skinInfoFieldLayout        = "0x0001010001000000000000000000000000000000000000000000000000000000"
)

func ItemCallData(item common.Item) ([]byte, error) {
	// zap.S().Infow("item category", "id", item.Id, "value", common.MapItemCategoryTypes[item.Category])
	staticData, err := encodePacked(
		uint8(item.Category),
		uint8(item.Type),
		uint32(item.Weight),
		uint8(item.Tier),
		item.Untradable,
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(item.Id)))),
	}
	encodedLength := mud.EncodeLengths([]int{len(stringToBytes(item.Name))})
	dynamicData := simpleEncodePacked(stringToBytes(item.Name))
	mt := mud.NewMudTable("ItemV2", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func EquipmentItemInfoCallData(equipmentInfo common.EquipmentInfo, itemId int) ([]byte, error) {
	staticData, err := encodePacked(
		uint8(equipmentInfo.SlotType),
		uint8(equipmentInfo.AdvantageType),
		equipmentInfo.TwoHanded,
		uint32(equipmentInfo.Hp),
		uint16(equipmentInfo.Atk),
		uint16(equipmentInfo.Def),
		uint16(equipmentInfo.Agi),
		uint16(equipmentInfo.Ms),
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(itemId)))),
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("EquipmentInfo", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func EquipmentItemInfo2V2CallData(equipmentInfo common.EquipmentInfo, itemId int) ([]byte, error) {
	staticData, err := encodePacked(
		uint8(0),  // max level
		uint8(0),  // counter
		uint16(0), // dmg percentage
		uint32(equipmentInfo.BonusWeight),
		uint32(equipmentInfo.ShieldBarrier),
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(itemId)))),
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("EquipmentInfo2V2", "app", "")
	// zap.S().Infow("equipment info v2", "itemId", itemId, "equipmentInfo", equipmentInfo)
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func HealingItemInfoCallData(healingInfo common.HealingInfo, itemId int) ([]byte, error) {
	staticData, err := encodePacked(
		uint32(healingInfo.HpRestore),
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(itemId)))),
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("HealingItemInfo", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func ResourceItemInfoCallData(resourceInfo common.ResourceInfo, itemId int) ([]byte, error) {
	staticData, err := encodePacked(
		uint8(resourceInfo.ResourceType),
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(itemId)))),
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("ResourceInfo", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func BuffItemInfoCallData(buffInfo common.BuffItemInfo, itemId int) ([]byte, error) {
	staticData, err := encodePacked(
		uint16(buffInfo.Range), uint32(buffInfo.Duration), uint8(buffInfo.NumTarget),
		buffInfo.SelfCastOnly, uint8(buffInfo.Type), buffInfo.IsBuff,
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(itemId)))),
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("BuffItemInfoV3", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func BuffDmgInfoCallData(skillInfo common.InstantDamage, itemId int) ([]byte, error) {
	staticData, err := encodePacked(
		uint32(skillInfo.Dmg), skillInfo.IsAbsDmg,
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(itemId)))),
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("BuffDmg", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func BuffStatCallData(statBuff common.StatsModify, itemId int) ([]byte, error) {
	staticData, err := encodePacked(
		statBuff.AtkPercent, statBuff.DefPercent, statBuff.AgiPercent,
		int8(statBuff.Sp), int8(statBuff.Ms), uint32(statBuff.Dmg), statBuff.IsAbsDmg,
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(itemId)))),
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("BuffStatV3", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func BuffExpCallData(statBuff common.ExpAmplify, itemId int) ([]byte, error) {
	staticData, err := encodePacked(
		uint16(statBuff.FarmingPerkAmp), uint16(statBuff.PveExpAmp), uint16(statBuff.PveExpAmp),
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(itemId)))),
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("BuffExp", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func ItemWeightCacheCallData(item common.Item) ([]byte, error) {
	staticData, err := encodePacked(
		uint32(item.OldWeight),
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(item.Id)))),
	}
	mt := mud.NewMudTable("ItemWeightCache", "app", itemWeightCacheFieldLayout)
	return mt.SetStaticFieldRawCalldata(keyTuple, 0, staticData)
}

func SkinInfoCallData(item common.Item) ([]byte, error) {
	staticData, err := encodePacked(
		uint8(item.SkinInfo.SlotType),
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(item.Id)))),
	}
	mt := mud.NewMudTable("SkinInfo", "app", skinInfoFieldLayout)
	return mt.SetStaticFieldRawCalldata(keyTuple, 0, staticData)
}
