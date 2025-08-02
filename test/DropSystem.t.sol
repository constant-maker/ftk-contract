pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, FarmingSystemFixture } from "./fixtures/index.sol";
import { CharPosition, CharOtherItem, CharCurrentStats } from "@codegen/index.sol";
import { InventoryToolUtils, InventoryEquipmentUtils } from "@utils/index.sol";
import { ItemsActionData } from "@common/Types.sol";

contract DropSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, FarmingSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  uint256 woodTier1 = 1;
  uint256 toolWoodAxe = 1;
  uint256 equipmentRustySword = 1;

  function setUp()
    public
    virtual
    override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, FarmingSystemFixture)
  {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_ShouldDropTool() external {
    uint32 beforeWeight = CharCurrentStats.getWeight(characterId);
    console2.log("before weight", beforeWeight);

    uint256[] memory toolIds = new uint256[](1);
    toolIds[0] = toolWoodAxe;
    ItemsActionData memory dropData = ItemsActionData({
      equipmentIds: new uint256[](0),
      toolIds: toolIds,
      itemIds: new uint256[](0),
      itemAmounts: new uint32[](0)
    });
    vm.startPrank(player);
    world.app__drop(characterId, dropData);
    vm.stopPrank();

    uint32 currentWeight = CharCurrentStats.getWeight(characterId);
    console2.log("current weight", currentWeight);
    assertEq(currentWeight + 2, beforeWeight);
  }

  function test_ShouldDropEquipment() external {
    uint32 beforeWeight = CharCurrentStats.getWeight(characterId);
    console2.log("before weight", beforeWeight);

    uint256[] memory equipmentIds = new uint256[](1);
    equipmentIds[0] = equipmentRustySword;
    ItemsActionData memory dropData = ItemsActionData({
      equipmentIds: equipmentIds,
      toolIds: new uint256[](0),
      itemIds: new uint256[](0),
      itemAmounts: new uint32[](0)
    });
    vm.startPrank(player);
    world.app__drop(characterId, dropData);
    vm.stopPrank();

    uint32 currentWeight = CharCurrentStats.getWeight(characterId);
    console2.log("current weight", currentWeight);
    assertEq(currentWeight + 5, beforeWeight);

    assertFalse(InventoryEquipmentUtils.hasEquipment(characterId, equipmentRustySword));
  }

  function test_ShouldDropResource() external {
    _doFarmingToGetResource(player, characterId, woodTier1, toolWoodAxe, 20);
    uint32 beforeWeight = CharCurrentStats.getWeight(characterId);
    console2.log("before weight", beforeWeight);

    uint256[] memory itemIds = new uint256[](1);
    itemIds[0] = woodTier1;
    uint32[] memory itemAmounts = new uint32[](1);
    itemAmounts[0] = 15;
    ItemsActionData memory dropData = ItemsActionData({
      equipmentIds: new uint256[](0),
      toolIds: new uint256[](0),
      itemIds: itemIds,
      itemAmounts: itemAmounts
    });
    vm.startPrank(player);
    world.app__drop(characterId, dropData);
    vm.stopPrank();

    uint32 currentWeight = CharCurrentStats.getWeight(characterId);
    console2.log("current weight", currentWeight);
    assertEq(currentWeight + 15, beforeWeight);

    uint32 currentResourceAmount = CharOtherItem.getAmount(characterId, woodTier1);
    assertEq(currentResourceAmount, 85);
  }

  function test_Revert_DropResource() external {
    _doFarmingToGetResource(player, characterId, woodTier1, toolWoodAxe, 20);
    uint32 beforeWeight = CharCurrentStats.getWeight(characterId);
    console2.log("before weight", beforeWeight);

    uint256[] memory itemIds = new uint256[](1);
    itemIds[0] = woodTier1;
    uint32[] memory itemAmounts = new uint32[](1);
    itemAmounts[0] = 105;
    ItemsActionData memory dropData = ItemsActionData({
      equipmentIds: new uint256[](0),
      toolIds: new uint256[](0),
      itemIds: itemIds,
      itemAmounts: itemAmounts
    });
    vm.expectRevert(); // drop amount > balance
    vm.startPrank(player);
    world.app__drop(characterId, dropData);
    vm.stopPrank();
  }

  function test_Revert_DropEquipment() external {
    uint256[] memory equipmentIds = new uint256[](1);
    equipmentIds[0] = 100;
    ItemsActionData memory dropData = ItemsActionData({
      equipmentIds: equipmentIds,
      toolIds: new uint256[](0),
      itemIds: new uint256[](0),
      itemAmounts: new uint32[](0)
    });
    vm.expectRevert(); // equipment not exist
    vm.startPrank(player);
    world.app__drop(characterId, dropData);
    vm.stopPrank();
  }

  function test_Revert_DropTool() external {
    uint256[] memory toolIds = new uint256[](1);
    toolIds[0] = 100;
    ItemsActionData memory dropData = ItemsActionData({
      equipmentIds: new uint256[](0),
      toolIds: toolIds,
      itemIds: new uint256[](0),
      itemAmounts: new uint32[](0)
    });
    vm.expectRevert(); // tool not exist
    vm.startPrank(player);
    world.app__drop(characterId, dropData);
    vm.stopPrank();
  }
}
