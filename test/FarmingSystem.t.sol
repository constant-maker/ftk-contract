pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import {
  CharPosition,
  CharPositionData,
  CharInfoData,
  CharFarmingState,
  CharFarmingStateData,
  CharInventoryData,
  CharOtherItem,
  CharStats,
  CharCurrentStats,
  CharPerk
} from "@codegen/index.sol";
import { CharInventory } from "@codegen/tables/CharInventory.sol";
import { Tool2, Tool2Data, Item, ItemData } from "@codegen/index.sol";
import { CharacterStateType, ItemType } from "@codegen/common.sol";
import { SpawnSystemFixture, MoveSystemFixture, WelcomeSystemFixture } from "@fixtures/index.sol";
import { FarmingSystemFixture } from "@fixtures/FarmingSystemFixture.sol";
import { Config } from "@common/Config.sol";
import { CharacterInfoMock } from "@mocks/CharacterInfoMock.sol";
import { console2 } from "forge-std/console2.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharacterStateUtils } from "@utils/CharacterStateUtils.sol";
import { CharacterItemUtils } from "@utils/CharacterItemUtils.sol";
import { TileInfo3, TileInfo3Data } from "@codegen/tables/TileInfo3.sol";

contract FarmingSystemTest is FarmingSystemFixture, SpawnSystemFixture, MoveSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  uint256 woodTier1 = 1;
  uint256 woodTier2 = 2;

  int32 characterX;
  int32 characterY;

  function setUp()
    public
    virtual
    override(FarmingSystemFixture, SpawnSystemFixture, MoveSystemFixture, WelcomeSystemFixture)
  {
    FarmingSystemFixture.setUp();
    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
    // move to location that has resource
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, 20, -32);
    vm.stopPrank();

    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    characterX = characterPosition.x;
    characterY = characterPosition.y;
  }

  /// @dev Get random tool in character inventory
  function _getRandomExistedTool(
    uint256 characterId,
    uint256 toolIndexInInventory
  )
    internal
    view
    returns (uint256 toolId)
  {
    CharInventoryData memory characterInventory = CharInventory.get(characterId);
    uint256 numOfTools = characterInventory.toolIds.length;
    toolIndexInInventory = bound(toolIndexInInventory, 0, numOfTools - 1);

    return characterInventory.toolIds[toolIndexInInventory];
  }

  function testFuzz_FarmWood_ByAxe(uint256 toolIndexInInventory) external {
    CharInventoryData memory characterInventory = CharInventory.get(characterId);
    uint256 numOfTools = characterInventory.toolIds.length;
    toolIndexInInventory = bound(toolIndexInInventory, 0, numOfTools - 1);

    for (uint256 i = 0; i <= toolIndexInInventory; i++) {
      uint256 toolId = characterInventory.toolIds[i];
      Tool2Data memory tool = Tool2.get(toolId);
      uint256 itemId = tool.itemId;

      assertTrue(itemId > 0);

      if (Item.getItemType(itemId) == ItemType.WoodAxe) {
        _startFarming(player, characterId, woodTier1, toolId);
      } else {
        _expectStartFarmingReverted(player, characterId, woodTier1, toolId);
      }
    }
  }

  function test_FarmInfinity() external {
    uint32 resourceAmount = CharOtherItem.getAmount(characterId, woodTier1);
    _startFarming(player, characterId, woodTier1, 1);
    vm.warp(block.timestamp + 1 minutes);
    _finishFarmingAndFarmAgain(player, characterId);
    assertTrue(CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Farming);

    uint32 currentResourceAmount = CharOtherItem.getAmount(characterId, woodTier1);
    assertEq(resourceAmount + 5, currentResourceAmount);
    vm.warp(block.timestamp + 1 minutes);
    _finishFarming(player, characterId);
    currentResourceAmount = CharOtherItem.getAmount(characterId, woodTier1);
    assertEq(resourceAmount + 10, currentResourceAmount);
    assertTrue(CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Standby);
  }

  /// Expect revert
  function testFuzz_ShouldRevert_WhenStartFarmingHide(uint256 resourceId, uint256 toolIndexInInventory) external {
    // bound between hide tier 1 and hide tier 2
    uint256 resourceId = bound(resourceId, 16, 17);
    uint256 toolId = _getRandomExistedTool(characterId, toolIndexInInventory);

    _expectStartFarmingReverted(player, characterId, resourceId, toolId);
  }

  function test_ShouldRevert_OverWeight_WhenStartFarming() external { }

  function test_ShouldAbleToFinishFarming() external {
    uint256 toolId = 1;
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);
    console2.log("current weight: ", currentWeight);
    uint32 maxWeight = CharStats.getWeight(characterId);
    console2.log("max weight: ", maxWeight);

    _startFarming(player, characterId, woodTier1, toolId);

    vm.warp(block.timestamp + 15 * 60);

    _finishFarming(player, characterId);

    uint32 newCurrentWeight = CharCurrentStats.getWeight(characterId);
    console2.log("new current weight: ", newCurrentWeight);
    assertEq(newCurrentWeight, currentWeight + 5);

    uint32 resourceAmount = CharOtherItem.getAmount(characterId, woodTier1);
    assertGe(resourceAmount, 5);
  }

  function test_FarmTier3() external {
    vm.startPrank(worldDeployer);
    CharacterItemUtils.addNewItem(characterId, 163, 1);
    CharPerk.setLevel(characterId, ItemType.WoodAxe, 5);
    vm.stopPrank();
    uint256 toolId = 7;

    assertEq(Tool2.getDurability(toolId), 150);

    _startFarming(player, characterId, 3, toolId);

    vm.warp(block.timestamp + 15 * 60);

    _finishFarming(player, characterId);

    uint32 resourceAmount = CharOtherItem.getAmount(characterId, 3);
    assertEq(resourceAmount, 4);
  }

  function test_ShouldBreakToolWithZeroDurability() external {
    vm.startPrank(worldDeployer);
    CharStats.setWeight(characterId, 1000);
    vm.stopPrank();
    uint256 prevLen = CharInventory.lengthToolIds(characterId);
    _doFarmingToGetResource(player, characterId, woodTier1, 1, 50);
    assertEq(CharInventory.lengthToolIds(characterId), prevLen - 1);
  }

  function test_CheckTileQuota() external {
    vm.startPrank(worldDeployer);
    CharStats.setWeight(characterId, 1000);
    CharacterItemUtils.addNewItem(characterId, 163, 1);
    CharPerk.setLevel(characterId, ItemType.WoodAxe, 5);
    vm.stopPrank();
    uint8 perkLevel = CharPerk.getLevel(characterId, ItemType.WoodAxe);
    assertEq(perkLevel, 5);
    uint256 prevLen = CharInventory.lengthToolIds(characterId);
    for (uint256 i = 0; i < prevLen; i++) {
      console2.log("tool", CharInventory.getItemToolIds(characterId, i));
    }
    uint256 toolTier3Id = 7;

    TileInfo3Data memory tileInfo2 = TileInfo3.get(20, -32);
    assertEq(tileInfo2.farmingQuotas.length, 0);
    _doFarmingToGetResource(player, characterId, woodTier1, 1, 2);
    _doFarmingToGetResource(player, characterId, 3, toolTier3Id, 2);
    tileInfo2 = TileInfo3.get(20, -32);
    // for (uint256 i = 0; i < TileInfo3.farmingQuotas.length; i++) {
    //   console2.log("quota", TileInfo3.farmingQuotas[i]);
    // }
    assertEq(tileInfo2.farmingQuotas[0], 18); // from 20 => 18
    assertEq(tileInfo2.farmingQuotas[2], 14); // from 16 => 14
    vm.warp(block.timestamp + 3 hours);

    _doFarmingToGetResource(player, characterId, woodTier1, 1, 1);
    tileInfo2 = TileInfo3.get(20, -32);
    assertEq(tileInfo2.farmingQuotas[0], 19); // from 20 => 19
    assertEq(tileInfo2.farmingQuotas[2], 16); // from 16 => 16

    _doFarmingToGetResource(player, characterId, 3, toolTier3Id, 16);
    tileInfo2 = TileInfo3.get(20, -32);
    assertEq(tileInfo2.farmingQuotas[2], 0);
    // vm.expectRevert();
    // _startFarming(player, characterId, 3, toolTier3Id);
  }
}
