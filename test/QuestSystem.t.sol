pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, FarmingSystemFixture } from "./fixtures/index.sol";
import {
  QuestV4,
  QuestV4Data,
  QuestContribute,
  QuestContributeData,
  QuestLocate,
  QuestLocateData,
  Npc,
  NpcData,
  CharPosition,
  CharPositionData,
  CharOtherItem,
  CharCurrentStats,
  CharFund,
  QuestLocateTracking2,
  CharAchievementIndex
} from "@codegen/index.sol";
import { CharQuestStatus } from "@codegen/index.sol";
import { QuestType, QuestStatusType, SocialType } from "@codegen/common.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { CharAchievementUtils } from "@utils/CharAchievementUtils.sol";

contract QuestSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, FarmingSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  uint256 woodTier1 = 1;
  uint256 toolWoodAxe = 1;

  int32 npc1X = 30;
  int32 npc1Y = -36;

  int32 npc2X = -28;
  int32 npc2Y = -31;

  function setUp()
    public
    virtual
    override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, FarmingSystemFixture)
  {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_FinishSocialQuest() external {
    vm.startPrank(player);
    world.app__finishSocialQuest(characterId, SocialType.Twitter);
    vm.stopPrank();

    assertEq(CharFund.getGold(characterId), 10);

    vm.startPrank(player);
    world.app__finishSocialQuest(characterId, SocialType.Telegram);
    vm.stopPrank();

    assertEq(CharFund.getGold(characterId), 20);

    vm.startPrank(player);
    world.app__finishSocialQuest(characterId, SocialType.Discord);
    vm.stopPrank();

    assertEq(CharFund.getGold(characterId), 30);

    vm.expectRevert();
    vm.startPrank(player);
    world.app__finishSocialQuest(characterId, SocialType.Discord);
    vm.stopPrank();

    vm.expectRevert();
    vm.startPrank(player);
    world.app__finishSocialQuest(characterId, SocialType.Telegram);
    vm.stopPrank();

    vm.expectRevert();
    vm.startPrank(player);
    world.app__finishSocialQuest(characterId, SocialType.Twitter);
    vm.stopPrank();
  }

  function test_ShouldReceiveAndFinishQuestByFarming() external {
    // set position same as npc 1
    console2.log("received quest -2");
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, npc1X, npc1Y);
    vm.stopPrank();
    console2.log("received quest -1");
    // after state
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    assertEq(characterPosition.x, npc1X);
    assertEq(characterPosition.y, npc1Y);

    console2.log("received quest 0");

    // receive quest
    vm.startPrank(player);
    world.app__receiveQuest(characterId, 1, 1);
    vm.stopPrank();

    assertEq(true, CharQuestStatus.get(characterId, 1) == QuestStatusType.InProgress);

    console2.log("received quest");

    // farm to get resource
    _doFarmingToGetResource(player, characterId, woodTier1, toolWoodAxe, 20);

    console2.log("received quest 1");

    // set position same as npc 1
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, npc1X, npc1Y);
    vm.stopPrank();

    console2.log("received quest 2");

    console2.log("current weight", CharCurrentStats.getWeight(characterId));

    vm.startPrank(player);
    world.app__finishQuest(characterId, 1, 1);
    vm.stopPrank();
    console2.log("current weight", CharCurrentStats.getWeight(characterId));
    console2.log("received quest 3");
    assertEq(true, CharQuestStatus.get(characterId, 1) == QuestStatusType.Done);
    assertTrue(CharAchievementUtils.hasAchievement(characterId, 5));
    console2.log("received quest 4");
  }

  function test_ShouldReceiveAndFinishQuestByLocating() external {
    uint256 locateQuestId = 9;
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
    world.app__receiveQuest(characterId, 1, locateQuestId);
    vm.stopPrank();

    assertTrue(CharQuestStatus.get(characterId, locateQuestId) == QuestStatusType.InProgress);

    // [{"x":30,"y":-37},{"x":31,"y":-37}]
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, 30, -37);
    vm.stopPrank();
    // try to finish
    vm.startPrank(player);
    world.app__finishQuest(characterId, 1, locateQuestId);
    vm.stopPrank();

    uint8 index = QuestLocateTracking2.get(characterId, locateQuestId);
    assertEq(index, 1);
    assertTrue(CharQuestStatus.get(characterId, locateQuestId) == QuestStatusType.InProgress);

    // move to last point
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, 31, -37);
    vm.stopPrank();
    // try to finish
    vm.startPrank(player);
    world.app__finishQuest(characterId, 1, locateQuestId);
    vm.stopPrank();
    index = QuestLocateTracking2.get(characterId, locateQuestId);
    assertEq(index, 2);
    assertTrue(CharQuestStatus.get(characterId, locateQuestId) == QuestStatusType.InProgress);

    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, npc1X, npc1Y);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__finishQuest(characterId, 1, locateQuestId);
    vm.stopPrank();
    assertEq(index, 2);
    assertTrue(CharQuestStatus.get(characterId, locateQuestId) == QuestStatusType.Done);
  }

  function test_ShouldHaveData() external {
    NpcData memory npc = Npc.get(2);
    assertEq(npc.cityId, 2);
    assertEq(npc.x, npc2X);
    assertEq(npc.y, npc2Y);

    QuestV4Data memory quest = QuestV4.get(1);
    assertEq(quest.exp, 14);
    assertEq(quest.gold, 5);
    assertEq(quest.fromNpcId, 1);
    assertEq(quest.toNpcId, 1);
    assertEq(quest.requiredDoneQuestIds.length, 0);

    quest = QuestV4.get(4);
    assertEq(quest.exp, 56);
    assertEq(quest.fromNpcId, 1);
    assertEq(quest.toNpcId, 1);
    assertEq(quest.requiredDoneQuestIds.length, 3);

    QuestContributeData memory questContribute = QuestContribute.get(1);
    assertEq(questContribute.itemIds.length, 1);
    assertEq(questContribute.amounts.length, 1);

    questContribute = QuestContribute.get(4);
    assertEq(questContribute.itemIds.length, 3);
    assertEq(questContribute.amounts.length, 3);

    quest = QuestV4.get(9);
    assertEq(quest.gold, 5);
    QuestLocateData memory questLocate = QuestLocate.get(9);
    assertEq(questLocate.xs.length, 2);
    assertEq(questLocate.ys.length, 2);
    assertEq(questLocate.xs[1], 31);

    quest = QuestV4.get(10);
    assertEq(quest.fromNpcId, 1);
    assertEq(quest.rewardItemIds.length, 2);
    assertEq(quest.rewardItemAmounts.length, 2);
    assertEq(quest.rewardItemIds[0], 30);
    assertEq(quest.rewardItemIds[1], 1);
    assertEq(quest.rewardItemAmounts[0], 1);
    assertEq(quest.rewardItemAmounts[1], 100);
    assertEq(quest.requiredAchievementIds.length, 2);
    assertEq(quest.requiredAchievementIds[0], 5);
    assertEq(quest.requiredAchievementIds[1], 6);
  }

  function test_ShouldReceiveAndFinishQuest() external {
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

    // set position same as npc 1
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, npc1X, npc1Y);
    vm.stopPrank();

    // try finish quest - expect revert => not enough resource
    vm.expectRevert();
    vm.startPrank(player);
    world.app__finishQuest(characterId, 1, 1);
    vm.stopPrank();

    // try finish quest - expect success
    vm.startPrank(worldDeployer);
    // add resource to inventory
    InventoryItemUtils.addItem(characterId, 1, 20);
    vm.stopPrank();

    console2.log("current weight", CharCurrentStats.getWeight(characterId));

    vm.startPrank(player);
    world.app__finishQuest(characterId, 1, 1);
    vm.stopPrank();

    console2.log("current weight", CharCurrentStats.getWeight(characterId));

    assertEq(true, CharQuestStatus.get(characterId, 1) == QuestStatusType.Done);
  }

  function test_ShouldRevertReceiveQuestInWrongPosition() external {
    // set position != npc 1 position
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, -6, -3);
    vm.stopPrank();
    // after state
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    assertEq(characterPosition.x, -6);
    assertEq(characterPosition.y, -3);

    // receive quest
    vm.expectRevert();
    vm.startPrank(player);
    world.app__receiveQuest(characterId, 1, 1);
    vm.stopPrank();
  }

  function test_ShouldRevertFinishQuestInWrongPosition() external {
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

    // set character position to another place
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, -5, -3);
    vm.stopPrank();
    // after state
    characterPosition = CharacterPositionUtils.currentPosition(characterId);
    assertEq(characterPosition.x, -5);

    // try finish quest - expect revert => position is not same as npc position
    vm.expectRevert();
    vm.startPrank(player);
    world.app__finishQuest(characterId, 1, 1);
    vm.stopPrank();
  }

  function test_ReceiveQuestWithRequirement() external {
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

    // set position same as npc 2
    // vm.startPrank(worldDeployer);
    // CharacterPositionUtils.moveToLocation(characterId, -51, -25);
    // vm.stopPrank();

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
  }

  function test_ReceiveItemResource() external {
    // set position same as npc 1
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, npc1X, npc1Y);
    CharAchievementIndex.set(characterId, 5, 10);
    CharAchievementIndex.set(characterId, 6, 11);
    vm.stopPrank();
    // after state
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    assertEq(characterPosition.x, npc1X);
    assertEq(characterPosition.y, npc1Y);

    // receive quest
    vm.startPrank(player);
    world.app__receiveQuest(characterId, 1, 10);
    vm.stopPrank();

    assertEq(true, CharQuestStatus.get(characterId, 10) == QuestStatusType.InProgress);

    // set position same as npc 1
    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, 1, 50);
    vm.stopPrank();

    uint32 prevWeight = CharCurrentStats.getWeight(characterId);
    console2.log("prevWeight", prevWeight);

    vm.startPrank(player);
    world.app__finishQuest(characterId, 1, 10);
    vm.stopPrank();
    assertEq(true, CharQuestStatus.get(characterId, 10) == QuestStatusType.Done);

    uint32 currentWeight = CharCurrentStats.getWeight(characterId);
    console2.log("currentWeight", currentWeight);
    assertEq(prevWeight + 104 - 50, currentWeight);
    // check if item is received
    assertEq(CharOtherItem.getAmount(characterId, 1), 100);
  }
}
