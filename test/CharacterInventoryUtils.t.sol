pragma solidity >=0.8.24;

import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture } from "./fixtures/index.sol";
import { InventoryEquipmentUtils, InventoryToolUtils } from "@utils/index.sol";
import { CharInventory, CharInventoryData, CharCurrentStats } from "@codegen/index.sol";
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

    assertEq(weight + 15, currentWeight);
  }

  // function test_RemoveEquipment() external {
  //   // before state
  //   uint256 equipmentNum = CharInventory.getEquipmentIds(characterId).length;
  //   uint32 weight = CharCurrentStats.getWeight(characterId);

  //   vm.startPrank(worldDeployer);
  //   InventoryEquipmentUtils.removeEquipment(characterId, 1);
  //   vm.stopPrank();

  //   // after state
  //   uint256 currentEquipmentNum = CharInventory.getEquipmentIds(characterId).length;
  //   uint32 currentWeight = CharCurrentStats.getWeight(characterId);
  //   console.log("equipmentNum %d", equipmentNum);
  //   console.log("currentEquipmentNum %d", currentEquipmentNum);
  //   console.log("weight %d", weight);
  //   console.log("currentWeight %d", currentWeight);
  //   assertEq(equipmentNum, currentEquipmentNum + 1);
  //   assertEq(weight, currentWeight);
  // }

  // function test_RemoveTool() external {
  //   // before state
  //   uint256 toolNum = CharInventory.getToolIds(characterId).length;
  //   uint32 weight = CharCurrentStats.getWeight(characterId);

  //   vm.startPrank(worldDeployer);
  //   InventoryToolUtils.removeTool(characterId, 1);
  //   vm.stopPrank();

  //   // after state
  //   uint256 currentToolNum = CharInventory.getToolIds(characterId).length;
  //   uint32 currentWeight = CharCurrentStats.getWeight(characterId);
  //   console.log("toolNum %d", toolNum);
  //   console.log("currentToolNum %d", currentToolNum);
  //   console.log("weight %d", weight);
  //   console.log("currentWeight %d", currentWeight);
  //   assertEq(toolNum, currentToolNum + 1);
  //   assertEq(currentToolNum, 5);
  //   assertEq(weight, currentWeight);
  // }
}
