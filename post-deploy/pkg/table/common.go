package table

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"math/big"
	"reflect"

	"github.com/ethereum/go-ethereum/common/math"
)

func simpleEncodePacked(input ...[]byte) []byte {
	return bytes.Join(input, nil)
}

func stringToBytes(s string) []byte {
	return []byte(s)
}

// encodeUint256 return []byte (len = 32)
func encodeUint256(num *big.Int) []byte {
	return math.U256Bytes(num)
}

func encodeUint256Array(arr []*big.Int) []byte {
	var res [][]byte
	for _, v := range arr {
		b := encodeUint256(v)
		res = append(res, b)
	}
	return bytes.Join(res, nil)
}

// encodePacked emulates Solidity's abi.encodePacked
func encodePacked(values ...interface{}) ([]byte, error) {
	var buffer bytes.Buffer
	for _, value := range values {
		switch v := value.(type) {
		case uint8, uint16, uint32, uint64, int8, int16, int32, int64:
			err := binary.Write(&buffer, binary.BigEndian, v)
			if err != nil {
				return nil, err
			}
		case string:
			buffer.WriteString(v)
		case bool:
			// Convert bool to byte, 0x00 for false and 0x01 for true
			var b byte
			if v {
				b = 0x01
			}
			buffer.WriteByte(b)
		case *big.Int:
			buffer.Write(encodeUint256(v))
		case []byte:
			buffer.Write(v)
		default:
			value := reflect.ValueOf(v)
			if value.Kind() == reflect.Array || value.Kind() == reflect.Slice {
				var res [][]byte
				for i := 0; i < value.Len(); i++ {
					elem := value.Index(i)
					byteData, err := encodePacked(elem.Interface())
					if err != nil {
						return nil, err
					}
					res = append(res, byteData)
				}
				buffer.Write(bytes.Join(res, nil))
			} else {
				return nil, fmt.Errorf("unsupported type: %T", v)
			}
		}
	}
	return buffer.Bytes(), nil
}
