pragma solidity >=0.8.24;

import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";
import { console2 } from "forge-std/console2.sol";
import { CharStats, CharStatsData } from "@codegen/tables/CharStats.sol";
import { CharCurrentStats, CharCurrentStatsData } from "@codegen/tables/CharCurrentStats.sol";
import { CharBaseStats, CharBaseStatsData } from "@codegen/tables/CharBaseStats.sol";
import {
  CharReborn, CharInfo, ItemV2, CharInventory, CharEquipment, CharEquipStats, Equipment
} from "@codegen/index.sol";
import { EquipData } from "@systems/app/EquipmentSystem.sol";
import { SlotType } from "@codegen/common.sol";
import { Config } from "@common/Config.sol";
import { CharAchievementUtils } from "@utils/CharAchievementUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { CharacterItemUtils, InventoryEquipmentUtils } from "@utils/index.sol";

contract RebornSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_Reborn() external {
    vm.startPrank(worldDeployer);
    CharCurrentStats.setExp(characterId, 132);
    CharStats.setLevel(characterId, 98);
    CharStats.setStatPoint(characterId, 10);
    vm.stopPrank();

    vm.expectRevert();
    vm.startPrank(player);
    world.app__reborn(characterId);
    vm.stopPrank();

    (uint16 oAtk, uint16 oDef, uint16 oAgi) = _getCharacterOriginalStats(characterId);
    console2.log("original atk", oAtk);
    console2.log("original def", oDef);
    console2.log("original agi", oAgi);

    CharCurrentStatsData memory prevCharCurrentStats = CharCurrentStats.get(characterId);
    console2.log("prev atk", prevCharCurrentStats.atk);

    vm.startPrank(worldDeployer);
    CharStats.setLevel(characterId, 99);
    CharBaseStats.setAtk(characterId, 10);
    CharBaseStats.setAgi(characterId, 1);
    CharCurrentStats.setAtk(characterId, prevCharCurrentStats.atk + 10);
    vm.stopPrank();

    console2.log("setup atk", CharCurrentStats.getAtk(characterId));

    vm.expectRevert(); // no resource
    vm.startPrank(player);
    world.app__reborn(characterId);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    (uint256[] memory itemIds, uint32[] memory amounts) = _requiredResources(1);
    InventoryItemUtils.addItems(characterId, itemIds, amounts);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__reborn(characterId);
    vm.stopPrank();

    CharStatsData memory charStats = CharStats.get(characterId);
    CharCurrentStatsData memory charCurrentStats = CharCurrentStats.get(characterId);
    CharBaseStatsData memory charBaseStats = CharBaseStats.get(characterId);
    assertEq(charStats.level, 1);
    assertEq(charStats.statPoint, 20);
    console2.log("current atk", charCurrentStats.atk);
    assertEq(charCurrentStats.atk, prevCharCurrentStats.atk + 3); // achievement
    assertEq(charCurrentStats.def, prevCharCurrentStats.def + 3);
    assertEq(charCurrentStats.agi, prevCharCurrentStats.agi + 3);
  }

  function test_RebornWithEquipment() external {
    vm.startPrank(worldDeployer);
    CharCurrentStats.setExp(characterId, 132);
    CharStats.setLevel(characterId, 98);
    vm.stopPrank();

    vm.expectRevert();
    vm.startPrank(player);
    world.app__reborn(characterId);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharStats.setLevel(characterId, 99);
    vm.stopPrank();

    CharCurrentStatsData memory prevCharCurrentStats = CharCurrentStats.get(characterId);
    console2.log("prev atk", prevCharCurrentStats.atk);
    console2.log("prev def", prevCharCurrentStats.def);
    console2.log("prev agi", prevCharCurrentStats.agi);

    EquipData memory equipData = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });
    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = equipData;
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    (uint256[] memory itemIds, uint32[] memory amounts) = _requiredResources(1);
    InventoryItemUtils.addItems(characterId, itemIds, amounts);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__reborn(characterId);
    vm.stopPrank();

    CharStatsData memory charStats = CharStats.get(characterId);
    CharCurrentStatsData memory charCurrentStats = CharCurrentStats.get(characterId);
    CharBaseStatsData memory charBaseStats = CharBaseStats.get(characterId);
    assertEq(charStats.level, 1);
    assertEq(charStats.statPoint, 20);
    assertEq(charCurrentStats.exp, 0);
    console2.log(" atk", charCurrentStats.atk); // should be 5 (2 + 3 (achievement bonus))
    assertEq(charCurrentStats.atk, prevCharCurrentStats.atk + 3); // achievement
    assertEq(charCurrentStats.def, prevCharCurrentStats.def + 3);
    assertEq(charCurrentStats.agi, prevCharCurrentStats.agi + 3);
    assertEq(charCurrentStats.hp, Config.DEFAULT_HP);
    assertEq(1, CharReborn.get(characterId));
    assertTrue(CharAchievementUtils.hasAchievement(characterId, 9));

    uint256[] memory equipmentIds = CharInventory.getEquipmentIds(characterId);
    assertEq(equipmentIds.length, 1);
    assertEq(equipmentIds[0], 1);

    vm.startPrank(worldDeployer);
    ItemV2.setTier(33, 2);
    vm.stopPrank();

    vm.expectRevert();
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    ItemV2.setTier(33, 1);
    vm.stopPrank();
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();
    assertEq(CharCurrentStats.getAtk(characterId), 7);
  }

  function test_RebornWithEquipment2() external {
    // set level and exp
    vm.startPrank(worldDeployer);
    CharCurrentStats.setExp(characterId, 132);
    CharStats.setLevel(characterId, 99);
    CharacterItemUtils.addNewItem(characterId, 267, 1);
    vm.stopPrank();

    assertTrue(InventoryEquipmentUtils.hasEquipment(characterId, 2));
    uint256 itemId = Equipment.getItemId(2);
    assertEq(itemId, 267);

    _giveResources(1); // give resources for reborn

    CharCurrentStatsData memory prevCharCurrentStats = CharCurrentStats.get(characterId);
    console2.log("prev atk", prevCharCurrentStats.atk);
    console2.log("prev def", prevCharCurrentStats.def);
    console2.log("prev agi", prevCharCurrentStats.agi);

    EquipData[] memory equipDatas = new EquipData[](2);
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });
    equipDatas[1] = EquipData({ slotType: SlotType.Mount, equipmentId: 2 });

    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    assertEq(CharEquipment.getEquipmentId(characterId, SlotType.Weapon), 1);
    assertEq(CharEquipment.getEquipmentId(characterId, SlotType.Mount), 2);
    assertEq(CharEquipStats.getMs(characterId, SlotType.Mount), 1);

    vm.startPrank(player);
    world.app__reborn(characterId);
    vm.stopPrank();

    CharStatsData memory charStats = CharStats.get(characterId);
    CharCurrentStatsData memory charCurrentStats = CharCurrentStats.get(characterId);
    assertEq(charStats.weight, 200);
    assertEq(charCurrentStats.ms, 1);
  }

  function _giveResources(uint16 rebornNum) private {
    (uint256[] memory itemIds, uint32[] memory amounts) = _requiredResources(rebornNum);
    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItems(characterId, itemIds, amounts);
    vm.stopPrank();
  }

  function _requiredResources(uint16 rebornNum)
    private
    pure
    returns (uint256[] memory itemIds, uint32[] memory amounts)
  {
    uint256 len = 4;
    itemIds = new uint256[](len);
    itemIds[0] = 258;
    itemIds[1] = 259;
    itemIds[2] = 260;
    itemIds[3] = 261;
    amounts = new uint32[](len);
    for (uint256 i = 0; i < len; i++) {
      amounts[i] = rebornNum;
    }
    return (itemIds, amounts);
  }

  function _getCharacterOriginalStats(uint256 characterId) private view returns (uint16 atk, uint16 def, uint16 agi) {
    uint16[3] memory traits = CharInfo.getTraits(characterId);
    atk = 1 + traits[0];
    def = 1 + traits[1];
    agi = 1 + traits[2];
    return (atk, def, agi);
  }
}
