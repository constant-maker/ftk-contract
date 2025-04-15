pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, MoveSystemFixture } from "./fixtures/index.sol";
import {
  CharCurrentStats,
  CharStats,
  CharSkill,
  CharEquipment,
  CharPerk,
  CharBattle,
  MonsterStats,
  MonsterStatsData,
  BossInfo,
  BossInfoData,
  PvE,
  PvEData,
  PvEExtra,
  PvEExtraData,
  TileInfo3,
  CharFund
} from "@codegen/index.sol";
import { EntityType, SlotType, ItemType } from "@codegen/common.sol";
import { Achievement, AchievementData } from "@codegen/tables/Achievement.sol";
import { CharOtherItem } from "@codegen/tables/CharOtherItem.sol";
import { CharAchievement } from "@codegen/tables/CharAchievement.sol";
import { CharacterItemUtils } from "@utils/CharacterItemUtils.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharAchievementUtils } from "@utils/CharAchievementUtils.sol";

contract PvESystemBossTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, MoveSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  int32 locationX = -50;
  int32 locationY = -17;

  uint256 bossId = 9;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, MoveSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_ShouldHaveData() external {
    uint256[] memory monsterIds = TileInfo3.getMonsterIds(locationX, locationY);
    assertEq(monsterIds.length, 1);
    assertEq(monsterIds[0], 9);

    MonsterStatsData memory monsterStats = MonsterStats.get(bossId);
    assertEq(monsterStats.hp, 1500);
    assertEq(monsterStats.atk, 10);
    assertEq(monsterStats.def, 2);
    assertEq(monsterStats.agi, 1);
    assertEq(monsterStats.sp, 5);

    BossInfoData memory bossInfo = BossInfo.get(bossId, locationX, locationY);
    assertEq(bossInfo.barrier, 50);
    assertEq(bossInfo.hp, 1500);
    assertEq(bossInfo.crystal, 300);
    assertEq(bossInfo.respawnDuration, 1); // 1 hour
    assertEq(bossInfo.berserkHpThreshold, 20);
    assertEq(bossInfo.boostPercent, 20);
    assertEq(bossInfo.lastDefeatedTime, 0);

    AchievementData memory achievement = Achievement.get(3);
    assertEq(achievement.def, 1);
    assertEq(achievement.agi, 1);
  }

  function test_BattleWithBossAndDead() external {
    // character atk 2 def 2 hp 100

    // set position to hunting place
    _moveToBossLocation(characterId);

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);

    vm.warp(block.timestamp + 4320 * 24 * 60 * 60);
    vm.startPrank(player);
    world.app__battlePvE(characterId, bossId);
    vm.stopPrank();

    PvEData memory pve = PvE.get(1);
    assertEq(pve.monsterId, bossId);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    assertEq(pve.hps[1], 1500);
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    // for (uint256 i = 0; i < pve.damages.length; i++) {
    //   console2.log("dmg index", i);
    //   console2.log("dmg value", pve.damages[i]);
    // }
    assertEq(pve.damages[0], 0); // no bonus attack
    assertEq(pve.damages[1], 21);
    assertEq(pve.damages[2], 128); // level 100 + 20 (min dmg) + atk 10 - def 2
    assertEq(pve.damages[3], 0); // player dead

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 100);
  }

  function test_BattleWithBoss() external {
    // character atk 2 def 2 hp 100

    // set position to hunting place
    _moveToBossLocation(characterId);

    _gearUpEquipment();

    vm.startPrank(worldDeployer);
    BossInfo.setHp(bossId, locationX, locationY, 300);
    CharCurrentStats.setHp(characterId, 2000);
    CharCurrentStats.setAtk(characterId, 100);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);

    uint16 prevAgi = CharCurrentStats.getAgi(characterId);

    vm.warp(block.timestamp + 4320 * 24 * 60 * 60);
    vm.startPrank(player);
    world.app__battlePvE(characterId, bossId);
    vm.stopPrank();

    PvEData memory pve = PvE.get(1);
    assertEq(pve.monsterId, bossId);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    assertEq(pve.hps[1], 300);
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    // for (uint256 i = 0; i < pve.damages.length; i++) {
    //   console2.log("dmg index", i);
    //   console2.log("dmg value", pve.damages[i]);
    // }
    assertEq(pve.damages[0], 0); // no bonus attack
    assertEq(pve.damages[1], 119);
    assertEq(pve.damages[2], 130); // level 100 + 20 (min dmg) + atk 12 (boost) - def 2
    assertEq(pve.damages[3], 119);
    assertEq(pve.damages[4], 156); // skill 120% dmg
    assertEq(pve.damages[5], 119);
    assertEq(pve.damages[6], 0); // bot dead

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 120); // set to real max hp
    assertEq(CharCurrentStats.getExp(characterId), 280);
    assertEq(CharStats.getLevel(characterId), 2);
    assertEq(CharCurrentStats.getExp(characterId), 280);
    assertEq(CharPerk.getExp(characterId, ItemType.Sword), 150);
    assertEq(CharFund.getCrystal(characterId), 300);

    assertEq(CharAchievement.getAchievementIds(characterId).length, 2);
    assertEq(CharAchievement.getAchievementIds(characterId)[0], 3);
    assertTrue(CharAchievementUtils.hasAchievement(characterId, 3));

    assertEq(prevAgi + 1, CharCurrentStats.getAgi(characterId));

    vm.expectRevert();
    vm.startPrank(player);
    world.app__battlePvE(characterId, bossId);
    vm.stopPrank();

    vm.warp(block.timestamp + 4320 * 24 * 60 * 60);
    vm.startPrank(player);
    world.app__battlePvE(characterId, bossId);
    vm.stopPrank();
  }

  function test_BattleWithBossManyTimes() external {
    // character atk 2 def 2 hp 100

    // set position to hunting place
    _moveToBossLocation(characterId);

    _gearUpEquipment();

    vm.startPrank(worldDeployer);
    BossInfo.setHp(bossId, locationX, locationY, 300);
    CharCurrentStats.setHp(characterId, 2000);
    CharCurrentStats.setAtk(characterId, 1000);
    CharCurrentStats.setAgi(characterId, 1000);
    vm.stopPrank();

    for (uint256 i = 0; i < 10; i++) {
      vm.warp(block.timestamp + 4320 * 24 * 60 * 60);
      vm.startPrank(player);
      world.app__battlePvE(characterId, bossId);
      vm.stopPrank();
    }
    uint32 amount1 = CharOtherItem.getAmount(characterId, 36);
    uint32 amount2 = CharOtherItem.getAmount(characterId, 37);
    uint32 amount3 = CharOtherItem.getAmount(characterId, 38);
    assertEq(amount1 + amount2 + amount3, 10);
  }

  function test_BattleWithBossLoseButStillAlive() external {
    // character atk 2 def 2 hp 100

    // set position to hunting place
    _moveToBossLocation(characterId);

    _gearUpEquipment();

    vm.startPrank(worldDeployer);
    CharCurrentStats.setHp(characterId, 2000);
    CharCurrentStats.setAtk(characterId, 100);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);

    vm.warp(block.timestamp + 4320 * 24 * 60 * 60);
    vm.startPrank(player);
    world.app__battlePvE(characterId, bossId);
    vm.stopPrank();

    PvEData memory pve = PvE.get(1);
    assertEq(pve.monsterId, bossId);
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
    assertEq(pve.damages[1], 119);
    assertEq(pve.damages[2], 128); // level 100 + 20 (min dmg) + atk 10 - def 2
    assertEq(pve.damages[3], 119);
    assertEq(pve.damages[4], 153); // skill 120% dmg
    assertEq(pve.damages[5], 119);
    assertEq(pve.damages[6], 128);
    assertEq(pve.damages[7], 119);
    assertEq(pve.damages[8], 320); // skill 250% dmg

    assertEq(CharCurrentStats.getHp(characterId), 1143);
    assertEq(BossInfo.getHp(bossId, locationX, locationY), 955); // 1500 - (119 * 5 - 50) barrier block 50 dmg
    assertEq(CharCurrentStats.getExp(characterId), 0);
    assertEq(CharPerk.getExp(characterId, ItemType.Sword), 0);
  }

  function test_BerserkBoss() external {
    // character atk 2 def 2 hp 100

    // set position to hunting place
    _moveToBossLocation(characterId);

    vm.startPrank(worldDeployer);
    BossInfo.setHp(bossId, locationX, locationY, 300);
    CharCurrentStats.setHp(characterId, 2000);
    CharCurrentStats.setAtk(characterId, 10);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    uint256[5] memory skills = CharSkill.get(characterId);

    vm.warp(block.timestamp + 4320 * 24 * 60 * 60);
    vm.startPrank(player);
    world.app__battlePvE(characterId, bossId);
    vm.stopPrank();

    PvEData memory pve = PvE.get(1);
    assertEq(pve.monsterId, bossId);
    assertEq(pve.x, locationX);
    assertEq(pve.y, locationY);
    assertTrue(pve.firstAttacker == EntityType.Character);
    assertEq(pve.hps[0], characterHp);
    assertEq(pve.hps[1], 300);
    for (uint256 i = 0; i < skills.length; i++) {
      assertEq(pve.characterSkillIds[i], skills[i]);
    }
    // for (uint256 i = 0; i < pve.damages.length; i++) {
    //   console2.log("dmg index", i);
    //   console2.log("dmg value", pve.damages[i]);
    // }
    assertEq(pve.damages[0], 0); // no bonus attack
    assertEq(pve.damages[1], 29);
    assertEq(pve.damages[2], 130); // level 100 + 20 (min dmg) + atk 12 (boost) - def 2
    assertEq(pve.damages[3], 29);
    assertEq(pve.damages[4], 156); // skill 120% dmg
    assertEq(pve.damages[5], 29);
    assertEq(pve.damages[6], 455); // berserk skill 350% dmg
    assertEq(pve.damages[7], 29);
    assertEq(pve.damages[8], 325); // skill 250% dmg
  }

  function _gearUpEquipment() private {
    vm.startPrank(worldDeployer);
    CharEquipment.set(characterId, SlotType.Weapon, 1);
    vm.stopPrank();
  }
}
