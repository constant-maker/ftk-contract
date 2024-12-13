package mud

import (
	"log"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"go.uber.org/zap"
)

var contractABI = `
[
	{
    "type": "function",
    "name": "setRecord",
    "inputs": [
      {
        "name": "tableId",
        "type": "bytes32",
        "internalType": "ResourceId"
      },
      {
        "name": "keyTuple",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "staticData",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "encodedLengths",
        "type": "bytes32",
        "internalType": "PackedCounter"
      },
      {
        "name": "dynamicData",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setDynamicField",
    "inputs": [
      {
        "name": "tableId",
        "type": "bytes32",
        "internalType": "ResourceId"
      },
      {
        "name": "keyTuple",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "dynamicFieldIndex",
        "type": "uint8",
        "internalType": "uint8"
      },
      {
        "name": "data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  }
]
`

// MudTable represents the equivalent Go struct for MudTable in Rust
type MudTable struct {
	TableName string
	Namespace string
	// FieldLayout FieldLayout
	TableID ResourceId
	abi     abi.ABI
}

// New creates a new MudTable instance
func NewMudTable(tableName, namespace string) MudTable {
	abi, err := abi.JSON(strings.NewReader(contractABI))
	if err != nil {
		log.Fatalf("failed to parse ABI: %v", err)
	}
	return MudTable{
		TableName: tableName,
		Namespace: namespace,
		// FieldLayout: fieldLayout,
		TableID: getTableId(tableName, namespace),
		abi:     abi,
	}
}

// SetRecordRawCalldata returns raw calldata of setRecord
func (mt *MudTable) SetRecordRawCalldata(
	keyTuple [][32]byte,
	staticData []byte,
	encodedLength PackedCounter,
	dynamicData []byte,
) ([]byte, error) {
	callData, err := mt.abi.Pack("setRecord", mt.TableID, keyTuple, staticData, encodedLength, dynamicData)
	if err != nil {
		zap.S().Errorw("cannot pack data setRecord", "err", err)
		return nil, err
	}
	return callData, nil
}

// SetDynamicFieldRawCalldata returns raw calldata of setDynamicField
func (mt *MudTable) SetDynamicFieldRawCalldata(
	keyTuple [][32]byte,
	dynamicFieldIndex uint8,
	dynamicData []byte,
) ([]byte, error) {
	callData, err := mt.abi.Pack("setDynamicField", mt.TableID, keyTuple, dynamicFieldIndex, dynamicData)
	if err != nil {
		zap.S().Errorw("cannot pack data setDynamicField", "err", err)
		return nil, err
	}
	return callData, nil
}
