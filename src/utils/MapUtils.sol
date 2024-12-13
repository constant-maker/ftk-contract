pragma solidity >=0.8.24;

import { Unmovable } from "@codegen/index.sol";

library MapUtils {
  function getTileId(int32 x, int32 y) internal pure returns (bytes32) {
    return keccak256(abi.encode(x, y));
  }

  function isTileMovable(int32 x, int32 y) internal view returns (bool) {
    bytes32 tileId = getTileId(x, y);
    return !Unmovable.get(x, y);
  }
}
