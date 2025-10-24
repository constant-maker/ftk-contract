pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, MoveSystemFixture } from "./fixtures/index.sol";
import {
  CharGrindSlot,
  CharPosition,
  CharPositionData,
  CharNextPosition,
  CharNextPositionData,
  CharCurrentStats,
  CharStats,
  CharSkill,
  CharEquipment,
  CharPerk,
  CharOtherItem,
  CharBattle,
  MonsterStats,
  PvE,
  PvEData,
  PvEExtraV2,
  PvEExtraV2Data,
  TileInfo3
} from "@codegen/index.sol";
import { EntityType, SlotType, ItemType } from "@codegen/common.sol";
import { CharacterItemUtils } from "@utils/CharacterItemUtils.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";

contract PvESystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, MoveSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  int32 locationX = 30;
  int32 locationY = -35;

  uint256 monsterId = 1;
  uint256 monsterId2 = 2;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, MoveSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_BattleCharacterLoseButStillAlive() external {
    // character atk 2 def 2
    // monster atk 5 def 1

    // set position to hunting place
    _moveToMonsterLocation(characterId);

    vm.startPrank(worldDeployer);
    MonsterStats.setHp(monsterId, 200);
    CharCurrentStats.setHp(characterId, 200);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId, true);
    vm.stopPrank();

    PvEData memory pve = PvE.get(characterId);
    assertEq(pve.monsterId, monsterId);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    // for (uint256 i = 0; i < pve.damages.length; i++) {
    //   console2.log("dmg index", i);
    //   console2.log("dmg value", pve.damages[i]);
    // }
    assertEq(pve.damages[0], 0); // no bonus attack
    assertEq(pve.damages[1], 22);
    assertEq(pve.damages[2], 24);
    assertEq(pve.damages[3], 22);
    assertEq(pve.damages[4], 24);
    assertEq(pve.damages[5], 22);
    assertEq(pve.damages[6], 24);
    assertEq(pve.damages[7], 22);
    assertEq(pve.damages[8], 30); // monster use skill 125% dmg ~

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 74);
    assertEq(CharCurrentStats.getExp(characterId), 0);
  }

  function test_BattleWithSkillHighSP() external {
    // character atk 2 def 2
    // monster atk 5 def 1

    // set position to hunting place
    _moveToMonsterLocation(characterId);

    uint256[5] memory customSkillIds = [uint256(12), uint256(0), uint256(2), uint256(1), uint256(0)];
    vm.startPrank(worldDeployer);
    MonsterStats.setHp(monsterId, 200);
    CharCurrentStats.setHp(characterId, 200);
    CharSkill.setSkillIds(characterId, customSkillIds);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId, true);
    vm.stopPrank();

    PvEData memory pve = PvE.get(characterId);
    assertEq(pve.monsterId, monsterId);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);

    // assert skill
    assertEq(pve.characterSkillIds[0], 12);
    assertEq(pve.characterSkillIds[1], 0);
    assertEq(pve.characterSkillIds[2], 2);
    assertEq(pve.characterSkillIds[3], 0);
    // assert dmg
    assertEq(pve.damages[0], 0); // no bonus attack
    assertEq(pve.damages[1], 33);
    assertEq(pve.damages[2], 0);
    assertEq(pve.damages[3], 22);
    assertEq(pve.damages[4], 24);
    assertEq(pve.damages[5], 33);
    assertEq(pve.damages[6], 24);
    assertEq(pve.damages[7], 22);
    assertEq(pve.damages[8], 30); // monster use skill 125% dmg ~

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 98);
    assertEq(CharCurrentStats.getExp(characterId), 0);
  }

  function test_BattleHaveBonusAttack() external {
    // character atk 2 def 2
    // monster atk 5 def 1

    // set position to hunting place
    _moveToMonsterLocation(characterId);

    vm.startPrank(worldDeployer);
    CharCurrentStats.setAgi(characterId, 100);
    MonsterStats.setHp(monsterId, 1000);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId, true);
    vm.stopPrank();

    PvEData memory pve = PvE.get(characterId);
    assertEq(pve.monsterId, monsterId);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    assertEq(pve.damages[0], 48); // (atk 2 - def 0) + 20 + level 1 = 23 * (100 + 99 * 1.15) / 100
    assertEq(pve.damages[1], 22); // (atk 2 - def 1) + 20 + level 1 = 22
    assertEq(pve.damages[2], 24); // (atk 5 - def 2) + 20 + level 1 = 24
    assertEq(pve.damages[6], 24); // monster died

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 100); // died
  }

  function test_BattleCharacterWinWithEquipment() external {
    // set position to hunting place
    _moveToMonsterLocation(characterId);

    // gear up equipment
    _gearUpEquipment();

    vm.startPrank(worldDeployer);
    CharCurrentStats.setAtk(characterId, 30);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId2, true);
    vm.stopPrank();

    PvEData memory pve = PvE.get(characterId);
    assertEq(pve.monsterId, monsterId2);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    assertEq(pve.hps[1], 0); // normal monster
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    assertEq(pve.damages[0], 0);
    assertEq(pve.damages[1], 56); // +15% advantage
    assertEq(pve.damages[2], 23); // -15% advantage
    assertEq(pve.damages[4], 0); // monster dead

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 77);

    assertEq(CharCurrentStats.getExp(characterId), 12);
    assertEq(CharPerk.getExp(characterId, ItemType.Sword), 6);
    // assertEq(CharOtherItem.getAmount(characterId, 17), 1);
    // assertEq(CharOtherItem.getAmount(characterId, 16), 1);
    PvEExtraV2Data memory pvpExtra = PvEExtraV2.get(characterId);
    uint256 rewardItemId = pvpExtra.itemId;
    uint256 rewardItemAmount = pvpExtra.itemAmount;
    assertEq(CharOtherItem.getAmount(characterId, rewardItemId), rewardItemAmount);

    assertTrue(CharOtherItem.getAmount(characterId, 17) == 1 || CharOtherItem.getAmount(characterId, 16) == 1);
    assertTrue(
      CharOtherItem.getCharId(characterId, 17) == characterId || CharOtherItem.getCharId(characterId, 16) == characterId
    );

    uint32 newCurrentWeight = CharCurrentStats.getWeight(characterId);
    assertTrue(newCurrentWeight > currentWeight);

    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(characterId);
    uint8 farmSlot = TileInfo3.getFarmSlot(charPosition.x, charPosition.y);
    assertEq(farmSlot, 5);
  }

  function test_BattleCharacterWinAndLevelUp() external {
    // set position to hunting place
    _moveToMonsterLocation(characterId);

    // gear up equipment
    _gearUpEquipment();

    vm.startPrank(worldDeployer);
    CharCurrentStats.setAtk(characterId, 30);
    CharCurrentStats.setExp(characterId, 1000);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId2, true);
    vm.stopPrank();

    PvEData memory pve = PvE.get(characterId);
    assertEq(pve.monsterId, monsterId2);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    assertEq(pve.hps[1], 0); // normal monster
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    assertEq(pve.damages[0], 0);
    assertEq(pve.damages[1], 56); // +15% advantage
    assertEq(pve.damages[2], 23); // -15% advantage
    assertEq(pve.damages[4], 0); // monster dead

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, CharStats.getHp(characterId));

    assertEq(CharCurrentStats.getExp(characterId), 992);
    assertEq(CharPerk.getExp(characterId, ItemType.Sword), 6);
    // assertEq(CharOtherItem.getAmount(characterId, 17), 1);
    // assertEq(CharOtherItem.getAmount(characterId, 16), 1);
    PvEExtraV2Data memory pvpExtra = PvEExtraV2.get(characterId);
    uint256 rewardItemId = pvpExtra.itemId;
    uint256 rewardItemAmount = pvpExtra.itemAmount;
    assertEq(CharOtherItem.getAmount(characterId, rewardItemId), rewardItemAmount);

    assertTrue(CharOtherItem.getAmount(characterId, 17) == 1 || CharOtherItem.getAmount(characterId, 16) == 1);
    assertTrue(
      CharOtherItem.getCharId(characterId, 17) == characterId || CharOtherItem.getCharId(characterId, 16) == characterId
    );

    uint32 newCurrentWeight = CharCurrentStats.getWeight(characterId);
    assertTrue(newCurrentWeight > currentWeight);

    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(characterId);
    uint8 farmSlot = TileInfo3.getFarmSlot(charPosition.x, charPosition.y);
    console2.log("farmSlot", farmSlot);
    assertEq(farmSlot, 5);

    uint16 currentLevel = CharStats.getLevel(characterId);
    assertEq(currentLevel, 2);
  }

  function test_BattleCharacterWinWithHighLevel() external {
    // set position to hunting place
    _moveToMonsterLocation(characterId);

    // gear up equipment
    _gearUpEquipment();

    vm.startPrank(worldDeployer);
    CharCurrentStats.setAtk(characterId, 30);
    CharStats.setLevel(characterId, 15);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId2, true);
    vm.stopPrank();

    PvEData memory pve = PvE.get(characterId);
    assertEq(pve.monsterId, monsterId2);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    assertEq(pve.hps[1], 0); // normal monster
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    assertEq(pve.damages[0], 0);
    assertEq(pve.damages[1], 72); // +15% advantage
    assertEq(pve.damages[2], 23); // -15% advantage
    assertEq(pve.damages[4], 0); // monster dead

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 77);

    assertEq(CharCurrentStats.getExp(characterId), 6);
    assertEq(CharPerk.getExp(characterId, ItemType.Sword), 6);

    assertTrue(CharOtherItem.getAmount(characterId, 17) == 1 || CharOtherItem.getAmount(characterId, 16) == 1);
    assertTrue(
      CharOtherItem.getCharId(characterId, 17) == characterId || CharOtherItem.getCharId(characterId, 16) == characterId
    );

    uint32 newCurrentWeight = CharCurrentStats.getWeight(characterId);
    assertTrue(newCurrentWeight > currentWeight);

    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(characterId);
    uint8 farmSlot = TileInfo3.getFarmSlot(charPosition.x, charPosition.y);
    assertEq(farmSlot, 5);
  }

  function test_BattleCharacterWinWithVeryHighLevel() external {
    // set position to hunting place
    _moveToMonsterLocation(characterId);

    // gear up equipment
    _gearUpEquipment();

    vm.startPrank(worldDeployer);
    CharCurrentStats.setAtk(characterId, 30);
    CharStats.setLevel(characterId, 30);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId2, true);
    vm.stopPrank();

    PvEData memory pve = PvE.get(characterId);
    assertEq(pve.monsterId, monsterId2);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    assertEq(pve.damages[0], 0);
    assertEq(pve.damages[1], 89); // +15% advantage
    assertEq(pve.damages[2], 23); // -15% advantage
    assertEq(pve.damages[4], 0); // monster dead

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 77);

    PvEExtraV2Data memory pvpExtra = PvEExtraV2.get(characterId);

    assertEq(CharCurrentStats.getExp(characterId), 0);
    assertEq(CharPerk.getExp(characterId, ItemType.Sword), 6);

    assertTrue(CharOtherItem.getAmount(characterId, 17) == 1 || CharOtherItem.getAmount(characterId, 16) == 1);
    assertTrue(
      CharOtherItem.getCharId(characterId, 17) == characterId || CharOtherItem.getCharId(characterId, 16) == characterId
    );

    uint32 newCurrentWeight = CharCurrentStats.getWeight(characterId);
    assertTrue(newCurrentWeight > currentWeight);

    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(characterId);
    uint8 farmSlot = TileInfo3.getFarmSlot(charPosition.x, charPosition.y);
    assertEq(farmSlot, 5);
  }

  function test_BattleWinAndGainGrindSlotPerkExp() external {
    // set position to hunting place
    _moveToMonsterLocation(characterId);

    // gear up equipment
    _gearUpEquipment();

    vm.startPrank(worldDeployer);
    CharacterItemUtils.addNewItem(characterId, 46, 1); // add shield
    CharEquipment.set(characterId, SlotType.SubWeapon, 2);
    CharGrindSlot.set(characterId, SlotType.SubWeapon);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharCurrentStats.setAtk(characterId, 30);

    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId2, true);
    vm.stopPrank();

    PvEData memory pve = PvE.get(characterId);
    assertEq(pve.monsterId, monsterId2);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    assertEq(pve.damages[0], 0);
    assertEq(pve.damages[1], 56); // +15% advantage
    assertEq(pve.damages[2], 23); // -15% advantage
    assertEq(pve.damages[4], 0); // monster dead

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 77);

    assertEq(CharCurrentStats.getExp(characterId), 12);
    assertEq(CharPerk.getExp(characterId, ItemType.Sword), 0);
    assertEq(CharPerk.getExp(characterId, ItemType.Shield), 6);
    // assertEq(CharOtherItem.getAmount(characterId, 17), 1);
    // assertEq(CharOtherItem.getAmount(characterId, 16), 1);
    assertTrue(CharOtherItem.getAmount(characterId, 17) == 1 || CharOtherItem.getAmount(characterId, 16) == 1);
    assertTrue(
      CharOtherItem.getCharId(characterId, 17) == characterId || CharOtherItem.getCharId(characterId, 16) == characterId
    );

    uint32 newCurrentWeight = CharCurrentStats.getWeight(characterId);
    assertTrue(newCurrentWeight > currentWeight);
  }

  function test_BattleCharacterLoseAndDead() external {
    // set position to hunting place
    _moveToMonsterLocation(characterId);

    vm.startPrank(worldDeployer);
    MonsterStats.setAtk(monsterId, 200);
    CharCurrentStats.setExp(characterId, 100);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);

    vm.warp(block.timestamp + 300);
    console2.log("char atk", CharCurrentStats.getAtk(characterId));
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId, true);
    vm.stopPrank();

    PvEData memory pve = PvE.get(characterId);
    assertEq(pve.monsterId, monsterId);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    assertEq(pve.damages[0], 0);
    assertEq(pve.damages[1], 22);
    assertEq(pve.damages[2], 219);
    assertEq(pve.damages[3], 0);

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    uint32 characterMaxHp = CharStats.getHp(characterId);
    assertEq(characterCurrentHp, characterMaxHp);
    assertEq(CharCurrentStats.getExp(characterId), 75); // penalty 25%

    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    assertEq(characterPosition.x, 30);
    assertEq(characterPosition.y, -36);
    CharPositionData memory prevPosition = CharPosition.get(characterId);
    assertEq(prevPosition.x, 30);
    assertEq(prevPosition.y, -36);
    CharNextPositionData memory nextPosition = CharNextPosition.get(characterId);
    assertEq(nextPosition.x, 30);
    assertEq(nextPosition.y, -36);
  }

  function test_BattleRevertWrongPosition() external {
    vm.warp(block.timestamp + 300);
    vm.expectRevert();
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId, true);
    vm.stopPrank();
  }

  function test_BattleRevertInvalidWeight() external {
    // set position to hunting place
    _moveToMonsterLocation(characterId);
    vm.warp(block.timestamp + 300);
    uint32 maxWeight = CharStats.getWeight(characterId);
    vm.startPrank(worldDeployer);
    CharCurrentStats.setWeight(characterId, maxWeight + 1);
    vm.stopPrank();
    vm.expectRevert();
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId, true);
    vm.stopPrank();
  }

  function test_BattleWithSkillEffect() external {
    // character atk 2 def 2
    // monster atk 5 def 1

    // set position to hunting place
    _moveToMonsterLocation(characterId);

    vm.startPrank(worldDeployer);
    MonsterStats.setHp(monsterId, 200);
    CharCurrentStats.setHp(characterId, 200);
    CharPerk.setLevel(characterId, ItemType.StoneHammer, 1);
    uint256[5] memory customSkillIds = [uint256(0), 11, 0, 0, 0];
    CharSkill.setSkillIds(characterId, customSkillIds);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    console2.log("char atk", CharCurrentStats.getAtk(characterId));
    // console2.log("char def", CharCurrentStats.getAtk(characterId));
    uint256[5] memory skills = CharSkill.get(characterId);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId, true);
    vm.stopPrank();

    PvEData memory pve = PvE.get(characterId);
    assertEq(pve.monsterId, monsterId);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    // for (uint256 i = 0; i < pve.damages.length; i++) {
    //   console2.log("dmg index", i);
    //   console2.log("dmg value", pve.damages[i]);
    // }
    assertEq(pve.damages[0], 0); // no bonus attack
    assertEq(pve.damages[1], 22);
    assertEq(pve.damages[2], 24);
    assertEq(pve.damages[3], 38); // skill 150% dmg + 25% next turn
    assertEq(pve.damages[4], 24);
    assertEq(pve.damages[5], 27); // DOT dmg 25%
    assertEq(pve.damages[6], 24);
    assertEq(pve.damages[7], 22);
    assertEq(pve.damages[8], 30); // monster use skill 125% dmg ~

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 74);
    assertEq(CharCurrentStats.getExp(characterId), 0);
  }

  function test_BattleWithSkillStun() external {
    // character atk 2 def 2
    // monster atk 5 def 1

    // set position to hunting place
    _moveToMonsterLocation(characterId);

    vm.startPrank(worldDeployer);
    MonsterStats.setHp(monsterId, 200);
    CharCurrentStats.setHp(characterId, 200);
    CharPerk.setLevel(characterId, ItemType.StoneHammer, 1);
    uint256[5] memory customSkillIds = [uint256(0), 12, 0, 0, 0];
    CharSkill.setSkillIds(characterId, customSkillIds);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    console2.log("char atk", CharCurrentStats.getAtk(characterId));
    // console2.log("char def", CharCurrentStats.getAtk(characterId));
    uint256[5] memory skills = CharSkill.get(characterId);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player);
    world.app__battlePvE(characterId, monsterId, true);
    vm.stopPrank();

    PvEData memory pve = PvE.get(characterId);
    assertEq(pve.monsterId, monsterId);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    // for (uint256 i = 0; i < pve.damages.length; i++) {
    //   console2.log("dmg index", i);
    //   console2.log("dmg value", pve.damages[i]);
    // }
    assertEq(pve.damages[0], 0); // no bonus attack
    assertEq(pve.damages[1], 22);
    assertEq(pve.damages[2], 24);
    assertEq(pve.damages[3], 33); // skill 150% dmg
    assertEq(pve.damages[4], 0);
    assertEq(pve.damages[5], 22);
    assertEq(pve.damages[6], 24);
    assertEq(pve.damages[7], 22);
    assertEq(pve.damages[8], 30); // monster use skill 125% dmg ~

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 98);
    assertEq(CharCurrentStats.getExp(characterId), 0);
  }

  function _gearUpEquipment() private {
    vm.startPrank(worldDeployer);
    CharEquipment.set(characterId, SlotType.Weapon, 1);
    vm.stopPrank();
  }
}
