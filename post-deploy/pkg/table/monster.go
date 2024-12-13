package table

import (
	"fmt"
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

func MonsterCallData(monster common.Monster) ([]byte, error) {
	if len(monster.ItemIds) != len(monster.ItemAmounts) {
		return nil, fmt.Errorf("invalid monster data len itemIds = %d len itemAmounts = %d",
			len(monster.ItemIds), len(monster.ItemAmounts))
	}
	staticData, err := encodePacked(uint8(monster.Grow), uint32(monster.Exp), uint32(monster.PerkExp), monster.IsBoss)
	if err != nil {
		return nil, err
	}
	encodedLength := mud.EncodeLengths([]int{
		len(stringToBytes(monster.Name)),
		32 * len(monster.SkillIds),
		32 * len(monster.ItemIds),
		4 * len(monster.ItemAmounts),
	})
	skillIds := make([]*big.Int, len(monster.SkillIds))
	for index, skillId := range monster.SkillIds {
		skillIds[index] = big.NewInt(int64(skillId))
	}
	itemIds := make([]*big.Int, len(monster.ItemIds))
	for index, itemId := range monster.ItemIds {
		itemIds[index] = big.NewInt(int64(itemId))
	}
	itemAmounts := make([]uint32, len(monster.ItemAmounts))
	for index, itemAmount := range monster.ItemAmounts {
		itemAmounts[index] = uint32(itemAmount)
	}
	// encodedResourceAmounts, _ := encodePacked(itemAmounts)
	dynamicData, err := encodePacked(
		stringToBytes(monster.Name),
		skillIds,
		itemIds,
		itemAmounts,
	)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(monster.Id)))),
	}
	mt := mud.NewMudTable("Monster", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func MonsterStatsCallData(monsterId int, stats common.MonsterStats) ([]byte, error) {
	staticData, err := encodePacked(
		uint32(stats.Hp), uint16(stats.Atk), uint16(stats.Def), uint16(stats.Agi), uint8(stats.Sp))
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(monsterId)))),
	}
	if err != nil {
		return nil, err
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("MonsterStats", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func BossInfosCallData(monsterId int, bossInfo common.BossInfo, x int32, y int32) ([]byte, error) {
	staticData, err := encodePacked(
		uint32(bossInfo.Barrier),
		uint32(bossInfo.Hp),
		uint32(bossInfo.Crystal),
		uint16(bossInfo.RespawnDuration),
		uint8(bossInfo.BerserkHpThreshold),
		uint8(bossInfo.BoostPercent),
		big.NewInt(int64(bossInfo.LastDefeatedTime)),
	)
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(monsterId)))),
		[32]byte(encodeUint256(big.NewInt(int64(x)))),
		[32]byte(encodeUint256(big.NewInt(int64(y)))),
	}
	if err != nil {
		return nil, err
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("BossInfo", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func MonsterLocationCallData(location common.Location, monsterId, level, advantageType int) ([]byte, error) {
	staticData, err := encodePacked(uint16(level), uint8(advantageType))
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(location.X)))),
		[32]byte(encodeUint256(big.NewInt(int64(location.Y)))),
		[32]byte(encodeUint256(big.NewInt(int64(monsterId)))),
	}
	if err != nil {
		return nil, err
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("MonsterLocation", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
