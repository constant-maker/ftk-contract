pragma solidity >=0.8.24;

import { Vm } from "forge-std/Vm.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { MoveSystemFixture } from "@fixtures/MoveSystemFixture.sol";
import { CharCollection, CollectionExchange, CharOtherItem } from "@codegen/index.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharacterPositionUtils, InventoryItemUtils } from "@utils/index.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { TestHelper } from "./TestHelper.sol";
import { console2 } from "forge-std/console2.sol";

contract CollectionSystemTest is WorldFixture, SpawnSystemFixture, MoveSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, MoveSystemFixture) {
    WorldFixture.setUp();
    characterId = _createDefaultCharacter(player);
  }

  function test_CollectionSystem() external {
    vm.startPrank(worldDeployer);
    CollectionExchange.set(1, 2, 100);

    InventoryItemUtils.addItem(characterId, 1, 100);

    CharacterPositionUtils.moveToLocation(characterId, 0, 0);
    vm.stopPrank();

    // add items to inventory
    uint256[] memory itemIds = new uint256[](1);
    itemIds[0] = 1;
    uint32[] memory amounts = new uint32[](1);
    amounts[0] = 50;

    vm.expectRevert(); // not in capital
    vm.prank(player);
    world.app__addToCollection(characterId, 1, itemIds, amounts);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToCapital(characterId);
    vm.stopPrank();

    vm.expectRevert(); // insufficient item amount
    vm.prank(player);
    world.app__exchangeItem(characterId, 1, 2, 1);
    vm.stopPrank();

    amounts[0] = 99;
    vm.prank(player);
    world.app__addToCollection(characterId, 1, itemIds, amounts);
    vm.stopPrank();

    uint32 remainingAmountInInventory = CharOtherItem.getAmount(characterId, 1);
    assertEq(remainingAmountInInventory, 1); // 99 moved to collection
    uint32 amountInCollection = CharCollection.get(characterId, 1);
    assertEq(amountInCollection, 99);

    vm.expectRevert(); // insufficient item amount
    vm.prank(player);
    world.app__exchangeItem(characterId, 1, 2, 1);
    vm.stopPrank();

    amounts[0] = 1;
    vm.prank(player);
    world.app__addToCollection(characterId, 1, itemIds, amounts);
    vm.stopPrank();

    remainingAmountInInventory = CharOtherItem.getAmount(characterId, 1);
    assertEq(remainingAmountInInventory, 0); // 100 moved to collection
    amountInCollection = CharCollection.get(characterId, 1);
    assertEq(amountInCollection, 100);

    vm.prank(player);
    world.app__exchangeItem(characterId, 1, 2, 1);
    vm.stopPrank();

    remainingAmountInInventory = CharOtherItem.getAmount(characterId, 2);
    assertEq(remainingAmountInInventory, 1); // received 1 output item
    amountInCollection = CharCollection.get(characterId, 1);
    assertEq(amountInCollection, 0); // 100 input items exchanged
  }
}
