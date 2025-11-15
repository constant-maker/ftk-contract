pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import {
  WorldFixture,
  SpawnSystemFixture,
  WelcomeSystemFixture,
  FarmingSystemFixture,
  MoveSystemFixture
} from "./fixtures/index.sol";
import {
  CharDailyQuest,
  CharDailyQuestData,
  CharFund,
  CharCurrentStats,
  DailyQuestConfig,
  DailyQuestConfigData
} from "@codegen/index.sol";
import { DailyQuestUtils } from "@utils/DailyQuestUtils.sol";

contract DailyQuestSystemTest is
  WorldFixture,
  SpawnSystemFixture,
  WelcomeSystemFixture,
  FarmingSystemFixture,
  MoveSystemFixture
{
  address player = makeAddr("player");
  address player_2 = makeAddr("player2");
  uint256 characterId;
  uint256 characterId_2;

  uint256 woodTier1 = 1;
  uint256 toolWoodAxe = 1;
  uint256 equipmentRustySword = 1;

  function setUp()
    public
    virtual
    override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, FarmingSystemFixture, MoveSystemFixture)
  {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
    characterId_2 = _createCharacterWithName(player_2, "character2");
    _claimWelcomePackages(player_2, characterId_2);
  }

  function test_RefreshAndFinishDaily() external {
    DailyQuestConfigData memory dailyQuestConfig = DailyQuestConfig.get();
    assertEq(dailyQuestConfig.moveNum, 2);
    assertEq(dailyQuestConfig.farmNum, 3);
    assertEq(dailyQuestConfig.pvpNum, 1);
    assertEq(dailyQuestConfig.pveNum, 3);
    assertEq(dailyQuestConfig.rewardExp, 5);
    assertEq(dailyQuestConfig.rewardGold, 10);
    _doFarmingToGetResource(player, characterId, woodTier1, toolWoodAxe, 1);

    CharDailyQuestData memory characterDailyQuest = CharDailyQuest.get(characterId);
    assertEq(characterDailyQuest.farmCount, 0); // the quest is not refresh yet

    vm.startPrank(player);
    world.app__refreshQuest(characterId);
    vm.stopPrank();

    uint256 startTime = CharDailyQuest.getStartTime(characterId);

    // farming
    console2.log("farming");
    _doFarmingToGetResource(player, characterId, woodTier1, toolWoodAxe, 5);
    uint8 farmCount = CharDailyQuest.getFarmCount(characterId);
    assertEq(farmCount, 3);

    // moving
    console2.log("moving");
    for (uint256 i = 0; i < 10; i++) {
      _goUp(player, characterId);
    }
    uint8 moveCount = CharDailyQuest.getMoveCount(characterId);
    assertEq(moveCount, 2);

    // pve
    console2.log("pve");
    for (uint256 i = 0; i < 10; i++) {
      _moveToMonsterLocation(characterId);
      vm.warp(block.timestamp + 300);
      vm.startPrank(player);
      world.app__battlePvE(characterId, 1, true);
      vm.stopPrank();
    }
    uint8 pveCount = CharDailyQuest.getPveCount(characterId);
    assertEq(pveCount, 3);
    // pvp
    console2.log("pvp");
    for (uint256 i = 0; i < 10; i++) {
      _moveToMonsterLocation(characterId);
      _moveToMonsterLocation(characterId_2);
      vm.warp(block.timestamp + 300);
      vm.startPrank(player);
      world.app__challengePvP(characterId, characterId_2);
      vm.stopPrank();
    }
    uint8 pvpCount = CharDailyQuest.getPvpCount(characterId);
    assertEq(pvpCount, 1);

    uint32 oldExp = CharCurrentStats.getExp(characterId);

    // finish quest successully
    vm.startPrank(player);
    world.app__finishQuest(characterId);
    vm.stopPrank();

    // check reward
    uint32 currentExp = CharCurrentStats.getExp(characterId);
    assertEq(oldExp + 5, currentExp);
    uint32 goldAmount = CharFund.getGold(characterId);
    assertEq(goldAmount, 10);

    characterDailyQuest = CharDailyQuest.get(characterId);
    assertEq(startTime + DailyQuestUtils.ONE_DAY_SECONDS, characterDailyQuest.startTime);
    assertEq(characterDailyQuest.moveCount, 0);
    assertEq(characterDailyQuest.farmCount, 0);
    assertEq(characterDailyQuest.pvpCount, 0);
    assertEq(characterDailyQuest.pveCount, 0);
    assertEq(characterDailyQuest.streak, 1);

    console2.log("last startTime", characterDailyQuest.startTime);

    // try to move again => expect moveCount is zero
    for (uint256 i = 0; i < 10; i++) {
      _goUp(player, characterId);
    }
    moveCount = CharDailyQuest.getMoveCount(characterId);
    assertEq(moveCount, 0);

    vm.expectRevert();
    vm.startPrank(player);
    world.app__finishQuest(characterId);
    vm.stopPrank();

    // try to refresh quest
    vm.expectRevert();
    vm.startPrank(player);
    world.app__refreshQuest(characterId);
    vm.stopPrank();

    vm.warp(block.timestamp + 2 days);
    console2.log("current time", block.timestamp);
    vm.startPrank(player);
    world.app__refreshQuest(characterId);
    vm.stopPrank();
  }

  function test_RevertFinishQuestTooLate() external {
    DailyQuestConfigData memory dailyQuestConfig = DailyQuestConfig.get();
    assertEq(dailyQuestConfig.moveNum, 2);
    assertEq(dailyQuestConfig.farmNum, 3);
    assertEq(dailyQuestConfig.pvpNum, 1);
    assertEq(dailyQuestConfig.pveNum, 3);
    assertEq(dailyQuestConfig.rewardExp, 5);
    assertEq(dailyQuestConfig.rewardGold, 10);
    _doFarmingToGetResource(player, characterId, woodTier1, toolWoodAxe, 1);

    CharDailyQuestData memory characterDailyQuest = CharDailyQuest.get(characterId);
    assertEq(characterDailyQuest.farmCount, 0); // the quest is not refresh yet

    vm.startPrank(player);
    world.app__refreshQuest(characterId);
    vm.stopPrank();

    uint256 startTime = CharDailyQuest.getStartTime(characterId);

    // farming
    console2.log("farming");
    _doFarmingToGetResource(player, characterId, woodTier1, toolWoodAxe, 5);
    uint8 farmCount = CharDailyQuest.getFarmCount(characterId);
    assertEq(farmCount, 3);

    // moving
    console2.log("moving");
    for (uint256 i = 0; i < 10; i++) {
      _goUp(player, characterId);
    }
    uint8 moveCount = CharDailyQuest.getMoveCount(characterId);
    assertEq(moveCount, 2);

    // pve
    console2.log("pve");
    for (uint256 i = 0; i < 10; i++) {
      _moveToMonsterLocation(characterId);
      vm.warp(block.timestamp + 300);
      vm.startPrank(player);
      world.app__battlePvE(characterId, 1, true);
      vm.stopPrank();
    }
    uint8 pveCount = CharDailyQuest.getPveCount(characterId);
    assertEq(pveCount, 3);
    // pvp
    console2.log("pvp");
    for (uint256 i = 0; i < 10; i++) {
      _moveToMonsterLocation(characterId);
      _moveToMonsterLocation(characterId_2);
      vm.warp(block.timestamp + 300);
      vm.startPrank(player);
      world.app__challengePvP(characterId, characterId_2);
      vm.stopPrank();
    }
    uint8 pvpCount = CharDailyQuest.getPvpCount(characterId);
    assertEq(pvpCount, 1);

    vm.warp(block.timestamp + DailyQuestUtils.ONE_DAY_SECONDS);

    vm.expectRevert();
    vm.startPrank(player);
    world.app__finishQuest(characterId);
    vm.stopPrank();
  }

  function test_RevertTasksAreNotDone() external {
    vm.startPrank(player);
    world.app__refreshQuest(characterId);
    vm.stopPrank();

    uint256 startTime = CharDailyQuest.getStartTime(characterId);

    // farming
    console2.log("farming");
    _doFarmingToGetResource(player, characterId, woodTier1, toolWoodAxe, 5);
    uint8 farmCount = CharDailyQuest.getFarmCount(characterId);
    assertEq(farmCount, 3);

    // moving
    console2.log("moving");
    for (uint256 i = 0; i < 1; i++) {
      _goUp(player, characterId);
    }
    uint8 moveCount = CharDailyQuest.getMoveCount(characterId);
    assertEq(moveCount, 1);

    // pve
    console2.log("pve");
    for (uint256 i = 0; i < 10; i++) {
      _moveToMonsterLocation(characterId);
      vm.warp(block.timestamp + 300);
      vm.startPrank(player);
      world.app__battlePvE(characterId, 1, true);
      vm.stopPrank();
    }
    uint8 pveCount = CharDailyQuest.getPveCount(characterId);
    assertEq(pveCount, 3);
    // pvp
    console2.log("pvp");
    for (uint256 i = 0; i < 10; i++) {
      _moveToMonsterLocation(characterId);
      _moveToMonsterLocation(characterId_2);
      vm.warp(block.timestamp + 300);
      vm.startPrank(player);
      world.app__challengePvP(characterId, characterId_2);
      vm.stopPrank();
    }
    uint8 pvpCount = CharDailyQuest.getPvpCount(characterId);
    assertEq(pvpCount, 1);

    vm.expectRevert();
    vm.startPrank(player);
    world.app__finishQuest(characterId);
    vm.stopPrank();
  }

  function test_CounterShouldNotIncreaseWhenOutOfTime() external {
    vm.startPrank(player);
    world.app__refreshQuest(characterId);
    vm.stopPrank();

    // farming
    console2.log("farming");
    _doFarmingToGetResource(player, characterId, woodTier1, toolWoodAxe, 1);
    uint8 farmCount = CharDailyQuest.getFarmCount(characterId);
    assertEq(farmCount, 1);

    vm.warp(block.timestamp + 2 days);
    _doFarmingToGetResource(player, characterId, woodTier1, toolWoodAxe, 5);
    farmCount = CharDailyQuest.getFarmCount(characterId);
    assertEq(farmCount, 1);
  }

  function test_CounterShouldWorkAfterNewStartTime() external {
    CharDailyQuestData memory characterDailyQuest = CharDailyQuest.get(characterId);
    assertEq(characterDailyQuest.farmCount, 0); // the quest is not refresh yet

    vm.startPrank(player);
    world.app__refreshQuest(characterId);
    vm.stopPrank();

    uint256 startTime = CharDailyQuest.getStartTime(characterId);

    // farming
    console2.log("farming");
    _doFarmingToGetResource(player, characterId, woodTier1, toolWoodAxe, 5);
    uint8 farmCount = CharDailyQuest.getFarmCount(characterId);
    assertEq(farmCount, 3);

    // moving
    console2.log("moving");
    for (uint256 i = 0; i < 10; i++) {
      _goUp(player, characterId);
    }
    uint8 moveCount = CharDailyQuest.getMoveCount(characterId);
    assertEq(moveCount, 2);

    // pve
    console2.log("pve");
    for (uint256 i = 0; i < 10; i++) {
      _moveToMonsterLocation(characterId);
      vm.warp(block.timestamp + 300);
      vm.startPrank(player);
      world.app__battlePvE(characterId, 1, true);
      vm.stopPrank();
    }
    uint8 pveCount = CharDailyQuest.getPveCount(characterId);
    assertEq(pveCount, 3);
    // pvp
    console2.log("pvp");
    for (uint256 i = 0; i < 10; i++) {
      _moveToMonsterLocation(characterId);
      _moveToMonsterLocation(characterId_2);
      vm.warp(block.timestamp + 300);
      vm.startPrank(player);
      world.app__challengePvP(characterId, characterId_2);
      vm.stopPrank();
    }
    uint8 pvpCount = CharDailyQuest.getPvpCount(characterId);
    assertEq(pvpCount, 1);

    // finish quest successully
    vm.startPrank(player);
    world.app__finishQuest(characterId);
    vm.stopPrank();

    moveCount = CharDailyQuest.getMoveCount(characterId);
    assertEq(moveCount, 0);
    vm.warp(block.timestamp + DailyQuestUtils.ONE_DAY_SECONDS); // valid to do new quest
    // moving
    console2.log("moving");
    for (uint256 i = 0; i < 10; i++) {
      _goUp(player, characterId);
    }
    moveCount = CharDailyQuest.getMoveCount(characterId);
    assertEq(moveCount, 2);
  }
}
