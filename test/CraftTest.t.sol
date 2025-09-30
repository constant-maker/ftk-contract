pragma solidity >=0.8.24;

import { CharInventory, CharInventoryData } from "@codegen/index.sol";
import { CharOtherItem } from "@codegen/tables/CharOtherItem.sol";
import { Tool2, Tool2Data, Item, ItemData, CharFund, CharStats, CharPerk } from "@codegen/index.sol";
import { ItemType } from "@codegen/common.sol";
import { WorldFixture, SpawnSystemFixture, MoveSystemFixture } from "@fixtures/index.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { console2 } from "forge-std/console2.sol";
import { TargetItemData } from "@systems/app/ConsumeSystem.sol";

abstract contract CraftSystemFixture is WorldFixture, SpawnSystemFixture, MoveSystemFixture {
  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, MoveSystemFixture) {
    WorldFixture.setUp();
  }

  function _craftItem(
    address _player,
    uint256 _characterId,
    uint256 _capitalId,
    uint256 _itemId,
    uint32 _amount
  )
    internal
  {
    vm.startPrank(_player);
    world.app__craftItem(_characterId, _capitalId, _itemId, _amount);
    vm.stopPrank();
  }
}

contract CraftSystemTest is CraftSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  uint256 constant woodTier1_Id = 1;
  uint256 constant oreTier1_Id = 10;

  uint256 constant woodAxeTier1_Id = 21;

  function setUp() public virtual override {
    CraftSystemFixture.setUp();
    characterId = _createDefaultCharacter(player);
  }

  function test_ShouldAbleToCraft_WoodAxe_Tier1() external {
    // give player enough resources
    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, woodTier1_Id, 20);
    InventoryItemUtils.addItem(characterId, oreTier1_Id, 20);
    InventoryItemUtils.addItem(characterId, 14, 20);
    InventoryItemUtils.addItem(characterId, 12, 20);
    CharFund.setGold(characterId, 12);
    vm.stopPrank();

    _craftItem(player, characterId, 1, woodAxeTier1_Id, 2);

    // assertion remaining resource amounts
    uint256 woodTier1_Amount = CharOtherItem.getAmount(characterId, woodTier1_Id);
    assertEq(woodTier1_Amount, 0);
    uint256 stoneTier1_Amount = CharOtherItem.getAmount(characterId, oreTier1_Id);
    assertEq(stoneTier1_Amount, 0);

    uint32 goldBalance = CharFund.getGold(characterId);
    assertEq(goldBalance, 10);

    CharInventoryData memory characterInventoryData = CharInventory.get(characterId);
    assertEq(characterInventoryData.toolIds.length, 2);

    uint256 healingPotionId = 66;
    _craftItem(player, characterId, 1, healingPotionId, 2);

    // assertion remaining resource amounts
    uint256 material1_amount = CharOtherItem.getAmount(characterId, 14);
    assertEq(material1_amount, 0);
    uint256 material2_amount = CharOtherItem.getAmount(characterId, 12);
    assertEq(material2_amount, 0);

    goldBalance = CharFund.getGold(characterId);
    assertEq(goldBalance, 10);

    assertEq(CharOtherItem.getAmount(characterId, healingPotionId), 2);
  }

  function test_ShouldRevertNotInCapital() external {
    // give player enough resources
    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, woodTier1_Id, 10);
    InventoryItemUtils.addItem(characterId, oreTier1_Id, 10);
    CharFund.setGold(characterId, 10);
    vm.stopPrank();

    _moveToMonsterLocation(characterId);

    vm.expectRevert();
    _craftItem(player, characterId, 1, woodAxeTier1_Id, 1);
  }

  function test_ShouldCraftTier6Item() external {
    uint256 itemRecipeID = 183;

    // give player enough resources
    vm.startPrank(worldDeployer);
    CharStats.setWeight(characterId, 163);
    InventoryItemUtils.addItem(characterId, 1, 30);
    InventoryItemUtils.addItem(characterId, 10, 30);
    InventoryItemUtils.addItem(characterId, 5, 20);
    CharFund.setGold(characterId, 1028);
    vm.stopPrank();

    vm.expectRevert(); // expect revert if perk level is not enough
    vm.startPrank(player);
    world.app__craftItem(characterId, 1, itemRecipeID, 1);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharPerk.setLevel(characterId, ItemType.StoneHammer, 5);
    CharPerk.setLevel(characterId, ItemType.FishingRod, 6);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__craftItem(characterId, 1, itemRecipeID, 1);
    vm.stopPrank();
  }

  function test_CraftBuffItem() external {
    uint256 itemRecipeID = 356;

    // give player enough resources
    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, 1, 30);
    InventoryItemUtils.addItem(characterId, 2, 30);
    CharFund.setGold(characterId, 10);
    vm.stopPrank();

    vm.expectRevert(); // exceed max buff item
    vm.startPrank(player);
    world.app__craftItem(characterId, 1, itemRecipeID, 5);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__craftItem(characterId, 1, itemRecipeID, 3);
    vm.stopPrank();

    TargetItemData memory targetData;
    targetData.targetPlayers = new uint256[](1);
    targetData.targetPlayers[0] = characterId;
    targetData.x = 30;
    targetData.y = -36;

    vm.startPrank(player);
    world.app__consumeItem(characterId, itemRecipeID, 1, targetData);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__craftItem(characterId, 1, itemRecipeID, 1);
    vm.stopPrank();
  }
}
