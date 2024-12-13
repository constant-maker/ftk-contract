pragma solidity >=0.8.24;

import { console } from "forge-std/console.sol";
import { WorldFixture } from "./fixtures/WorldFixture.sol";
import { ItemRecipe, ItemRecipeData } from "@codegen/index.sol";

contract ItemRecipeTest is WorldFixture {
  function setUp() public override {
    WorldFixture.setUp();
  }

  function test_Recipe_ShouldHaveRightInfo() external {
    uint256 itemId = 18; // wood axe
    ItemRecipeData memory data = ItemRecipe.get(itemId);
    assertEq(data.goldCost, uint32(5));
    assertEq(data.itemIds.length, uint256(2));
    assertEq(data.amounts.length, uint256(2));
    assertEq(data.itemIds[0], uint256(1));
    assertEq(data.amounts[0], uint32(10));
    assertEq(data.itemIds[1], uint256(10));
    assertEq(data.amounts[1], uint32(10));
  }
}
