pragma solidity >=0.8.24;

import { console } from "forge-std/console.sol";
import { StoreHook } from "@latticexyz/store/src/StoreHook.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EncodedLengths } from "@latticexyz/store/src/EncodedLengths.sol";
import { FieldLayout } from "@latticexyz/store/src/FieldLayout.sol";
import { MonsterLocationUtils } from "@utils/MonsterLocationUtils.sol";
import { Errors } from "@common/Errors.sol";

contract MonsterLocationHook is StoreHook {
  function onAfterSetRecord(
    ResourceId tableId,
    bytes32[] memory keyTuple,
    bytes memory staticData,
    EncodedLengths encodedLengths,
    bytes memory dynamicData,
    FieldLayout fieldLayout
  )
    public
    override
  {
    int32 x = int32(int256(uint256(keyTuple[0])));
    int32 y = int32(int256(uint256(keyTuple[1])));
    uint256 monsterId = uint256(keyTuple[2]);
    MonsterLocationUtils.addMonster(x, y, monsterId);
  }

  function onAfterDeleteRecord(ResourceId tableId, bytes32[] memory keyTuple, FieldLayout fieldLayout) public override {
    int32 x = int32(int256(uint256(keyTuple[0])));
    int32 y = int32(int256(uint256(keyTuple[1])));
    uint256 monsterId = uint256(keyTuple[2]);
    MonsterLocationUtils.removeMonster(x, y, monsterId);
  }
}
