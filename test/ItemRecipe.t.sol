pragma solidity >=0.8.24;

import { console } from "forge-std/console.sol";
import { WorldFixture } from "./fixtures/WorldFixture.sol";
import { ItemRecipeV2, ItemRecipeV2Data } from "@codegen/index.sol";

contract ItemRecipeTest is WorldFixture {
  function setUp() public override {
    WorldFixture.setUp();
  }

  function test_Recipe_ShouldHaveRightInfo() external {
    uint256 itemId = 18; // wood axe
    ItemRecipeV2Data memory data = ItemRecipeV2.get(itemId);
    assertEq(data.goldCost, uint32(5));
    assertEq(data.itemIds.length, uint256(2));
    assertEq(data.amounts.length, uint256(2));
    assertEq(data.itemIds[0], uint256(1));
    assertEq(data.amounts[0], uint32(10));
    assertEq(data.itemIds[1], uint256(10));
    assertEq(data.amounts[1], uint32(10));

    itemId = 183; // Adept Wood Axe tier 6
    data = ItemRecipeV2.get(itemId);
    assertEq(data.goldCost, uint32(14));
    assertEq(data.itemIds.length, uint256(3));
    assertEq(data.amounts.length, uint256(3));
    assertEq(data.itemIds[0], uint256(1));
    assertEq(data.amounts[0], uint32(30));
    assertEq(data.itemIds[1], uint256(10));
    assertEq(data.amounts[1], uint32(30));
    assertEq(data.perkTypes[0], uint8(1));
    assertEq(data.requiredPerkLevels[0], uint8(5));
    assertEq(data.perkTypes[1], uint8(2));
    assertEq(data.requiredPerkLevels[1], uint8(6));
  }
}
