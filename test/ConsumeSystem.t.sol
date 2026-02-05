pragma solidity >=0.8.24;

import {
  CharOtherItem,
  CharCurrentStats,
  CharStats,
  ItemV2,
  ItemV2Data,
  BuffItemInfoV3,
  BuffItemInfoV3Data,
  BuffExp,
  BuffExpData,
  BuffStatV4,
  BuffStatV4Data,
  BuffDmg,
  BuffDmgData,
  RestrictLocV2,
  CharPositionData
} from "@codegen/index.sol";
import { BuffType } from "@codegen/common.sol";
import { WorldFixture, SpawnSystemFixture } from "@fixtures/index.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { console2 } from "forge-std/console2.sol";
import { TargetItemData } from "@systems/app/ConsumeSystem.sol";

contract ConsumeSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  address player2 = makeAddr("player2");
  uint256 characterId;
  uint256 characterId2;

  uint256 berryId = 14;
  uint256 healPotionId = 66;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);

    _claimWelcomePackages(player, characterId);

    characterId2 = _createCharacterWithName(player2, "test2");

    _claimWelcomePackages(player2, characterId2);
  }

  function test_ConsumeBerriesSuccessfully() external {
    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, berryId, 1000);
    CharCurrentStats.setHp(characterId, 1);
    vm.stopPrank();
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);

    vm.startPrank(player);
    world.app__eatBerries(characterId, berryId, 10);
    vm.stopPrank();

    uint32 currentHp = CharCurrentStats.getHp(characterId);
    assertEq(currentHp, 11);
    uint32 currentBerryAmount = CharOtherItem.getAmount(characterId, berryId);
    assertEq(currentBerryAmount, 990);

    uint32 newCurrentWeight = CharCurrentStats.getWeight(characterId);
    assertEq(newCurrentWeight + 10, currentWeight);

    uint32 maxHp = CharStats.getHp(characterId);

    vm.startPrank(player);
    world.app__eatBerries(characterId, berryId, 990);
    vm.stopPrank();

    currentHp = CharCurrentStats.getHp(characterId);
    assertEq(currentHp, maxHp);
    currentBerryAmount = CharOtherItem.getAmount(characterId, berryId);
    assertEq(currentBerryAmount, 0);
    newCurrentWeight = CharCurrentStats.getWeight(characterId);
    assertEq(newCurrentWeight + 1000, currentWeight);
  }

  function test_ConsumePotionSuccessfully() external {
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);
    vm.startPrank(worldDeployer);
    CharCurrentStats.setHp(characterId, 1);
    vm.stopPrank();

    TargetItemData memory targetData;

    vm.startPrank(player);
    world.app__consumeItem(characterId, healPotionId, 1, targetData);
    vm.stopPrank();

    uint32 currentHp = CharCurrentStats.getHp(characterId);
    assertEq(currentHp, 51);
    uint32 currentPotionAmount = CharOtherItem.getAmount(characterId, healPotionId);
    assertEq(currentPotionAmount, 0);
    uint32 newCurrentWeight = CharCurrentStats.getWeight(characterId);
    assertEq(newCurrentWeight + 2, currentWeight);

    uint32 maxHp = CharStats.getHp(characterId);

    vm.startPrank(worldDeployer);
    CharCurrentStats.setHp(characterId, maxHp - 1);
    InventoryItemUtils.addItem(characterId, healPotionId, 1);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__consumeItem(characterId, healPotionId, 1, targetData);
    vm.stopPrank();

    currentHp = CharCurrentStats.getHp(characterId);
    assertEq(currentHp, maxHp);
    currentPotionAmount = CharOtherItem.getAmount(characterId, healPotionId);
    assertEq(currentPotionAmount, 0);
  }

  function test_RevertConsumeExceedBalance() external {
    vm.expectRevert();
    vm.startPrank(player);
    world.app__eatBerries(characterId, berryId, 10);
    vm.stopPrank();

    TargetItemData memory targetData;

    vm.expectRevert();
    vm.startPrank(player);
    world.app__consumeItem(characterId, healPotionId, 2, targetData);
    vm.stopPrank();
  }

  // test buff and skill item

  function test_ShouldHaveData() external {
    BuffItemInfoV3Data memory buffItemInfo = BuffItemInfoV3.get(360); // instant dmg buff

    assertEq(uint8(buffItemInfo.buffType), uint8(BuffType.InstantDamage));
    assertEq(buffItemInfo.range, 10);
    assertEq(buffItemInfo.numTarget, 10);
    assertFalse(buffItemInfo.selfCastOnly);

    BuffDmgData memory buffDmg = BuffDmg.get(360); // skill item
    assertEq(buffDmg.dmg, 200);
    assertTrue(buffDmg.isAbsDmg);

    buffItemInfo = BuffItemInfoV3.get(358); // exp buff
    assertEq(uint8(buffItemInfo.buffType), uint8(BuffType.ExpAmplify));
    assertEq(buffItemInfo.range, 0);
    assertEq(buffItemInfo.duration, 300);
    assertEq(buffItemInfo.selfCastOnly, true);

    BuffExpData memory buffExpData = BuffExp.get(358);
    assertEq(buffExpData.farmingPerkAmp, 120);

    BuffStatV4Data memory buffStatData = BuffStatV4.get(356); // stat buff
    assertEq(buffStatData.atkPercent, 50);
    assertEq(buffStatData.defPercent, -100);
    assertEq(buffStatData.agiPercent, 0);
    assertEq(buffStatData.ms, 5);
    assertEq(buffStatData.sp, 1);
  }

  function test_ActiveSkillItem() external {
    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(characterId);
    console2.log("char position x", charPosition.x);
    console2.log("char position y", charPosition.y);
    vm.startPrank(worldDeployer);
    RestrictLocV2.set(charPosition.x, charPosition.y, 1, true);
    InventoryItemUtils.addItem(characterId, 360, 2); // instant dmg item with abs dmg
    InventoryItemUtils.addItem(characterId, 359, 1); // instant dmg item with percentage dmg
    CharacterPositionUtils.moveToLocation(characterId2, charPosition.x, charPosition.y + 1);
    CharCurrentStats.setHp(characterId2, 150);
    CharCurrentStats.setAtk(characterId, 30);
    vm.stopPrank();

    uint256[] memory targetPlayers = new uint256[](1);
    targetPlayers[0] = characterId2;

    TargetItemData memory targetData;
    targetData.targetPlayers = targetPlayers;
    targetData.x = charPosition.x;
    targetData.y = charPosition.y;

    vm.warp(block.timestamp + 10);

    vm.expectRevert(); // amount must be 1
    vm.startPrank(player);
    world.app__consumeItem(characterId, 360, 2, targetData);
    vm.stopPrank();

    // vm.expectRevert(); // restrict location
    // vm.startPrank(player);
    // world.app__consumeItem(characterId, 360, 1, targetData);
    // vm.stopPrank();

    uint32 char2Hp = CharCurrentStats.getHp(characterId2);
    targetData.y = charPosition.y - 1;
    vm.startPrank(player);
    world.app__consumeItem(characterId, 360, 1, targetData);
    vm.stopPrank();
    assertEq(CharOtherItem.getAmount(characterId, 360), 1);
    assertEq(CharCurrentStats.getHp(characterId2), char2Hp); // char 2 is not in that position

    targetData.y = charPosition.y + 1;
    vm.expectRevert(); // cooldown
    vm.startPrank(player);
    world.app__consumeItem(characterId, 360, 1, targetData);
    vm.stopPrank();

    vm.warp(block.timestamp + 10); // wait for cooldown

    vm.startPrank(player);
    world.app__consumeItem(characterId, 360, 1, targetData);
    vm.stopPrank();

    assertEq(CharOtherItem.getAmount(characterId, 360), 0);
    assertEq(CharCurrentStats.getHp(characterId2), 1); // abs dmg - min hp is 1
  }
}
