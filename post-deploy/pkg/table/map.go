package table

import (
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

func MapConfigCallData() ([]byte, error) {
	keyTuple := make([][32]byte, 0)
	var (
		width  uint32 = 4294967295
		height uint32 = 4294967295
	)
	staticData, err := encodePacked(width, height)
	if err != nil {
		return nil, err
	}
	encodedLength := mud.PackedCounter{}
	dynamicData := []byte{}
	mt := mud.NewMudTable("MapConfig", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func KingdomCallData(kd common.Kingdom) ([]byte, error) {
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(kd.Id)))),
	}
	staticData := encodeUint256(big.NewInt(int64(kd.CapitalId)))
	encodedLength := mud.EncodeLengths([]int{len(stringToBytes(kd.Name))})
	dynamicData := simpleEncodePacked(stringToBytes(kd.Name))
	mt := mud.NewMudTable("Kingdom", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}

func CityCallData(city common.City) ([]byte, error) {
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(city.Id)))),
	}
	staticData, err := encodePacked(city.X, city.Y, city.IsCapital, city.KingdomId, city.Level)
	if err != nil {
		return nil, err
	}
	encodedLength := mud.EncodeLengths([]int{
		len(stringToBytes(city.Name)),
	})
	dynamicData := simpleEncodePacked(stringToBytes(city.Name))
	mt := mud.NewMudTable("City", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
