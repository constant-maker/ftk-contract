pragma solidity >=0.8.24;

import { CharInventory, CharInventoryData } from "@codegen/index.sol";
import { CharOtherItem } from "@codegen/tables/CharOtherItem.sol";
import { Tool2, Tool2Data, Item, ItemData, CharFund } from "@codegen/index.sol";
import { WorldFixture, SpawnSystemFixture, MoveSystemFixture } from "@fixtures/index.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";

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

  uint256 constant woodAxeTier1_Id = 18;

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
    InventoryItemUtils.addItem(characterId, 12, 15);
    CharFund.setGold(characterId, 12);
    vm.stopPrank();

    _craftItem(player, characterId, 1, woodAxeTier1_Id, 2);

    // assertion remaining resource amounts
    uint256 woodTier1_Amount = CharOtherItem.getAmount(characterId, woodTier1_Id);
    assertEq(woodTier1_Amount, 0);
    uint256 stoneTier1_Amount = CharOtherItem.getAmount(characterId, oreTier1_Id);
    assertEq(stoneTier1_Amount, 0);

    uint32 goldBalance = CharFund.getGold(characterId);
    assertEq(goldBalance, 2);

    CharInventoryData memory characterInventoryData = CharInventory.get(characterId);
    assertEq(characterInventoryData.toolIds.length, 2);

    uint256 healingPotionId = 35;
    _craftItem(player, characterId, 1, healingPotionId, 2);

    // assertion remaining resource amounts
    uint256 material1_amount = CharOtherItem.getAmount(characterId, 14);
    assertEq(material1_amount, 0);
    uint256 material2_amount = CharOtherItem.getAmount(characterId, 12);
    assertEq(material2_amount, 5);

    goldBalance = CharFund.getGold(characterId);
    assertEq(goldBalance, 0);

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
}
