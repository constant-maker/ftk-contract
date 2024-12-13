package mud

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/math"
)

type ResourceId [32]byte
type FieldLayout [32]byte
type PackedCounter [32]byte

const RESOURCE_TABLE = "tb"

func getTableId(tableName, nameSpace string) ResourceId {
	data := []byte(RESOURCE_TABLE)
	data = append(data, make([]byte, 2-len(RESOURCE_TABLE))...) // Padding to ensure "tb" is bytes2
	data = append(data, []byte(nameSpace)...)                   // Adding nameSpace directly
	data = append(data, make([]byte, 14-len(nameSpace))...)     // Padding to ensure nameSpace fits into bytes14
	data = append(data, []byte(tableName)...)
	data = append(data, make([]byte, 32-len(data))...) // Ensure total length is 32 bytes

	var rawTableId common.Hash = common.BytesToHash(data)
	var tableId [32]byte
	copy(tableId[:], rawTableId[:])
	return tableId
}

const (
	BYTE_TO_BITS = 8
	ACC_BITS     = 7 * BYTE_TO_BITS
	VAL_BITS     = 5 * BYTE_TO_BITS
)

func EncodeLengths(lengths []int) PackedCounter {
	var packedCounterInt int
	for _, l := range lengths {
		packedCounterInt += l
	}

	packedCounter := big.NewInt(int64(packedCounterInt))

	for index, value := range lengths {
		shiftAmount := uint(ACC_BITS + VAL_BITS*index)
		shiftedValue := new(big.Int).Lsh(big.NewInt(int64(value)), shiftAmount)
		packedCounter.Or(packedCounter, shiftedValue)
	}

	return PackedCounter(math.U256Bytes(packedCounter))
}
