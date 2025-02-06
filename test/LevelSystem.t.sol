pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture } from "./fixtures/index.sol";
import {
  Quest2,
  Quest2Data,
  QuestContribute,
  QuestContributeData,
  Npc,
  NpcData,
  CharPosition,
  CharPositionData,
  CharStats,
  CharStatsData,
  CharCurrentStats,
  CharCurrentStatsData,
  CharBaseStats,
  CharBaseStatsData,
  CharPerk,
  CharPerkData
} from "@codegen/index.sol";
import { CharQuestStatus } from "@codegen/index.sol";
import { QuestType, QuestStatusType, StatType, ItemType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { Config } from "@common/Config.sol";
import { IncreaseStatData } from "@systems/app/LevelSystem.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";

contract LevelSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  int32 npc1X = 30;
  int32 npc1Y = -36;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);

    assertEq(CharStats.getLevel(characterId), 1);
    assertEq(CharCurrentStats.getExp(characterId), 0);
  }

  function test_ShouldGainExp() external {
    _finishQuest_1();
    assertEq(CharCurrentStats.getExp(characterId), 14);
    _finishQuest_4();
    assertEq(CharCurrentStats.getExp(characterId), 70);
  }

  function test_ShouldLevelUpSuccess() external {
    vm.startPrank(worldDeployer);
    CharCurrentStats.setExp(characterId, 132);
    vm.stopPrank();

    vm.startPrank(player);
    // level up 3 levels
    world.app__levelUp(characterId, 3);
    vm.stopPrank();

    assertEq(CharStats.getHp(characterId), 160);
    assertEq(CharStats.getLevel(characterId), 4);
    assertEq(CharStats.getStatPoint(characterId), 3);
    assertEq(CharCurrentStats.getExp(characterId), 6);
    assertEq(CharCurrentStats.getHp(characterId), 160);

    vm.prank(worldDeployer);
    CharCurrentStats.setExp(characterId, 425_686);

    vm.startPrank(player);
    // level up to level 30
    world.app__levelUp(characterId, 29);
    vm.stopPrank();

    assertEq(CharStats.getLevel(characterId), 33);
    assertEq(CharStats.getStatPoint(characterId), 40);

    vm.startPrank(player);
    // level up to level 53
    world.app__levelUp(characterId, 20);
    vm.stopPrank();

    assertEq(CharStats.getLevel(characterId), 53);
    assertEq(CharStats.getStatPoint(characterId), 83);
  }

  function test_ShouldIncreaseStatsSuccess() external {
    vm.startPrank(worldDeployer);
    CharCurrentStats.setExp(characterId, 343);
    vm.stopPrank();
    assertEq(CharCurrentStats.getExp(characterId), 343);

    CharCurrentStatsData memory beforeCurrentStats = CharCurrentStats.get(characterId);

    vm.startPrank(player);
    // level up 5 levels => level 6
    world.app__levelUp(characterId, 5);
    vm.stopPrank();

    assertEq(CharStats.getLevel(characterId), 6);
    assertEq(CharStats.getStatPoint(characterId), 5);
    assertEq(CharCurrentStats.getExp(characterId), 0);

    CharCurrentStatsData memory currentStats = CharCurrentStats.get(characterId);
    // all stats +1 at level 5
    assertEq(currentStats.atk, beforeCurrentStats.atk + 1);
    assertEq(currentStats.def, beforeCurrentStats.atk + 1);
    assertEq(currentStats.agi, beforeCurrentStats.agi + 1);

    console2.log("test increaseStats");

    beforeCurrentStats = CharCurrentStats.get(characterId);
    IncreaseStatData[] memory datas = new IncreaseStatData[](4);
    datas[0] = IncreaseStatData({ statType: StatType.ATK, amount: 1 });
    datas[1] = IncreaseStatData({ statType: StatType.ATK, amount: 1 });
    datas[2] = IncreaseStatData({ statType: StatType.DEF, amount: 1 });
    datas[3] = IncreaseStatData({ statType: StatType.AGI, amount: 1 });
    vm.startPrank(player);
    // add 2 point to attack, 1 to def and 1 to agi
    world.app__increaseStats(characterId, datas);
    vm.stopPrank();

    currentStats = CharCurrentStats.get(characterId);
    assertEq(currentStats.atk, beforeCurrentStats.atk + 2);
    assertEq(currentStats.def, beforeCurrentStats.atk + 1);
    assertEq(currentStats.agi, beforeCurrentStats.agi + 1);
    assertEq(CharStats.getStatPoint(characterId), 1);
  }

  function test_ShouldIncreaseBigStatsSuccess() external {
    vm.startPrank(worldDeployer);
    CharCurrentStats.setExp(characterId, 407_316);
    vm.stopPrank();
    assertEq(CharCurrentStats.getExp(characterId), 407_316);

    CharCurrentStatsData memory beforeCurrentStats = CharCurrentStats.get(characterId);

    vm.startPrank(player);
    // level up to level 53
    world.app__levelUp(characterId, 52);
    vm.stopPrank();

    assertEq(CharStats.getLevel(characterId), 53);
    assertEq(CharStats.getStatPoint(characterId), 83);

    CharCurrentStatsData memory currentStats = CharCurrentStats.get(characterId);
    // all stats +1 at level multiple of 5
    assertEq(currentStats.atk, beforeCurrentStats.atk + 10);
    assertEq(currentStats.def, beforeCurrentStats.atk + 10);
    assertEq(currentStats.agi, beforeCurrentStats.agi + 10);

    CharBaseStatsData memory baseStats = CharBaseStats.get(characterId);
    assertEq(currentStats.atk, baseStats.atk + 2);
    assertEq(currentStats.def, baseStats.def + 2);
    assertEq(currentStats.agi, baseStats.agi + 4);

    console2.log("test increaseStats");
    console2.log("current atk", currentStats.atk);
    console2.log("current def", currentStats.def);

    IncreaseStatData[] memory datas = new IncreaseStatData[](2);
    datas[0] = IncreaseStatData({ statType: StatType.ATK, amount: 40 });
    datas[1] = IncreaseStatData({ statType: StatType.DEF, amount: 13 });
    vm.startPrank(player);
    // add 40 point to attack; from 12 -> 52 cost 68 points
    // add 13 point to attack; from 12 -> 25 cost 13 points
    world.app__increaseStats(characterId, datas);
    vm.stopPrank();

    currentStats = CharCurrentStats.get(characterId);
    baseStats = CharBaseStats.get(characterId);
    assertEq(currentStats.atk, 52);
    assertEq(currentStats.def, 25);
    assertEq(currentStats.atk, baseStats.atk + 2);
    assertEq(currentStats.def, baseStats.def + 2);
    assertEq(CharStats.getStatPoint(characterId), 5);
  }

  function test_ShouldLevelUpFrom5To6Success() external {
    vm.startPrank(worldDeployer);
    CharStats.setLevel(characterId, 5);
    CharCurrentStats.setExp(characterId, 125);
    vm.stopPrank();
    assertEq(CharCurrentStats.getExp(characterId), 125);
    assertEq(CharStats.getLevel(characterId), 5);

    vm.startPrank(player);
    // level up level 5 => level 6
    bytes memory data = abi.encodeWithSignature("app__levelUp(uint256,uint16)", characterId, 1);
    (bool success,) = address(world).call(data);
    // world.app__levelUp(characterId, 1);
    vm.stopPrank();

    assertEq(CharCurrentStats.getExp(characterId), 0);
  }

  function test_ShouldRevertExceedMaxLevel() external {
    bytes memory encodedError =
      abi.encodeWithSelector(Errors.LevelSystem_ExceedMaxLevel.selector, Config.MAX_LEVEL, 1001);
    vm.expectRevert(encodedError);
    vm.startPrank(player);
    // level up to level 1001
    world.app__levelUp(characterId, 1000);
    vm.stopPrank();
  }

  // function test_ShouldRevertExceedMaxBaseStat() external {
  //   bytes memory encodedError =
  //     abi.encodeWithSelector(Errors.Stats_ExceedMaxBaseStat.selector, StatType.ATK, Config.MAX_BASE_STAT, 133);
  //   IncreaseStatData[] memory datas = new IncreaseStatData[](1);
  //   datas[0] = IncreaseStatData({ statType: StatType.ATK, amount: 131 });
  //   vm.expectRevert(encodedError);
  //   vm.startPrank(player);
  //   world.app__increaseStats(characterId, datas);
  //   vm.stopPrank();
  // }

  function test_ShouldRevertNotEnoughExp() external {
    vm.expectRevert();
    vm.startPrank(player);
    // level up to level 2
    world.app__levelUp(characterId, 1);
    vm.stopPrank();
  }

  function test_ShouldRevertNotEnoughStatPoint() external {
    IncreaseStatData[] memory datas = new IncreaseStatData[](1);
    datas[0] = IncreaseStatData({ statType: StatType.ATK, amount: 1 });
    vm.expectRevert();
    vm.startPrank(player);
    world.app__increaseStats(characterId, datas);
    vm.stopPrank();
  }

  // TEST PERK
  function test_LevelUpPerkSuccess() external {
    ItemType swordType = ItemType.Sword;
    uint8 amount = 2; // from 1 => 3
    vm.startPrank(worldDeployer);
    CharPerk.setExp(characterId, swordType, 6750);
    vm.stopPrank();
    vm.startPrank(player);
    world.app__levelUpPerk(characterId, swordType, amount);
    vm.stopPrank();
    console2.log("done perk to level 3");
    CharPerkData memory characterPerk = CharPerk.get(characterId, swordType);
    assertEq(characterPerk.level, 2);
    assertEq(characterPerk.exp, 0);

    // try to level 5
    vm.startPrank(worldDeployer);
    CharPerk.setExp(characterId, swordType, 68_250);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__levelUpPerk(characterId, swordType, 2);
    vm.stopPrank();
    console2.log("done perk to level 5");
    characterPerk = CharPerk.get(characterId, swordType);
    assertEq(characterPerk.level, 4); // perk level start from zero
    assertEq(characterPerk.exp, 0);

    // try to level 10
    vm.startPrank(worldDeployer);
    CharPerk.setExp(characterId, swordType, 1_443_750);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__levelUpPerk(characterId, swordType, 5);
    vm.stopPrank();
    console2.log("done perk to level 10");
    characterPerk = CharPerk.get(characterId, swordType);
    assertEq(characterPerk.level, 9); // perk level start from zero
    assertEq(characterPerk.exp, 0);
  }

  // TEST PERK
  function test_RevertLevelUpPerkExceedMaxLevel() external {
    ItemType swordType = ItemType.Sword;
    uint8 amount = 10; // from 0 => 10 ~ MAX is 9
    vm.expectRevert();
    vm.startPrank(player);
    world.app__levelUpPerk(characterId, swordType, amount);
    vm.stopPrank();

    amount = 0; // invalid data
    vm.expectRevert();
    vm.startPrank(player);
    world.app__levelUpPerk(characterId, swordType, amount);
    vm.stopPrank();
  }

  function _finishQuest_1() private {
    // set position same as npc 1
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, npc1X, npc1Y);
    vm.stopPrank();
    // after state
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    assertEq(characterPosition.x, npc1X);
    assertEq(characterPosition.y, npc1Y);

    // receive quest
    vm.startPrank(player);
    world.app__receiveQuest(characterId, 1, 1);
    vm.stopPrank();

    assertEq(true, CharQuestStatus.get(characterId, 1) == QuestStatusType.InProgress);

    // try finish quest - expect success
    vm.startPrank(worldDeployer);
    // add resource to inventory
    InventoryItemUtils.addItem(characterId, 1, 20);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__finishQuest(characterId, 1, 1);
    vm.stopPrank();

    assertEq(true, CharQuestStatus.get(characterId, 1) == QuestStatusType.Done);
  }

  function _finishQuest_4() private {
    // set position same as npc 1
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, npc1X, npc1Y);
    vm.stopPrank();

    // add resource to inventory
    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, 1, 50);
    InventoryItemUtils.addItem(characterId, 10, 50);
    InventoryItemUtils.addItem(characterId, 12, 50);
    vm.stopPrank();

    // try to receive the second quest - expect revert => because the required done quest is not enough
    vm.expectRevert();
    vm.startPrank(player);
    world.app__receiveQuest(characterId, 1, 4);
    vm.stopPrank();

    // finish the first quest
    vm.startPrank(worldDeployer);
    CharQuestStatus.set(characterId, 1, QuestStatusType.Done);
    CharQuestStatus.set(characterId, 2, QuestStatusType.Done);
    CharQuestStatus.set(characterId, 3, QuestStatusType.Done);
    vm.stopPrank();

    // try to receive the second quest - expect success
    vm.startPrank(player);
    world.app__receiveQuest(characterId, 1, 4);
    vm.stopPrank();

    assertEq(true, CharQuestStatus.get(characterId, 4) == QuestStatusType.InProgress);

    // finish
    vm.startPrank(player);
    world.app__finishQuest(characterId, 1, 4);
    vm.stopPrank();

    assertEq(true, CharQuestStatus.get(characterId, 4) == QuestStatusType.Done);
  }
}
