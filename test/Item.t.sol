pragma solidity >=0.8.24;

import { Item, ItemData, EquipmentInfo2, EquipmentInfo2Data } from "@codegen/index.sol";
import { ItemType } from "@codegen/common.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";

contract ItemTest is WorldFixture, SpawnSystemFixture {
  function setUp() public virtual override(WorldFixture, SpawnSystemFixture) {
    WorldFixture.setUp();
  }

  function test_HaveData() external {
    ItemData memory item = Item.get(269);
    assertTrue(item.itemType == ItemType.Card);
    assertEq(item.tier, 1);

    EquipmentInfo2Data memory equipmentInfo2 = EquipmentInfo2.get(41);
    assertEq(equipmentInfo2.bonusWeight, 0);
    assertEq(equipmentInfo2.barrier, 0);
  }
}
