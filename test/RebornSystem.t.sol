pragma solidity >=0.8.24;

import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";
import { console2 } from "forge-std/console2.sol";
import { CharStats, CharStatsData } from "@codegen/tables/CharStats.sol";
import { CharCurrentStats, CharCurrentStatsData } from "@codegen/tables/CharCurrentStats.sol";
import { CharBaseStats, CharBaseStatsData } from "@codegen/tables/CharBaseStats.sol";
import { CharReborn } from "@codegen/index.sol";
import { EquipData } from "@systems/app/EquipmentSystem.sol";
import { SlotType } from "@codegen/common.sol";
import { Config } from "@common/Config.sol";
import { CharAchievementUtils } from "@utils/CharAchievementUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";

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
    assertEq(charCurrentStats.agi + 1, prevCharCurrentStats.agi + 3);
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

    EquipData memory equipData = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });
    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = equipData;
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    CharCurrentStatsData memory prevCharCurrentStats = CharCurrentStats.get(characterId);
    console2.log("prev atk", prevCharCurrentStats.atk);

    vm.startPrank(worldDeployer);
    CharStats.setLevel(characterId, 99);
    CharBaseStats.setAtk(characterId, 10);
    CharBaseStats.setAgi(characterId, 1);
    CharCurrentStats.setAtk(characterId, prevCharCurrentStats.atk + 5); // smaller than actual 5 unit
    vm.stopPrank();

    console2.log("setup atk", CharCurrentStats.getAtk(characterId));

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
    console2.log(" atk", charCurrentStats.atk); // should be 9 (6 + 3 (achievement bonus))
    assertEq(charCurrentStats.atk, 9);
    assertEq(charCurrentStats.def, prevCharCurrentStats.def + 3);
    assertEq(charCurrentStats.agi + 1, prevCharCurrentStats.agi + 3);
    assertEq(charCurrentStats.hp, Config.DEFAULT_HP);
    assertEq(1, CharReborn.get(characterId));
    assertTrue(CharAchievementUtils.hasAchievement(characterId, 9));
  }

  function _requiredResources(uint16 rebornNum)
    private
    pure
    returns (uint256[] memory itemIds, uint32[] memory amounts)
  {
    itemIds = new uint256[](3);
    itemIds[0] = 67;
    itemIds[1] = 68;
    itemIds[2] = 69;
    amounts = new uint32[](3);
    amounts[0] = rebornNum;
    amounts[1] = rebornNum;
    amounts[2] = rebornNum;
    return (itemIds, amounts);
  }
}
