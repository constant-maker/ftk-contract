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
  PvPChallengeV2,
  PvPChallengeV2Data,
  Equipment,
  TileInfo3,
  AllianceV2,
  CharCurrentStats,
  CharCurrentStatsData,
  TileInventory,
  DropResource,
  KingSetting,
  PvPExtraV3,
  PvPExtraV3Data,
  CharInventory,
  CharBuff,
  CharBuffData,
  EquipmentInfo
} from "@codegen/index.sol";
import { EntityType, SlotType, ItemType, ZoneType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";
import {
  CharacterPositionUtils,
  InventoryItemUtils,
  InventoryEquipmentUtils,
  CharAchievementUtils,
  CharacterItemUtils,
  CharacterEquipmentUtils
} from "@utils/index.sol";
import { CharStats2 } from "@codegen/tables/CharStats2.sol";
import { LootItems } from "@systems/app/TileSystem.sol";
import { EquipData } from "@systems/app/EquipmentSystem.sol";
import { ItemsActionData } from "@common/Types.sol";
import { TargetItemData } from "@systems/app/ConsumeSystem.sol";

contract PvPSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player_1 = makeAddr("player1");
  address player_2 = makeAddr("player2");
  address player_3 = makeAddr("player3");
  uint256 characterId_1;
  uint256 characterId_2;
  uint256 characterId_3;

  uint256[5] customSkillIds_1 = [uint256(3), uint256(0), uint256(2), uint256(1), uint256(0)];
  uint256[5] customSkillIds_2 = [uint256(1), uint256(0), uint256(0), uint256(0), uint256(0)];

  int32 locationX = 30;
  int32 locationY = -35;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();
    characterId_1 = _createDefaultCharacter(player_1);
    _claimWelcomePackages(player_1, characterId_1);
    characterId_2 = _createCharacterWithName(player_2, "character2");
    _claimWelcomePackages(player_2, characterId_2);
    characterId_3 = _createCharacterWithNameAndKingdomId(player_3, "char3", 2);
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
    PvPChallengeV2Data memory pvpChallenge = PvPChallengeV2.get(characterId_2);
    assertEq(pvpChallenge.defenderId, 0);
    assertEq(pvpChallenge.firstAttackerId, 0);
    assertEq(pvpChallenge.hps[0], 0);
    assertEq(pvpChallenge.hps[1], 0);

    // char 1
    pvpChallenge = PvPChallengeV2.get(characterId_1);
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

    vm.startPrank(worldDeployer);
    CharCurrentStats.setHp(characterId_1, 200);
    CharCurrentStats.setHp(characterId_2, 200);
    vm.stopPrank();

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
    assertEq(pvp.damages[9], 21);
    assertEq(pvp.damages[10], 21);

    uint32 currentCharacterHp_1 = CharCurrentStats.getHp(characterId_1);
    uint32 currentCharacterHp_2 = CharCurrentStats.getHp(characterId_2);

    assertEq(currentCharacterHp_1, 92);
    assertEq(currentCharacterHp_2, 95);
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

    // character2 lost => move back to city
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId_2);
    assertEq(characterPosition.x, 30);
    assertEq(characterPosition.y, -36);
  }

  function test_BattleWithVeryHighDef() external {
    // character atk 2 def 2

    // both go to same location
    _moveToTheLocation(locationX, locationY);

    vm.startPrank(worldDeployer);
    CharCurrentStats.setDef(characterId_2, 50);
    vm.stopPrank();

    uint32 characterHp_1 = CharCurrentStats.getHp(characterId_1);
    console2.log("characterHp_1", characterHp_1);
    console2.log("characterAtk_1", CharCurrentStats.getAtk(characterId_1));
    console2.log("characterDef_1", CharCurrentStats.getDef(characterId_1));
    uint32 characterHp_2 = CharCurrentStats.getHp(characterId_2);
    console2.log("characterHp_2", characterHp_2);
    console2.log("characterAtk_2", CharCurrentStats.getAtk(characterId_2));
    console2.log("characterDef_2", CharCurrentStats.getDef(characterId_2));

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

    // for (uint256 i = 0; i < pvp.damages.length; i++) {
    //   console2.log("dmg index", i);
    //   console2.log("dmg value", pvp.damages[i]);
    // }
    // assert dmg
    assertEq(pvp.damages[0], 0); // no bonus attack
    // def 50 => reduce all level bonus dmg max(0, 1 - (50-2) * 0.3) => only 20 min dmg left
    assertEq(pvp.damages[1], 20);
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
    _addEquipment(characterId_2, equipmentId, 36); // 36 Hunting Bow - Green
    _gearUpWeapon(characterId_2, equipmentId);
    _gearUpWeapon(characterId_1, 1); // Rusty Sword - Red

    console2.log("character 1 atk", CharCurrentStats.getAtk(characterId_1));
    console2.log("character2 def", CharCurrentStats.getDef(characterId_2));

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
    assertEq(pvp.damages[1], 45); // (atk 2 - def 2 + 20 + level 1 = 21 ~ skill 200% dmg ~ plus 8% advantage
    assertEq(pvp.damages[2], 22); // skill 115% dmg ~ minus 8% advantage
    assertEq(pvp.damages[3], 22);
    assertEq(pvp.damages[4], 19);
    assertEq(pvp.damages[5], 22);
    assertEq(pvp.damages[6], 19);
    assertEq(pvp.damages[7], 22);
    assertEq(pvp.damages[8], 0); // character 1 already win from prev turn

    uint32 currentCharacterHp_1 = CharCurrentStats.getHp(characterId_1);
    uint32 currentCharacterHp_2 = CharCurrentStats.getHp(characterId_2);

    assertEq(currentCharacterHp_1, 40);
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
    CharCurrentStats.setAtk(characterId_1, 1000);
    CharCurrentStats.setAgi(characterId_1, 1000);
    TileInfo3.setKingdomId(20, -32, 1);
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

    _moveToTheLocation(21, -32); // RED zone
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();
    char1Fame = CharStats2.get(characterId_1);
    assertEq(char1Fame, 950);

    // update char 2 stats
    vm.startPrank(worldDeployer);
    CharCurrentStats.setAtk(characterId_2, 2000);
    CharCurrentStats.setAgi(characterId_2, 2000);
    vm.stopPrank();

    vm.warp(block.timestamp + 300);

    _moveToTheLocation(21, -32); // RED zone
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
    AllianceV2.set(1, 2, true, true);
    vm.stopPrank();
    _moveToTheLocation(20, -32); // GREEN zone
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_3);
    vm.stopPrank();

    char1Fame = CharStats2.get(characterId_1);
    assertEq(char1Fame, 900);
  }

  function test_DropItemInDangerZone() external {
    vm.warp(block.timestamp + 300);

    uint256[] memory dropResourceIds = DropResource.get();
    console2.log("drop resource ids length", dropResourceIds.length);
    // for (uint256 i = 0; i < dropResourceIds.length; i++) {
    //   console2.log("resource id", dropResourceIds[i]);
    // }

    _moveToTheLocation(20, -32);

    vm.startPrank(worldDeployer);
    TileInfo3.setKingdomId(20, -32, 1);
    InventoryItemUtils.addItem(characterId_1, 1, 100);
    InventoryItemUtils.addItem(characterId_1, 2, 100);
    vm.stopPrank();

    // update char 2 stats
    vm.startPrank(worldDeployer);
    CharCurrentStats.setAtk(characterId_2, 2000);
    CharCurrentStats.setAgi(characterId_2, 2000);
    vm.stopPrank();

    uint32 weightChar1 = CharCurrentStats.getWeight(characterId_1);
    console2.log("weight char 1", weightChar1);
    uint32 weightChar2 = CharCurrentStats.getWeight(characterId_2);
    console2.log("weight char 2", weightChar2);

    vm.startPrank(player_2);
    world.app__battlePvP(characterId_2, characterId_1);
    vm.stopPrank();

    assertEq(CharOtherItem.getAmount(characterId_1, 1), 100);
    assertEq(CharOtherItem.getAmount(characterId_1, 2), 100);
    console2.log("done test fight in green zone");

    vm.warp(block.timestamp + 300);
    console2.log("move to red zone");
    _moveToTheLocation(21, -32); // RED zone
    vm.startPrank(player_2);
    world.app__battlePvP(characterId_2, characterId_1);
    vm.stopPrank();

    assertEq(CharOtherItem.getAmount(characterId_1, 1), 100);
    assertEq(CharOtherItem.getAmount(characterId_1, 2), 0); // dropped 100 items
    uint32 newWeightChar1 = CharCurrentStats.getWeight(characterId_1);
    console2.log("new weight char 1 in red zone", newWeightChar1);
    assertEq(newWeightChar1, weightChar1 - 100); // 100 items dropped (weight 1 each)

    uint256[] memory tileItemIds = TileInventory.getOtherItemIds(21, -32);
    uint32[] memory tileItemAmounts = TileInventory.getOtherItemAmounts(21, -32);
    for (uint256 i = 0; i < tileItemIds.length; i++) {
      console2.log("tile item id", tileItemIds[i]);
      console2.log("tile item amount", tileItemAmounts[i]);
    }
    assertEq(tileItemIds[0], 2);
    assertEq(tileItemAmounts[0], 100);
    console2.log("done test fight in red zone");

    vm.warp(block.timestamp + 300);
    vm.startPrank(worldDeployer);
    TileInfo3.setZoneType(21, -32, ZoneType.Black);
    CharacterItemUtils.addNewItem(characterId_1, 329, 1); // tier 7 // weight 11
    CharacterItemUtils.addNewItem(characterId_1, 70, 1); // tier 6 // weight 10
    vm.stopPrank();

    weightChar1 = CharCurrentStats.getWeight(characterId_1);
    console2.log("weight char 1", weightChar1); // 140
    console2.log("len equipment inventory", CharInventory.lengthEquipmentIds(characterId_1));
    assertEq(CharInventory.lengthEquipmentIds(characterId_1), 3);
    console2.log("tile kingdom id", TileInfo3.getKingdomId(21, -32));

    vm.startPrank(player_1);
    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });
    world.app__gearUpEquipments(characterId_1, equipDatas);
    vm.stopPrank();

    console2.log("equipped weapon id", CharEquipment.get(characterId_1, SlotType.Weapon));

    console2.log("move to black zone");
    _moveToTheLocation(21, -32); // BLACK zone
    vm.startPrank(player_2);
    world.app__battlePvP(characterId_2, characterId_1);
    vm.stopPrank();

    newWeightChar1 = CharCurrentStats.getWeight(characterId_1);
    console2.log("new weight char 1 in black zone", newWeightChar1);
    assertEq(newWeightChar1, weightChar1 - 10 - 11); // 2 highest equipment is dropped
    assertEq(CharInventory.lengthEquipmentIds(characterId_1), 1);
    assertEq(CharInventory.getItemEquipmentIds(characterId_1, 0), 1);

    uint256[] memory tileEquipmentIds = TileInventory.getEquipmentIds(21, -32);
    assertEq(tileEquipmentIds.length, 2);
    assertEq(tileEquipmentIds[0], 4); // tier 7
    assertEq(tileEquipmentIds[1], 5); // tier 6

    console2.log("done test fight in black zone");

    // test loot item
    uint256[] memory equipmentIds = new uint256[](1);
    equipmentIds[0] = 4;
    uint256[] memory itemIds = new uint256[](1);
    uint32[] memory itemAmounts = new uint32[](1);
    itemIds[0] = 2;
    itemAmounts[0] = 10;
    vm.startPrank(player_2);
    world.app__lootItems(
      characterId_2, LootItems({ equipmentIds: equipmentIds, itemIds: itemIds, itemAmounts: itemAmounts })
    );
    vm.stopPrank();
    assertEq(CharOtherItem.getAmount(characterId_2, 2), 10);
    assertEq(CharOtherItem.getAmount(characterId_1, 2), 0);
    uint32 tileItemAmount = TileInventory.getItemOtherItemAmounts(21, -32, 0);
    assertEq(tileItemAmount, 90);
    tileEquipmentIds = TileInventory.getEquipmentIds(21, -32);
    assertEq(tileEquipmentIds.length, 1);

    console2.log("has equipment", InventoryEquipmentUtils.hasEquipment(characterId_1, 4));
    console2.log("has equipment", InventoryEquipmentUtils.hasEquipment(characterId_2, 4));
    console2.log("char id", Equipment.getCharacterId(4));
    assertEq(Equipment.getCharacterId(4), characterId_2);

    uint32 newWeightChar2 = CharCurrentStats.getWeight(characterId_2);
    console2.log("new weight char 2 in black zone", newWeightChar2);
    assertEq(newWeightChar2, weightChar2 + 11 + 10); // 11 for equipped weapon + 10 items (weight 1 each)

    // uint256[] memory equipmentIds = new uint256[](1);
    // equipmentIds[0] = 1;
    ItemsActionData memory dropData = ItemsActionData({
      equipmentIds: equipmentIds,
      toolIds: new uint256[](0),
      itemIds: new uint256[](0),
      itemAmounts: new uint32[](0)
    });

    vm.startPrank(player_2);
    world.app__drop(characterId_2, dropData);
    vm.stopPrank();

    newWeightChar2 = CharCurrentStats.getWeight(characterId_2);
    console2.log("new weight char 2 in black zone", newWeightChar2);
    assertEq(newWeightChar2, weightChar2 + 10); // + 10 items (weight 1 each)

    console2.log("done test loot item");
  }

  function test_LootItem() external {
    // update char 2 stats
    vm.startPrank(worldDeployer);
    CharCurrentStats.setAtk(characterId_2, 2000);
    CharCurrentStats.setAgi(characterId_2, 2000);

    TileInfo3.setZoneType(21, -32, ZoneType.Black);

    InventoryItemUtils.addItem(characterId_1, 1, 100);
    InventoryItemUtils.addItem(characterId_1, 2, 100);
    vm.stopPrank();

    uint32 weightChar1 = CharCurrentStats.getWeight(characterId_1);
    console2.log("weight char 1 in black zone", weightChar1);

    console2.log("move to black zone");
    _moveToTheLocation(21, -32); // BLACK zone
    vm.warp(block.timestamp + 3);
    vm.startPrank(player_2);
    world.app__battlePvP(characterId_2, characterId_1);
    vm.stopPrank();

    uint32 newWeightChar1 = CharCurrentStats.getWeight(characterId_1);
    console2.log("new weight char 1 in black zone", newWeightChar1);
    assertEq(newWeightChar1, weightChar1 - 100 - 5); // 100 items dropped (weight 1 each) + 5 weight for equipped weapon

    uint256[] memory tileEquipmentIds = TileInventory.getEquipmentIds(21, -32);
    assertEq(tileEquipmentIds.length, 1);
    assertEq(tileEquipmentIds[0], 1);

    console2.log("test loot item in black zone");

    // test loot item
    uint256[] memory equipmentIds = new uint256[](1);
    equipmentIds[0] = 1;
    uint256[] memory itemIds = new uint256[](1);
    uint32[] memory itemAmounts = new uint32[](1);
    itemIds[0] = 2;
    itemAmounts[0] = 10;
    uint256[] memory emptyArray = new uint256[](0);
    uint32[] memory emptyArray32 = new uint32[](0);
    CharPositionData memory charPosition1 = CharacterPositionUtils.currentPosition(characterId_1);
    console2.log("char 1 position x", charPosition1.x);
    console2.log("char 1 position y", charPosition1.y);
    console2.log("play 1 try to loot item");
    vm.expectRevert();
    vm.startPrank(player_1);
    world.app__lootItems(
      characterId_1, LootItems({ equipmentIds: equipmentIds, itemIds: emptyArray, itemAmounts: emptyArray32 })
    );
    vm.stopPrank();

    uint32 weightChar2 = CharCurrentStats.getWeight(characterId_2);
    vm.startPrank(player_2);
    world.app__lootItems(
      characterId_2, LootItems({ equipmentIds: equipmentIds, itemIds: itemIds, itemAmounts: itemAmounts })
    );
    vm.stopPrank();
    assertEq(CharOtherItem.getAmount(characterId_2, 2), 10);
    assertEq(CharOtherItem.getAmount(characterId_1, 2), 0);
    uint32 tileItemAmount = TileInventory.getItemOtherItemAmounts(21, -32, 0);
    assertEq(tileItemAmount, 90);
    tileEquipmentIds = TileInventory.getEquipmentIds(21, -32);
    assertEq(tileEquipmentIds.length, 0);

    console2.log("has equipment", InventoryEquipmentUtils.hasEquipment(characterId_1, 1));
    console2.log("has equipment", InventoryEquipmentUtils.hasEquipment(characterId_2, 1));
    console2.log("char id", Equipment.getCharacterId(1));
    assertEq(Equipment.getCharacterId(1), characterId_2);

    uint32 newWeightChar2 = CharCurrentStats.getWeight(characterId_2);
    console2.log("new weight char 2 in black zone", newWeightChar2);
    assertEq(newWeightChar2, weightChar2 + 5 + 10); // 5 for equipped weapon + 10 items (weight 1 each)
  }

  function test_KingSettingAndAchievement() external {
    // update char 2 stats
    vm.startPrank(worldDeployer);
    CharCurrentStats.setAtk(characterId_1, 5000);
    CharCurrentStats.setAgi(characterId_1, 200);

    TileInfo3.setZoneType(20, -32, ZoneType.Green);
    TileInfo3.setKingdomId(20, -32, 1);

    AllianceV2.set(1, 2, true, true);
    vm.stopPrank();

    _moveToTheLocation(20, -32);
    // fight in safe zone, no king setting
    vm.warp(block.timestamp + 3);
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();
    assertEq(CharStats2.get(characterId_1), 950);

    vm.startPrank(worldDeployer);
    TileInfo3.setKingdomId(20, -32, 2);

    CharCurrentStats.setAtk(characterId_3, 9000);
    CharCurrentStats.setAgi(characterId_3, 500);
    vm.stopPrank();
    // fight in ally safe zone, no king setting
    vm.warp(block.timestamp + 3);
    vm.startPrank(player_3);
    world.app__battlePvP(characterId_3, characterId_1);
    vm.stopPrank();

    assertEq(CharStats2.get(characterId_3), 950);
    uint256 lastPvpId = CharBattle.getLastPvpId(characterId_3);
    PvPExtraV3Data memory pvpExtra = PvPExtraV3.get(lastPvpId);
    assertEq(pvpExtra.fames[0], -50);
    assertEq(pvpExtra.fames[1], 0);

    // fight in safe zone with king setting
    vm.startPrank(worldDeployer);
    TileInfo3.setKingdomId(20, -32, 1);
    KingSetting.setPvpFamePenalty(1, 10);
    vm.stopPrank();
    _moveToTheLocation(20, -32);
    vm.warp(block.timestamp + 3);
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();
    assertEq(CharStats2.get(characterId_1), 900);
    lastPvpId = CharBattle.getLastPvpId(characterId_1);
    pvpExtra = PvPExtraV3.get(lastPvpId);
    assertEq(pvpExtra.fames[0], -50);
    assertEq(pvpExtra.fames[1], 0);

    // fight in death zone with king setting
    vm.startPrank(worldDeployer);
    TileInfo3.setZoneType(20, -32, ZoneType.Black);
    CharCurrentStats.setAtk(characterId_3, 9);
    CharCurrentStats.setAgi(characterId_3, 9);
    vm.stopPrank();
    _moveToTheLocation(20, -32);

    vm.warp(block.timestamp + 3);
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_3);
    vm.stopPrank();
    assertEq(CharStats2.get(characterId_1), 890);
    lastPvpId = CharBattle.getLastPvpId(characterId_1);
    pvpExtra = PvPExtraV3.get(lastPvpId);
    assertEq(pvpExtra.fames[0], -10);
    assertEq(pvpExtra.fames[1], 0);

    // test achievement
    vm.startPrank(worldDeployer);
    AllianceV2.deleteRecord(1, 2);
    CharStats2.setFame(characterId_3, 100_000);
    vm.stopPrank();

    uint32 char1Fame = CharStats2.get(characterId_1);

    // for (uint256 i = 0; i < 500; i++) {
    //   _moveToTheLocation(20, -32);
    //   vm.warp(block.timestamp + 3);
    //   vm.startPrank(player_1);
    //   world.app__battlePvP(characterId_1, characterId_3);
    //   vm.stopPrank();
    //   lastPvpId = CharBattle.getLastPvpId(characterId_1);
    //   pvpExtra = PvPExtraV3.get(lastPvpId);
    //   assertEq(pvpExtra.fames[0], 10);
    //   assertEq(pvpExtra.fames[1], -20);
    // }

    // assertEq(CharStats2.get(characterId_1), char1Fame + 500 * 10); // 10 fame per fight
    // assertTrue(CharAchievementUtils.hasAchievement(characterId_1, 12));
    // assertTrue(CharAchievementUtils.hasAchievement(characterId_1, 13));
    // assertTrue(CharAchievementUtils.hasAchievement(characterId_1, 14));
    // assertTrue(CharAchievementUtils.hasAchievement(characterId_1, 15));
    // assertTrue(CharAchievementUtils.hasAchievement(characterId_1, 16));
  }

  function test_UsingBuffItem() external {
    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId_1, 356, 1); // gain 5 ms
    InventoryItemUtils.addItem(characterId_1, 357, 1); // decrease ms by 3
    vm.stopPrank();

    CharCurrentStatsData memory currentStatsChar1 = CharCurrentStats.get(characterId_1);
    console2.log("char 1 atk", currentStatsChar1.atk);
    console2.log("char 1 def", currentStatsChar1.def);
    console2.log("char 1 agi", currentStatsChar1.agi);
    CharCurrentStatsData memory currentStatsChar2 = CharCurrentStats.get(characterId_2);
    console2.log("char 2 atk", currentStatsChar2.atk);
    console2.log("char 2 def", currentStatsChar2.def);
    console2.log("char 2 agi", currentStatsChar2.agi);

    _moveToTheLocation(20, -32);

    TargetItemData memory targetData;
    targetData.targetPlayers = new uint256[](1);
    targetData.targetPlayers[0] = characterId_1;
    targetData.x = 20;
    targetData.y = -32;

    vm.warp(block.timestamp + 300);
    vm.startPrank(player_1);
    world.app__consumeItem(characterId_1, 356, 1, targetData); // char 1, atk = 3 (2 + 50% of 2), def = 0 (4 - 100% of
      // 4)
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();

    PvPData memory pvp = PvP.get(1);
    assertEq(pvp.attackerId, characterId_1);
    assertEq(pvp.defenderId, characterId_2);
    assertEq(pvp.firstAttackerId, characterId_1);

    // result in normal condition
    // assertEq(pvp.damages[0], 0); // no bonus attack
    // assertEq(pvp.damages[1], 21); // (atk 2 - def 2 + 20 + level 1 = 21
    // assertEq(pvp.damages[2], 21);
    // assertEq(pvp.damages[3], 21);
    // assertEq(pvp.damages[4], 21);

    // result in buff condition
    assertEq(pvp.damages[0], 0); // no bonus attack
    assertEq(pvp.damages[1], 22); // atk 3 - def 2 + 20 + level 1 = 22
    assertEq(pvp.damages[2], 23); // atk 2 - def 0 + 20 + 1 = 23

    vm.warp(block.timestamp + 10);
    _moveToTheLocation(20, -32);

    vm.startPrank(worldDeployer);
    CharCurrentStats.setAgi(characterId_2, 100); // increase agi to reduce more ms
    CharCurrentStats.setAtk(characterId_2, 1000); // increase atk to deal more damage
    vm.stopPrank();
    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();

    CharPositionData memory char1Position = CharacterPositionUtils.currentPosition(characterId_1);
    assertEq(char1Position.x, 30);
    assertEq(char1Position.y, -36);
    CharBuffData memory char1Buff = CharBuff.get(characterId_1);
    assertEq(char1Buff.buffIds[0], 0); // dispel on death
    assertEq(char1Buff.buffIds[1], 0); // dispel on death
  }

  function test_2HandAdvantage() external {
    console2.log("item 361 2handed", EquipmentInfo.getTwoHanded(361));
    console2.log("item 362 2handed", EquipmentInfo.getTwoHanded(362));

    vm.startPrank(worldDeployer);
    CharacterItemUtils.addNewItem(characterId_1, 361, 1); // 2 hand axe - blue
    CharacterItemUtils.addNewItem(characterId_2, 362, 1); // 2 hand spear - green
    CharCurrentStats.setAgi(characterId_2, 5); // attack first
    vm.stopPrank();

    for (uint256 i = 1; i <= 5; i++) {
      console2.log("item id", Equipment.getItemId(i));
    }

    assertEq(Equipment.getItemId(4), 361);
    assertEq(Equipment.getItemId(5), 362);

    _gearUpWeapon(characterId_1, 4);
    _gearUpWeapon(characterId_2, 5);

    CharCurrentStatsData memory currentStatsChar1 = CharCurrentStats.get(characterId_1);
    console2.log("char 1 atk", currentStatsChar1.atk);
    console2.log("char 1 def", currentStatsChar1.def);
    console2.log("char 1 agi", currentStatsChar1.agi);
    CharCurrentStatsData memory currentStatsChar2 = CharCurrentStats.get(characterId_2);
    console2.log("char 2 atk", currentStatsChar2.atk);
    console2.log("char 2 def", currentStatsChar2.def);
    console2.log("char 2 agi", currentStatsChar2.agi);

    _moveToTheLocation(20, -32);

    vm.warp(block.timestamp + 3);

    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();

    PvPData memory pvp = PvP.get(1);
    assertEq(pvp.attackerId, characterId_1);
    assertEq(pvp.defenderId, characterId_2);
    assertEq(pvp.firstAttackerId, characterId_2);

    for (uint256 i = 0; i < pvp.damages.length; i++) {
      console2.log("dmg index", i);
      console2.log("dmg value", pvp.damages[i]);
    }

    // assert dmg
    assertEq(pvp.damages[0], 0); // no bonus attack
    assertEq(pvp.damages[1], 24); // atk 2 - def 2 + 20 + level 1 = 21 ~ plus 15% advantage

    vm.startPrank(worldDeployer);
    EquipmentInfo.setTwoHanded(362, false); // remove 2 handed property
    vm.stopPrank();

    _moveToTheLocation(20, -32);

    vm.warp(block.timestamp + 3);

    vm.startPrank(player_1);
    world.app__battlePvP(characterId_1, characterId_2);
    vm.stopPrank();

    pvp = PvP.get(2);
    assertEq(pvp.damages[0], 0); // no bonus attack
    assertEq(pvp.damages[1], 22); // atk 2 - def 2 + 20 + level 1 = 21 ~ plus 8% advantage // 1 handed now
  }

  function _moveToTheLocation(int32 _x, int32 _y) private {
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId_1, _x, _y);
    CharacterPositionUtils.moveToLocation(characterId_2, _x, _y);
    CharacterPositionUtils.moveToLocation(characterId_3, _x, _y);
    vm.stopPrank();
  }

  function _setSkill(uint256 characterId, uint256[5] memory customSkillIds) private {
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
