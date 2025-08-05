pragma solidity >=0.8.24;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
import { KingdomV2, KingdomV2Data } from "../src/codegen/index.sol";
import { TestHelper } from "./TestHelper.sol";
import { WorldFixture } from "./fixtures/WorldFixture.sol";

contract KingdomTest is WorldFixture {
  function setUp() public override {
    WorldFixture.setUp();
  }

  function test_Kingdom_ShouldBeInitialize() external {
    KingdomV2Data memory kingdomData = KingdomV2.get(1);
    assertTrue(kingdomData.capitalId != 0);
  }

  function testFuzz_UserShouldNotAbleToConfigKingdom(address user) external {
    vm.assume(user != worldDeployer);
    vm.assume(user != creator);
    vm.assume(user != address(0));

    vm.startPrank(user);

    bytes memory accessDeniedError = TestHelper.getAccessDeniedError(user, KingdomV2._tableId);
    vm.expectRevert(accessDeniedError);
    KingdomV2.set(1, 1, 1, 1, "The Great KingdomV2");

    vm.stopPrank();
  }
}
