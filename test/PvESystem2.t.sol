pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, MoveSystemFixture } from "./fixtures/index.sol";
import {
  CharGrindSlot,
  CharPosition,
  CharPositionData,
  CharCurrentStats,
  CharCurrentStatsData,
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
  TileInfo3,
  PvEAfkLoc,
  PvEAfk,
  PvEAfkData,
  MonsterLocation
} from "@codegen/index.sol";
import { EntityType, SlotType, ItemType, CharacterStateType } from "@codegen/common.sol";
import { CharacterItemUtils, CharacterStateUtils } from "@utils/index.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";

contract PvESystem2Test is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, MoveSystemFixture {
  address player = makeAddr("player");
  address player2 = makeAddr("player2");

  uint256 characterId;
  uint256 characterId2;

  int32 locationX = 30;
  int32 locationY = -35;

  uint256 monsterId = 1;
  uint256 monsterId2 = 2;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture, MoveSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);

    characterId2 = _createCharacterWithName(player2, "Character 2");
    _claimWelcomePackages(player2, characterId2);
  }

  function test_AFK() external {
    // character atk 2 def 2
    // monster atk 5 def 1

    // set position to hunting place
    _moveToMonsterLocation(characterId);
    _moveToMonsterLocation(characterId2);

    vm.startPrank(worldDeployer);
    MonsterStats.setHp(monsterId, 200);
    CharCurrentStats.setHp(characterId, 200);
    CharCurrentStats.setAtk(characterId, 150);
    CharCurrentStats.setAgi(characterId, 100);
    CharEquipment.set(characterId, SlotType.Weapon, 1);
    vm.stopPrank();

    uint32 characterHp = CharCurrentStats.getHp(characterId);
    assertEq(characterHp, 200);
    uint256[5] memory skills = CharSkill.get(characterId);

    vm.warp(block.timestamp + 10);
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
    assertEq(pve.damages[0], 338);
    assertEq(pve.damages[1], 0);
    assertEq(pve.damages[2], 0);
    assertEq(pve.damages[3], 0);
    assertEq(pve.damages[4], 0);
    assertEq(pve.damages[5], 0);
    assertEq(pve.damages[6], 0);
    assertEq(pve.damages[7], 0);
    assertEq(pve.damages[8], 0); // monster use skill 125% dmg ~

    uint32 characterCurrentHp = CharCurrentStats.getHp(characterId);
    assertEq(characterCurrentHp, 200);
    assertEq(CharCurrentStats.getExp(characterId), 10);
    assertEq(CharPerk.getExp(characterId, ItemType.Sword), 5);

    uint16 monsterLevel = MonsterLocation.getLevel(locationX, locationY, monsterId);
    console2.log("monster level", monsterLevel);

    // test AFK
    vm.warp(block.timestamp + 10);

    vm.expectRevert(); // must in state pve
    vm.startPrank(player);
    world.app__pveAFK(characterId, monsterId, true);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__pveAFK(characterId, monsterId, false);
    vm.stopPrank();
    CharacterStateUtils.mustInState(characterId, CharacterStateType.Hunting);

    PvEAfkData memory afk = PvEAfk.get(characterId);
    console2.log("afk monsterId", afk.monsterId);
    console2.log("afk expPerTick", afk.expPerTick);
    console2.log("afk maxTick", afk.maxTick);
    console2.log("afk perkExpPerTick", afk.perkExpPerTick);

    assertEq(afk.monsterId, monsterId);
    assertEq(afk.expPerTick, 10);
    assertEq(afk.perkExpPerTick, 5);
    assertEq(afk.maxTick, 169);

    vm.warp(block.timestamp + 21); // 2 ticks
    vm.startPrank(player);
    world.app__pveAFK(characterId, monsterId, true);
    vm.stopPrank();

    CharacterStateUtils.mustInState(characterId, CharacterStateType.Standby);

    CharCurrentStatsData memory charCurrentStats = CharCurrentStats.get(characterId);
    console2.log("char current stats exp", charCurrentStats.exp);
    assertEq(charCurrentStats.exp, 30); // 10 + 10 * 2 ticks
    assertEq(CharPerk.getExp(characterId, ItemType.Sword), 15); // 5 + 5 * 2 ticks

    afk = PvEAfk.get(characterId);
    assertEq(afk.maxTick, 0); // reset max tick
    assertEq(afk.monsterId, 0); // reset monster id
    assertEq(afk.expPerTick, 0); // reset exp per tick
    assertEq(afk.perkExpPerTick, 0); // reset perk exp per tick
    assertEq(PvEAfkLoc.get(locationX, locationY), 0); // reset afk loc

    vm.expectRevert(); // not ready to battle pve
    vm.startPrank(player);
    world.app__pveAFK(characterId, monsterId, false);
    vm.stopPrank();

    vm.warp(block.timestamp + 10);

    vm.startPrank(player);
    world.app__pveAFK(characterId, monsterId, false);
    vm.stopPrank();

    vm.warp(block.timestamp + 2000); // 200 ticks

    console2.log("character 2 pve afk");

    vm.expectRevert(); // other character already in pve afk
    vm.startPrank(player2);
    world.app__pveAFK(characterId2, monsterId, false);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__pveAFK(characterId, monsterId, true);
    vm.stopPrank();

    charCurrentStats = CharCurrentStats.get(characterId);
    console2.log("char current stats exp", charCurrentStats.exp);
    assertEq(charCurrentStats.exp, 1700);
    assertEq(CharPerk.getExp(characterId, ItemType.Sword), 1015); // 2000 => 200 ticks * 5 perk exp per tick + 15 from
      // previous afk
  }

  function _gearUpEquipment() private {
    vm.startPrank(worldDeployer);
    CharEquipment.set(characterId, SlotType.Weapon, 1);
    vm.stopPrank();
  }
}
