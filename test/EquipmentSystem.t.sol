pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture } from "./fixtures/index.sol";
import { CharacterItemUtils } from "@utils/CharacterItemUtils.sol";
import {
  CharEquipment,
  CharInventory,
  CharPerk,
  CharStats,
  CharCurrentStats,
  CharBaseStats,
  CharGrindSlot,
  Equipment,
  EquipmentInfo
} from "@codegen/index.sol";
import { SlotType, ItemType } from "@codegen/common.sol";
import { EquipData } from "@systems/app/EquipmentSystem.sol";

contract EquipmentSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_ShouldGearUpEquipments() external {
    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });

    // before state
    uint256 equipmentsInInventory = CharInventory.getEquipmentIds(characterId).length;

    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    // after
    uint256 gearedUpEquipmentId = CharEquipment.get(characterId, SlotType.Weapon);
    assertEq(gearedUpEquipmentId, equipDatas[0].equipmentId);
    uint256 currentEquipmentsInInventory = CharInventory.getEquipmentIds(characterId).length;
    assertEq(currentEquipmentsInInventory + 1, equipmentsInInventory);
  }

  function test_ShouldUnequipEquipments() external {
    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    EquipmentInfo.setAtk(30, 1);
    vm.stopPrank();

    // unequip
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 0 });

    // before state
    uint256 equipmentsInInventory = CharInventory.getEquipmentIds(characterId).length;
    uint16 atk = CharCurrentStats.getAtk(characterId);
    uint16 def = CharCurrentStats.getDef(characterId);
    uint16 baseAtk = CharBaseStats.getAtk(characterId);
    uint16 baseDef = CharBaseStats.getDef(characterId);

    console2.log("before attack", atk);
    console2.log("before def", def);

    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    // after
    uint256 currentEquipmentsInInventory = CharInventory.getEquipmentIds(characterId).length;
    assertEq(currentEquipmentsInInventory, equipmentsInInventory + 1);

    uint256 gearedUpEquipmentId = CharEquipment.get(characterId, SlotType.Weapon);
    assertEq(gearedUpEquipmentId, 0);

    uint16 currentAtk = CharCurrentStats.getAtk(characterId);
    uint16 currentDef = CharCurrentStats.getDef(characterId);
    console2.log("after attack", currentAtk);
    console2.log("after def", currentDef);

    assertEq(currentAtk + 2, atk);
    assertEq(currentDef + 1, def);
    assertEq(currentAtk, baseAtk + 2);
    assertEq(currentDef, baseDef + 2);

    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();
    assertEq(currentAtk + 1, CharCurrentStats.getAtk(characterId)); // atk decrease 1
  }

  function test_ShouldReplaceEquipment() external {
    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    uint16 prevAtk = CharCurrentStats.getAtk(characterId);
    console2.log("prevAtk", prevAtk);

    vm.startPrank(worldDeployer);
    CharacterItemUtils.addNewItem(characterId, 32, 1); // add bow tier 1
    CharPerk.setLevel(characterId, ItemType.Bow, 2); // set perk level for bow to level 2
    vm.stopPrank();

    console2.log("equipment item id", Equipment.getItemId(2));
    console2.log("equipment info", EquipmentInfo.getAtk(Equipment.getItemId(2)));

    // gear up equipments
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 2 });
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    uint16 currentAtk = CharCurrentStats.getAtk(characterId);
    console2.log("currentAtk", currentAtk);
    assertEq(currentAtk, prevAtk + 2);
  }

  function test_ShouldUpdateGrindSlot() external {
    SlotType grindSlot = CharGrindSlot.get(characterId);
    assertTrue(grindSlot == SlotType.Weapon);
    vm.startPrank(player);
    world.app__updateGrindSlot(characterId, SlotType.Armor);
    vm.stopPrank();
    SlotType currentGrindSlot = CharGrindSlot.get(characterId);
    assertTrue(currentGrindSlot == SlotType.Armor);
  }

  function test_Revert_GearUpNonexistentEquipment() external {
    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = EquipData({
      slotType: SlotType.Weapon,
      equipmentId: 2 // nonexistent
     });
    vm.expectRevert();
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();
  }

  function test_Revert_GearUpUnmatchSlotType() external {
    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = EquipData({
      slotType: SlotType.Armor,
      equipmentId: 1 // a weapon
     });
    vm.expectRevert();
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();
  }
}
