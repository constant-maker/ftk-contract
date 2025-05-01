pragma solidity >=0.8.24;

import { Item, ItemData } from "@codegen/index.sol";
import { ItemType } from "@codegen/common.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";

contract ItemTest is WorldFixture, SpawnSystemFixture {
  function setUp() public virtual override(WorldFixture, SpawnSystemFixture) {
    WorldFixture.setUp();
  }

  function test_HaveData() external {
    ItemData memory item = Item.get(185);
    assertTrue(item.itemType == ItemType.Card);
    assertEq(item.tier, 2);
  }
}
