package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
	"go.uber.org/zap"
)

func TileInfoCallData(ti common.TileInfo, dataConfig common.DataConfig) ([]byte, error) {
	l := zap.S()
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(ti.X)))),
		[32]byte(encodeUint256(big.NewInt(int64(ti.Y)))),
	}
	farmSlot := uint8(3)
	for _, boss := range dataConfig.MonsterLocationsBoss {
		for _, location := range boss.Locations {
			if ti.X == location.X && ti.Y == location.Y {
				l.Infow("boss location", "value", location)
				farmSlot = 0
				break
			}
		}
	}
	staticData, err := encodePacked(
		ti.KingdomId,
		farmSlot,
		ti.ZoneType,
		big.NewInt(0),
		big.NewInt(0),
	)
	if err != nil {
		return nil, err
	}
	encodedLength := mud.EncodeLengths([]int{len(ti.ResourceItemIds) * 32, 0, 0})
	resourceIds := make([]*big.Int, 0)
	for _, rId := range ti.ResourceItemIds {
		resourceIds = append(resourceIds, big.NewInt(rId))
	}
	resourceIdsData := encodeUint256Array(resourceIds)
	dynamicData := simpleEncodePacked(resourceIdsData, encodeUint256Array(nil), encodeUint256Array(nil))
	mt := mud.NewMudTable("TileInfo3", "app")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
