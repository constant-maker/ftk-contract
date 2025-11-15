pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { CharInventory, CharInventoryData } from "@codegen/index.sol";
import { Tool2, Tool2Data, Equipment, EquipmentData, ItemV2, ItemV2Data } from "@codegen/index.sol";
import { CharacterStateType, ResourceType, ItemCategoryType, ItemType } from "@codegen/common.sol";
import { WorldFixture, SpawnSystemFixture, MoveSystemFixture, WelcomeSystemFixture } from "@fixtures/index.sol";
import { Config } from "@common/Config.sol";
import { CharacterInfoMock } from "@mocks/CharacterInfoMock.sol";
import { console2 } from "forge-std/console2.sol";

contract WelcomePackagesTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player1 = makeAddr("player1");
  address player2 = makeAddr("player2");
  uint256 characterId_1;
  uint256 characterId_2;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();
    console2.log("world set up done");
    characterId_1 = _createDefaultCharacter(player1);
    _claimWelcomePackages(player1, characterId_1);
    characterId_2 = _createCharacterWithName(player2, "character2");
    _claimWelcomePackages(player2, characterId_2);
  }

  function test_ShouldReceiveCorrectTools() external {
    CharInventoryData memory characterInventory = CharInventory.get(characterId_1);
    assertEq(characterInventory.toolIds.length, 6);
    for (uint256 i = 0; i < characterInventory.toolIds.length; i++) {
      uint256 toolId = characterInventory.toolIds[i];

      Tool2Data memory tool = Tool2.get(toolId);
      assertEq(tool.characterId, characterId_1);
      assertGe(tool.itemId, 21);
      assertLe(tool.itemId, 31);
    }
  }

  function test_ShouldReceiveCorrectEquipments() external {
    CharInventoryData memory characterInventory = CharInventory.get(characterId_1);
    assertEq(characterInventory.equipmentIds.length, 1);
    uint256 equipmentId = characterInventory.equipmentIds[0];

    EquipmentData memory equipment = Equipment.get(equipmentId);
    assertEq(equipment.characterId, characterId_1);
    assertEq(equipment.itemId, 33); // rusty sword
  }

  function test_ShouldReceiveHealingPotion() external { }

  function test_ShouldReceiveCorrectToolsMultiUser() external {
    CharInventoryData memory characterInventory = CharInventory.get(characterId_2);
    assertEq(characterInventory.toolIds.length, 6);
    for (uint256 i = 0; i < characterInventory.toolIds.length; i++) {
      uint256 toolId = characterInventory.toolIds[i];
      console2.log("toolId", toolId);
      Tool2Data memory tool = Tool2.get(toolId);
      if (toolId == 8) {
        console2.log("itemId", tool.itemId);
        assertTrue(ItemV2.getItemType(tool.itemId) == ItemType.StoneHammer);
      }
      assertEq(tool.characterId, characterId_2);
      assertGe(tool.itemId, 21);
      assertLe(tool.itemId, 31);
    }
  }
}
