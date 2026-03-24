pragma solidity >=0.8.24;

import { WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
import { MapConfig, MapConfigData, Tile, TileData } from "@codegen/index.sol";
import { TestHelper } from "./TestHelper.sol";
import { WorldFixture } from "./fixtures/WorldFixture.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

contract MapConfigTest is WorldFixture {
  function setUp() public override {
    WorldFixture.setUp();
  }

  function test_ShouldHaveData() external {
    TileData memory tileInfo = Tile.get(20, -32);
    assertEq(tileInfo.farmSlot, 3);
    assertEq(tileInfo.kingdomId, 0);
    assertEq(tileInfo.itemIds.length, 12);
  }
}
