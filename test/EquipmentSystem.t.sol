pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture } from "./fixtures/index.sol";
import { CharacterItemUtils, InventoryEquipmentUtils } from "@utils/index.sol";
import {
  CharEquipment,
  CharInventory,
  CharPerk,
  CharStats,
  CharStatsData,
  CharCurrentStats,
  CharCurrentStatsData,
  CharBaseStats,
  CharGrindSlot,
  Equipment,
  EquipmentInfo,
  Item,
  CharFund
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
    console2.log("init attack", CharCurrentStats.getAtk(characterId));
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
    assertEq(currentAtk + 2, CharCurrentStats.getAtk(characterId)); // atk increased by 2
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
    CharacterItemUtils.addNewItem(characterId, 35, 1); // add bow tier 1
    CharPerk.setLevel(characterId, ItemType.Bow, 2); // set perk level for bow to level 2
    vm.stopPrank();

    console2.log("equipment item id", Equipment.getItemId(2));
    console2.log("item atk", EquipmentInfo.getAtk(Equipment.getItemId(2)));
    console2.log("item def", EquipmentInfo.getDef(Equipment.getItemId(2)));
    console2.log("item agi", EquipmentInfo.getAgi(Equipment.getItemId(2)));

    // gear up equipments
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 2 });
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    uint16 currentAtk = CharCurrentStats.getAtk(characterId);
    console2.log("currentAtk", currentAtk);
    assertEq(currentAtk, prevAtk + 3);
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

  function test_UnequipAndEquipSameTx() external {
    vm.startPrank(worldDeployer);
    CharacterItemUtils.addNewItem(characterId, 56, 1); // headgear - 2
    CharacterItemUtils.addNewItem(characterId, 72, 1); // shield - 3
    CharacterItemUtils.addNewItem(characterId, 262, 1); // sword - 4
    CharacterItemUtils.addNewItem(characterId, 266, 1); // mount - 1 / - 5
    CharacterItemUtils.addNewItem(characterId, 219, 1); // axe - weapon - 6
    CharacterItemUtils.addNewItem(characterId, 245, 1); // headgear - 7
    CharacterItemUtils.addNewItem(characterId, 267, 1); // mount - 2 - 8
    for (uint8 i = 0; i < 25; i++) {
      CharPerk.setLevel(characterId, ItemType(i), 9);
    }
    CharStats.setLevel(characterId, 90);
    vm.stopPrank();

    uint256[] memory equipmentIds = CharInventory.getEquipmentIds(characterId);
    // for (uint256 i = 0; i < equipmentIds.length; i++) {
    // console2.log("equipment id", equipmentIds[i]);
    // uint256 itemId = Equipment.getItemId(equipmentIds[i]);
    // console2.log("item id", itemId);
    // console2.log("item name", Item.getName(itemId));
    // }
    CharCurrentStatsData memory currentStats = CharCurrentStats.get(characterId);
    CharStatsData memory stats = CharStats.get(characterId);
    console2.log("current atk", currentStats.atk);
    console2.log("current def", currentStats.def);
    console2.log("current hp", currentStats.hp);
    console2.log("max hp", stats.hp);
    console2.log("current ms", currentStats.ms);
    console2.log("max weight", stats.weight);

    EquipData[] memory equipDatas = new EquipData[](4);
    equipDatas[0] = EquipData({ slotType: SlotType.Headgear, equipmentId: 2 });
    equipDatas[1] = EquipData({ slotType: SlotType.SubWeapon, equipmentId: 3 });
    equipDatas[2] = EquipData({ slotType: SlotType.Weapon, equipmentId: 4 });
    equipDatas[3] = EquipData({ slotType: SlotType.Mount, equipmentId: 5 });

    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    currentStats = CharCurrentStats.get(characterId);
    stats = CharStats.get(characterId);

    console2.log("current atk", currentStats.atk);
    console2.log("current def", currentStats.def);
    console2.log("current hp", currentStats.hp);
    console2.log("max hp", stats.hp);
    console2.log("current ms", currentStats.ms);
    console2.log("max weight", stats.weight);
    assertEq(stats.weight, 240);

    equipDatas = new EquipData[](6);
    equipDatas[0] = EquipData({ slotType: SlotType.Mount, equipmentId: 8 });
    equipDatas[1] = EquipData({ slotType: SlotType.Headgear, equipmentId: 0 });
    equipDatas[2] = EquipData({ slotType: SlotType.Weapon, equipmentId: 0 });
    // equipDatas[3] = EquipData({ slotType: SlotType.Mount, equipmentId: 0 });
    equipDatas[3] = EquipData({ slotType: SlotType.Headgear, equipmentId: 7 });
    equipDatas[4] = EquipData({ slotType: SlotType.Weapon, equipmentId: 6 });

    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();
    currentStats = CharCurrentStats.get(characterId);
    stats = CharStats.get(characterId);
    console2.log("current atk", currentStats.atk);
    console2.log("current def", currentStats.def);
    console2.log("current hp", currentStats.hp);
    console2.log("max hp", stats.hp);
    console2.log("current ms", currentStats.ms);
    console2.log("max weight", stats.weight);
    assertEq(stats.weight, 280);
  }

  function test_ShouldUpgradeEquipment() external {
    vm.startPrank(worldDeployer);
    // id from 2 -> 4
    CharacterItemUtils.addNewItem(characterId, 33, 3);
    vm.stopPrank();
    uint256 characterId = 1;

    vm.expectRevert(); // no gold
    vm.startPrank(player);
    world.app__upgradeEquipment(characterId, 1, 2);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharFund.setGold(characterId, 10_000);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__upgradeEquipment(characterId, 1, 2);
    vm.stopPrank();

    assertEq(Equipment.getLevel(1), 2);

    vm.expectRevert(); // equipment not match
    vm.startPrank(player);
    world.app__upgradeEquipment(characterId, 1, 4);
    vm.stopPrank();

    assertFalse(InventoryEquipmentUtils.hasEquipment(characterId, 2));

    vm.startPrank(player);
    world.app__upgradeEquipment(characterId, 3, 4);
    world.app__upgradeEquipment(characterId, 1, 3);
    vm.stopPrank();

    assertEq(Equipment.getLevel(1), 3);

    CharCurrentStatsData memory currentStats = CharCurrentStats.get(characterId);
    console2.log("current atk", currentStats.atk);
    console2.log("current def", currentStats.def);

    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    CharCurrentStatsData memory newCurrentStats = CharCurrentStats.get(characterId);
    console2.log("current atk", newCurrentStats.atk);
    console2.log("current def", newCurrentStats.def);
    assertEq(newCurrentStats.atk, currentStats.atk + 4);
    assertEq(newCurrentStats.def, currentStats.def + 3);

    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 0 });
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    newCurrentStats = CharCurrentStats.get(characterId);
    console2.log("current atk", newCurrentStats.atk);
    console2.log("current def", newCurrentStats.def);
    assertEq(newCurrentStats.atk, currentStats.atk);
    assertEq(newCurrentStats.def, currentStats.def);
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
