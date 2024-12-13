pragma solidity >=0.8.24;

import { WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
import { MapConfig, MapConfigData, TileInfo3, TileInfo3Data } from "@codegen/index.sol";
import { TestHelper } from "./TestHelper.sol";
import { WorldFixture } from "./fixtures/WorldFixture.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

contract MapConfigTest is WorldFixture {
  function setUp() public override {
    WorldFixture.setUp();
  }

  function test_MapConfigSize_ShouldBeSet() external {
    console.logBytes32(ResourceId.unwrap(MapConfig._tableId));
    MapConfigData memory mapConfigData = MapConfig.get();
    assertEq(mapConfigData.width, type(uint32).max);
    assertEq(mapConfigData.height, type(uint32).max);
  }

  function testFuzz_UserShouldNotAbleToConfigMap(address user) external {
    vm.assume(user != worldDeployer);
    vm.assume(user != creator);
    vm.assume(user != address(0));

    vm.startPrank(user);

    bytes memory accessDeniedError = TestHelper.getAccessDeniedError(user, MapConfig._tableId);
    vm.expectRevert(accessDeniedError);
    MapConfig.set(uint32(10), uint32(10));

    vm.stopPrank();
  }

  function test_ShouldHaveData() external {
    TileInfo3Data memory tileInfo = TileInfo3.get(20, -32);
    assertEq(tileInfo.farmSlot, 3);
    assertEq(tileInfo.kingdomId, 0);
    assertEq(tileInfo.itemIds.length, 12);
  }
}
