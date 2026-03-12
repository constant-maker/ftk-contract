package table

import (
	"errors"
	"math/big"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/ftk/post-deploy/pkg/mud"
)

func PetComponentInfoCallData(petId int, petCpn common.PetCpn) ([]byte, error) {
	// zap.S().Infow("quest.TitleId", "value", quest.AchievementId)
	staticData := []byte{}
	if len(petCpn.CpnValues) != len(petCpn.CpnRatios) {
		return nil, errors.New("invalid pet component: CpnValues and CpnTypes must have the same length")
	}
	totalRatio := uint16(0)
	for i := range petCpn.CpnRatios {
		totalRatio += petCpn.CpnRatios[i]
	}
	if totalRatio != 10_000 {
		return nil, errors.New("invalid pet component: total ratio must be 10000")
	}
	encodedLength := mud.EncodeLengths([]int{
		2 * len(petCpn.CpnValues),
	})
	dynamicData, err := encodePacked(petCpn.CpnRatios)
	if err != nil {
		return nil, err
	}
	keyTuple := [][32]byte{
		[32]byte(encodeUint256(big.NewInt(int64(petId)))),
		[32]byte(encodeUint256(big.NewInt(int64(petCpn.CpnType)))),
	}
	mt := mud.NewMudTable("PetCpnInfo", "app", "")
	return mt.SetRecordRawCalldata(keyTuple, staticData, encodedLength, dynamicData)
}
