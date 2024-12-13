package mud

import (
	"fmt"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/stretchr/testify/require"
)

func TestGetTableId(t *testing.T) {
	tableId := getTableId("", "MapConfig")
	fmt.Println(common.Bytes2Hex(tableId[:]))
	require.Equal(t, "0x746200000000000000000000000000004d6170436f6e66696700000000000000", hexutil.Encode(tableId[:]))
}
