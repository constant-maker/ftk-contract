pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture } from "./fixtures/index.sol";
import {
  CharPosition,
  CharStats,
  CharSkill,
  CharEquipment,
  CharPerk,
  CharOtherItem,
  CharPosition,
  CharPositionData,
  CharBattle,
  PvP,
  PvPData,
  PvPChallenge,
  PvPChallengeData,
  Equipment
} from "@codegen/index.sol";
import { EntityType, SlotType, ItemType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharStats2 } from "@codegen/tables/CharStats2.sol";
import { Alliance } from "@codegen/tables/Alliance.sol";
import { CharCurrentStats } from "@codegen/tables/CharCurrentStats.sol";

contract PvPSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player_1 = makeAddr("player1");
  address player_2 = makeAddr("player2");
  address player_3 = makeAddr("player3");
  uint256 characterId_1;
  uint256 characterId_2;
  uint256 characterId_3;

  uint256[4] customSkillIds_1 = [uint256(3), uint256(0), uint256(2), uint256(1)];
  uint256[4] customSkillIds_2 = [uint256(1), uint256(0), uint256(0), uint256(0)];

  int32 locationX = 30;
  int32 locationY = -35;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();
    characterId_1 = _createDefaultCharacter(player_1);
    _claimWelcomePackages(player_1, characterId_1);
    characterId_2 = _createCharacterWithName(player_2, "character 2");
    _claimWelcomePackages(player_2, characterId_2);
    characterId_3 = _createCharacterWithNameAndKingdomId(player_3, "char 3", 2);
    _claimWelcomePackages(player_3, characterId_3);
  }

  function test_Challenge() external {
    _setSkill(characterId_2, customSkillIds_2);
    uint32 characterOriginHp_2 = CharCurrentStats.getHp(characterId_2);
    vm.startPrank(worldDeployer);
    CharCurrentStats.setHp(characterId_2, 1);
    vm.stopPrank();

    uint32 characterHp_1 = CharCurrentStats.getHp(characterId_1);
    uint32 characterHp_2 = CharCurrentStats.getHp(characterId_2);
    assertEq(characterHp_2, 1);

    vm.startPrank(player_1);
    world.app__challengePvP(characterId_1, characterId_2);
    vm.stopPrank();

    // assert last pvp id
    uint256 lastPvpId = CharBattle.getLastPvpId(characterId_1);
    assertEq(lastPvpId, 0);
    lastPvpId = CharBattle.getLastPvpId(characterId_2);
    assertEq(lastPvpId, 0);

    // char 2
    PvPChallengeData memory pvpChallenge = PvPChallenge.get(characterId_2);
    assertEq(pvpChallenge.defenderId, 0);
    assertEq(pvpChallenge.firstAttackerId, 0);
    assertEq(pvpChallenge.hps[0], 0);
    assertEq(pvpChallenge.hps[1], 0);

    // char 1
    pvpChallenge = PvPChallenge.get(characterId_1);
    assertEq(pvpChallenge.defenderId, characterId_2);
    assertEq(pvpChallenge.firstAttackerId, characterId_1);
    assertEq(pvpChallenge.hps[0], characterHp_1);
    assertEq(pvpChallenge.hps[1], characterOriginHp_2);

    // assert dmg
    assertEq(pvpChallenge.damages[0], 0); // no bonus attack
    assertEq(pvpChallenge.damages[1], 21); // (atk 2 - def 2 + 20 + level 1 = 21
    assertEq(pvpChallenge.damages[2], 24); // skill 115% dmg ~
    assertEq(pvpChallenge.damages[3], 21);
    assertEq(pvpChallenge.damages[4], 21);
    assertEq(pvpChallenge.damages[5], 21);
    assertEq(pvpChallenge.damages[6], 21);
    assertEq(pvpChallenge.damages[7], 21);
    assertEq(pvpChallenge.damages[8], 21);

    uint32 currentCharacterHp_1 = CharCurrentStats.getHp(characterId_1);
    uint32 currentCharacterHp_2 = CharCurrentStats.getHp(characterId_2);

    // hp must be unchanged
    assertEq(currentCharacterHp_1, 100);
    assertEq(currentCharacterHp_2, 1);
  }

  function test_BattleBothStillAlive() external {
    // character atk 2 def 2

    // both go to same location
    _moveToTheLocation(locationX, locationY);

    _setSkill(characterId_2, customSkillIds_2);

    // vm.startPrank(worldDeployer);
    // vm.stopPrank();

    uint32 characterHp_1 = CharCurrentStats.getHp(characterId_1);
    uint32 characterHp_2 = CharCurrentStats.getHp(characterId_2);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();

    // assert last pvp id
    uint256 lastPvpId = CharBattle.getLastPvpId(characterId_1);
    assertEq(lastPvpId, 1);
    lastPvpId = CharBattle.getLastPvpId(characterId_2);
    assertEq(lastPvpId, 1);

    PvPData memory pvp = PvP.get(1);
    assertEq(pvp.attackerId, characterId_1);
    assertEq(pvp.defenderId, characterId_2);
    assertEq(pvp.firstAttackerId, characterId_1);
    assertEq(pvp.hps[0], characterHp_1);
    assertEq(pvp.hps[1], characterHp_2);

    // assert dmg
    assertEq(pvp.damages[0], 0); // no bonus attack
    assertEq(pvp.damages[1], 21); // (atk 2 - def 2 + 20 + level 1 = 21
    assertEq(pvp.damages[2], 24); // skill 115% dmg ~
    assertEq(pvp.damages[3], 21);
    assertEq(pvp.damages[4], 21);
    assertEq(pvp.damages[5], 21);
    assertEq(pvp.damages[6], 21);
    assertEq(pvp.damages[7], 21);
    assertEq(pvp.damages[8], 21);

    uint32 currentCharacterHp_1 = CharCurrentStats.getHp(characterId_1);
    uint32 currentCharacterHp_2 = CharCurrentStats.getHp(characterId_2);

    assertEq(currentCharacterHp_1, 13);
    assertEq(currentCharacterHp_2, 16);
  }

  function test_BattleHasWinner() external {
    // character atk 2 def 2

    // both go to same location
    _moveToTheLocation(locationX, locationY);

    _setSkill(characterId_1, customSkillIds_1);
    _setSkill(characterId_2, customSkillIds_2);

    // vm.startPrank(worldDeployer);
    // vm.stopPrank();

    uint32 characterHp_1 = CharCurrentStats.getHp(characterId_1);
    console2.log("characterHp_1", characterHp_1);
    uint32 characterHp_2 = CharCurrentStats.getHp(characterId_2);
    console2.log("characterHp_2", characterHp_2);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();

    // assert last pvp id
    uint256 lastPvpId = CharBattle.getLastPvpId(characterId_1);
    assertEq(lastPvpId, 1);
    lastPvpId = CharBattle.getLastPvpId(characterId_2);
    assertEq(lastPvpId, 1);

    PvPData memory pvp = PvP.get(1);
    assertEq(pvp.attackerId, characterId_1);
    assertEq(pvp.defenderId, characterId_2);
    assertEq(pvp.firstAttackerId, characterId_1);
    assertEq(pvp.hps[0], characterHp_1);
    assertEq(pvp.hps[1], characterHp_2);

    // assert skill
    assertEq(pvp.skillIds[0], 0);
    assertEq(pvp.skillIds[1], 3);
    assertEq(pvp.skillIds[2], 1);
    assertEq(pvp.skillIds[3], 0);
    assertEq(pvp.skillIds[4], 0);
    assertEq(pvp.skillIds[5], 0);
    assertEq(pvp.skillIds[6], 0);
    assertEq(pvp.skillIds[7], 0);
    assertEq(pvp.skillIds[8], 0);

    // for (uint256 i = 0; i < pvp.damages.length; i++) {
    //   console2.log("dmg index", i);
    //   console2.log("dmg value", pvp.damages[i]);
    // }
    // assert dmg
    assertEq(pvp.damages[0], 0); // no bonus attack
    assertEq(pvp.damages[1], 42); // (atk 2 - def 2 + 20 + level 1 = 21 ~ skill 200% dmg
    assertEq(pvp.damages[2], 24); // skill 115% dmg ~
    assertEq(pvp.damages[3], 21);
    assertEq(pvp.damages[4], 21);
    assertEq(pvp.damages[5], 21);
    assertEq(pvp.damages[6], 21);
    assertEq(pvp.damages[7], 21);
    assertEq(pvp.damages[8], 0); // character 1 already win from prev turn

    uint32 currentCharacterHp_1 = CharCurrentStats.getHp(characterId_1);
    uint32 currentCharacterHp_2 = CharCurrentStats.getHp(characterId_2);

    assertEq(currentCharacterHp_1, 34);
    assertEq(currentCharacterHp_2, characterHp_2); // reset hp

    // character 2 lost => move back to city
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId_2);
    assertEq(characterPosition.x, 30);
    assertEq(characterPosition.y, -36);
  }

  function test_BattleHasWeaponAdvantage() external {
    // character atk 2 def 2

    // both go to same location
    _moveToTheLocation(locationX, locationY);

    // set skill
    _setSkill(characterId_1, customSkillIds_1);
    _setSkill(characterId_2, customSkillIds_2);

    // add equipment
    uint256 equipmentId = 100;
    _addEquipment(characterId_2, equipmentId, 33); // 33 Hunting Bow - Green
    _gearUpWeapon(characterId_2, equipmentId);
    _gearUpWeapon(characterId_1, 1); // Rusty Sword - Red

    // vm.startPrank(worldDeployer);
    // vm.stopPrank();

    uint32 characterHp_1 = CharCurrentStats.getHp(characterId_1);
    uint32 characterHp_2 = CharCurrentStats.getHp(characterId_2);

    vm.warp(block.timestamp + 300);
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();

    // assert last pvp id
    uint256 lastPvpId = CharBattle.getLastPvpId(characterId_1);
    assertEq(lastPvpId, 1);
    lastPvpId = CharBattle.getLastPvpId(characterId_2);
    assertEq(lastPvpId, 1);

    PvPData memory pvp = PvP.get(1);
    assertEq(pvp.attackerId, characterId_1);
    assertEq(pvp.defenderId, characterId_2);
    assertEq(pvp.firstAttackerId, characterId_1);
    assertEq(pvp.hps[0], characterHp_1);
    assertEq(pvp.hps[1], characterHp_2);

    for (uint256 i = 0; i < pvp.damages.length; i++) {
      console2.log("dmg index", i);
      console2.log("dmg value", pvp.damages[i]);
    }
    // assert dmg
    assertEq(pvp.damages[0], 0); // no bonus attack
    assertEq(pvp.damages[1], 48); // (atk 2 - def 2 + 20 + level 1 = 21 ~ skill 200% dmg ~ plus 15% advantage
    assertEq(pvp.damages[2], 20); // skill 115% dmg ~ minus 15% advantage
    assertEq(pvp.damages[3], 24);
    assertEq(pvp.damages[4], 17);
    assertEq(pvp.damages[5], 24);
    assertEq(pvp.damages[6], 17);
    assertEq(pvp.damages[7], 24);
    assertEq(pvp.damages[8], 0); // character 1 already win from prev turn

    uint32 currentCharacterHp_1 = CharCurrentStats.getHp(characterId_1);
    uint32 currentCharacterHp_2 = CharCurrentStats.getHp(characterId_2);

    assertEq(currentCharacterHp_1, 46);
    assertEq(currentCharacterHp_2, characterHp_2); // reset hp
  }

  function test_BattleRevertInvalidWeight() external {
    // set position to hunting place
    vm.warp(block.timestamp + 300);
    uint32 maxWeight = CharStats.getWeight(characterId_1);
    vm.startPrank(worldDeployer);
    CharCurrentStats.setWeight(characterId_1, maxWeight + 1);
    vm.stopPrank();
    vm.expectRevert();
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();
  }

  function test_Fame() external {
    vm.warp(block.timestamp + 300);

    _moveToTheLocation(20, -32);

    vm.startPrank(worldDeployer);
    CharCurrentStats.setAtk(characterId_1, 10_000);
    CharCurrentStats.setAgi(characterId_1, 10_000);
    vm.stopPrank();

    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();

    uint32 char1Fame = CharStats2.get(characterId_1);
    assertEq(char1Fame, 950);

    vm.warp(block.timestamp + 300);

    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_3);
    vm.stopPrank();
    char1Fame = CharStats2.get(characterId_1);
    assertEq(char1Fame, 950);

    vm.warp(block.timestamp + 300);

    _moveToTheLocation(21, -32); // BLUE zone
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();
    char1Fame = CharStats2.get(characterId_1);
    assertEq(char1Fame, 950);

    // update char 2 stats
    vm.startPrank(worldDeployer);
    CharCurrentStats.setAtk(characterId_2, 20_000);
    CharCurrentStats.setAgi(characterId_2, 20_000);
    vm.stopPrank();

    vm.warp(block.timestamp + 300);

    _moveToTheLocation(21, -32); // BLUE zone
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();

    char1Fame = CharStats2.get(characterId_1);
    assertEq(char1Fame, 950);
    uint32 char2Fame = CharStats2.get(characterId_2);
    assertEq(char2Fame, 1000);

    // test alliance
    vm.warp(block.timestamp + 300);
    vm.startPrank(worldDeployer);
    Alliance.set(1, 2, true);
    vm.stopPrank();
    _moveToTheLocation(20, -32); // GREEN zone
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_3);
    vm.stopPrank();

    char1Fame = CharStats2.get(characterId_1);
    assertEq(char1Fame, 900);
  }

  function _moveToTheLocation(int32 _x, int32 _y) private {
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId_1, _x, _y);
    CharacterPositionUtils.moveToLocation(characterId_2, _x, _y);
    CharacterPositionUtils.moveToLocation(characterId_3, _x, _y);
    vm.stopPrank();
  }

  function _setSkill(uint256 characterId, uint256[4] memory customSkillIds) private {
    vm.startPrank(worldDeployer);
    CharSkill.setSkillIds(characterId, customSkillIds);
    vm.stopPrank();
  }

  function _gearUpWeapon(uint256 characterId, uint256 weaponId) private {
    vm.startPrank(worldDeployer);
    CharEquipment.set(characterId, SlotType.Weapon, weaponId);
    vm.stopPrank();
  }

  function _addEquipment(uint256 characterId, uint256 equipmentId, uint256 itemId) private {
    vm.startPrank(worldDeployer);
    Equipment.set(equipmentId, itemId, characterId, 1, 0);
    vm.stopPrank();
  }
}
