pragma solidity >=0.8.24;

import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture } from "./fixtures/index.sol";
import { InventoryToolUtils, InventoryItemUtils } from "@utils/index.sol";
import { CharInventory, CharInventoryData, CharCurrentStats, CharOtherItem, CharItemCache, Item } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";
import { console } from "forge-std/console.sol";

contract CharacterInventoryUtilsTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    uint32 weight = CharCurrentStats.getWeight(characterId);
    _claimWelcomePackages(player, characterId);
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);

    CharInventoryData memory characterInventory = CharInventory.get(characterId);
    assertEq(characterInventory.toolIds.length, 6);

    assertEq(weight + 19, currentWeight);
  }

  function test_CanBringManyExpBuffItem() external {
    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, 358, 50); // exp buff item
    vm.stopPrank();
    assertEq(CharOtherItem.getAmount(characterId, 358), 50);
  }

  function test_ShouldUseCachedItemWeightAfterConfigChange() external {
    uint256 itemId = 1;
    uint32 baseWeight = CharCurrentStats.getWeight(characterId);

    vm.startPrank(worldDeployer);
    Item.setWeight(itemId, 2);
    InventoryItemUtils.addItem(characterId, itemId, 10);
    vm.stopPrank();

    assertEq(CharCurrentStats.getWeight(characterId), baseWeight + 20);
    assertEq(CharItemCache.getWeight(characterId, itemId), 2);

    vm.startPrank(worldDeployer);
    Item.setWeight(itemId, 3);
    InventoryItemUtils.addItem(characterId, itemId, 5);
    vm.stopPrank();

    assertEq(CharCurrentStats.getWeight(characterId), baseWeight + 45);
    assertEq(CharItemCache.getWeight(characterId, itemId), 3);

    vm.startPrank(worldDeployer);
    Item.setWeight(itemId, 8);
    InventoryItemUtils.removeItem(characterId, itemId, 10);
    vm.stopPrank();

    assertEq(CharCurrentStats.getWeight(characterId), baseWeight + 15);
    assertEq(CharItemCache.getWeight(characterId, itemId), 3);

    vm.startPrank(worldDeployer);
    InventoryItemUtils.removeItem(characterId, itemId, 5);
    vm.stopPrank();

    assertEq(CharCurrentStats.getWeight(characterId), baseWeight);
    assertEq(CharItemCache.getWeight(characterId, itemId), 0);
  }

  function test_RevertWhenBatchContainsDuplicateItemIds() external {
    uint256[] memory itemIds = new uint256[](2);
    itemIds[0] = 1;
    itemIds[1] = 1;

    uint32[] memory amounts = new uint32[](2);
    amounts[0] = 1;
    amounts[1] = 2;

    vm.startPrank(worldDeployer);
    vm.expectRevert(abi.encodeWithSelector(Errors.Inventory_DuplicateItemId.selector, uint256(1)));
    InventoryItemUtils.addItems(characterId, itemIds, amounts);
    vm.stopPrank();
  }
}
