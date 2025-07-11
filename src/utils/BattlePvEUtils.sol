pragma solidity >=0.8.24;

import {
  CharPositionData,
  CharBattle,
  MonsterLocationData,
  Monster,
  PvE,
  PvEData,
  PvEExtraV2,
  PvEExtraV2Data,
  BossInfo,
  BossInfoData,
  MonsterStats,
  MonsterStatsData,
  CharCurrentStats,
  CharStats,
  Item,
  CharCStats2
} from "@codegen/index.sol";
import { BattleInfo, BattleUtils } from "./BattleUtils.sol";
import { CharacterFundUtils } from "./CharacterFundUtils.sol";
import { InventoryItemUtils } from "./InventoryItemUtils.sol";
import { EntityType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";

library BattlePvEUtils {
  uint8 public constant BERSERK_SP_BONUS = 5;

  /// @dev perform and return the result of the fight
  /// hps is final hp of character and monster
  function performFight(
    uint256 characterId,
    uint256 monsterId,
    uint32 characterOriginHp,
    uint256[5] memory characterSkills,
    CharPositionData memory characterPosition,
    MonsterLocationData memory monsterLocation
  )
    public
    view
    returns (EntityType firstAttackerType, uint32[2] memory hps, uint32[11] memory damages)
  {
    // Build battle information for character and monster
    BattleInfo memory characterBattleInfo =
      BattleUtils.buildCharacterBattleInfo(characterId, characterSkills, characterOriginHp);
    BattleInfo memory monsterBattleInfo =
      buildMonsterBattleInfo(monsterId, characterPosition.x, characterPosition.y, monsterLocation);

    // Determine the first attacker based on agility
    if (characterBattleInfo.agi >= monsterBattleInfo.agi) {
      firstAttackerType = EntityType.Character;
      (hps, damages) = BattleUtils.fight(characterBattleInfo, monsterBattleInfo);
    } else {
      firstAttackerType = EntityType.Monster;
      (hps, damages) = BattleUtils.fight(monsterBattleInfo, characterBattleInfo);
      // hps now is [monsterHP, characterHP], we need to swap it to [characterHP, monsterHP]
      (hps[0], hps[1]) = (hps[1], hps[0]);
    }

    return (firstAttackerType, hps, damages);
  }

  /// @dev store the result of battle
  function storePvEData(
    uint256 characterId,
    uint256 monsterId,
    uint32 characterOriginHp,
    EntityType firstAttacker,
    CharPositionData memory characterPosition,
    uint256[5] memory characterSkills,
    uint32[11] memory damages
  )
    public
  {
    // get origin hp if monster is boss, monsterHp will be zero with normal monster
    uint32 monsterHp = BossInfo.getHp(monsterId, characterPosition.x, characterPosition.y);
    uint256 currentCounter = PvE.getCounter(characterId);
    PvEData memory pve = PvEData({
      monsterId: monsterId,
      x: characterPosition.x,
      y: characterPosition.y,
      firstAttacker: firstAttacker,
      counter: currentCounter + 1,
      timestamp: block.timestamp,
      characterSkillIds: characterSkills,
      damages: damages,
      hps: [characterOriginHp, monsterHp]
    });
    PvE.set(characterId, pve);
    CharBattle.setPveLastAtkTime(characterId, block.timestamp);
  }

  function getExpAndPerkExpReward(
    uint256 monsterId,
    bool isBoss,
    uint16 monsterLevel,
    uint16 characterLevel
  )
    public
    view
    returns (uint32 exp, uint32 perkExp)
  {
    exp = Monster.getExp(monsterId);
    perkExp = Monster.getPerkExp(monsterId);
    if (isBoss) return (exp, perkExp);
    uint8 grow = Monster.getGrow(monsterId) / 3;
    uint16 multiplier = 100 + (monsterLevel - 1) * grow;
    exp = exp * multiplier / 100;
    perkExp = perkExp * multiplier / 100;
    if (characterLevel >= monsterLevel + 20) {
      // if the character's level is 20 or more above the monster's level, exp reward is zero
      exp = 0;
    } else if (characterLevel >= monsterLevel + 10) {
      // if the character's level is 10 or more above the monster's level, halve the exp
      exp /= 2;
    }
    return (exp, perkExp);
  }

  function handleBossResult(
    uint256 characterId,
    uint256 monsterId,
    uint32 monsterHp,
    CharPositionData memory charPosition
  )
    public
  {
    if (!Monster.getIsBoss(monsterId)) {
      return;
    }
    int32 x = charPosition.x;
    int32 y = charPosition.y;
    if (monsterHp == 0) {
      BossInfo.setHp(monsterId, x, y, MonsterStats.getHp(monsterId));
      BossInfo.setLastDefeatedTime(monsterId, x, y, block.timestamp);
      CharacterFundUtils.increaseCrystal(characterId, BossInfo.getCrystal(monsterId, x, y));
    } else {
      BossInfo.setHp(monsterId, x, y, monsterHp);
    }
  }

  function checkIsReadyToBattle(uint256 characterId) public view {
    uint256 lastPvETimestamp = CharBattle.getPveLastAtkTime(characterId);
    uint256 nextBattleTimestamp = lastPvETimestamp + Config.ATTACK_COOLDOWN;
    if (block.timestamp < nextBattleTimestamp) {
      revert Errors.PvE_NotReadyToBattle(nextBattleTimestamp);
    }
  }

  function checkIsBossReady(uint256 monsterId, CharPositionData memory characterPosition) public view {
    if (!Monster.getIsBoss(monsterId)) {
      return;
    }
    // respawnDuration is in hour
    uint256 respawnTime = BossInfo.getLastDefeatedTime(monsterId, characterPosition.x, characterPosition.y)
      + uint32(BossInfo.getRespawnDuration(monsterId, characterPosition.x, characterPosition.y)) * 60 * 60;
    if (block.timestamp < respawnTime) {
      revert Errors.PvE_BossIsNotRespawnedYet(monsterId, respawnTime);
    }
  }

  /// @dev build monster BattleInfo
  function buildMonsterBattleInfo(
    uint256 monsterId,
    int32 x,
    int32 y,
    MonsterLocationData memory monsterLocation
  )
    public
    view
    returns (BattleInfo memory monsterBattleInfo)
  {
    monsterBattleInfo.id = monsterId;
    MonsterStatsData memory monsterStats = MonsterStats.get(monsterId);
    uint8 monsterSp = monsterStats.sp;
    if (!Monster.getIsBoss(monsterId)) {
      grewMonsterStats(monsterId, monsterStats, monsterLocation.level);
    } else {
      BossInfoData memory bossInfo = BossInfo.get(monsterId, x, y);
      monsterBattleInfo.barrier = bossInfo.barrier; // set barrier
      if (bossInfo.hp <= monsterStats.hp * bossInfo.berserkHpThreshold / 100) {
        uint16 multiplier = 100 + bossInfo.boostPercent;
        monsterStats.atk = monsterStats.atk * multiplier / 100;
        monsterStats.def = monsterStats.def * multiplier / 100;
        monsterStats.agi = monsterStats.agi * multiplier / 100;
        monsterSp += BERSERK_SP_BONUS;
      }
      monsterStats.hp = bossInfo.hp; // use current boss hp
    }
    monsterBattleInfo.hp = monsterStats.hp;
    monsterBattleInfo.atk = monsterStats.atk;
    monsterBattleInfo.def = monsterStats.def;
    monsterBattleInfo.agi = monsterStats.agi;
    monsterBattleInfo.level = monsterLocation.level;
    monsterBattleInfo.advantageType = monsterLocation.advantageType;
    monsterBattleInfo.skillIds = getMonsterSkillIds(monsterId, monsterSp);

    return monsterBattleInfo;
  }

  function getMonsterSkillIds(uint256 monsterId, uint8 monsterSp) public view returns (uint256[5] memory skillIds) {
    uint256[5] memory monsterSkillIds = Monster.getSkillIds(monsterId);

    return BattleUtils.reBuildSkills(monsterSkillIds, monsterSp);
  }

  function grewMonsterStats(uint256 monsterId, MonsterStatsData memory monsterStats, uint16 level) public view {
    uint8 grow = Monster.getGrow(monsterId);
    uint16 multiplier = (100 + (level - 1) * grow);
    monsterStats.hp = monsterStats.hp * multiplier / 100;
    monsterStats.atk = monsterStats.atk * multiplier / 100;
    monsterStats.def = monsterStats.def * multiplier / 100;
    monsterStats.agi = monsterStats.agi * multiplier / 100;
  }

  function claimReward(uint256 characterId, uint256 monsterId) public {
    uint256[] memory itemIds = Monster.getItemIds(monsterId);
    uint32[] memory itemAmounts = Monster.getItemAmounts(monsterId);
    if (itemIds.length == 0) {
      return;
    }
    if (itemIds.length != itemAmounts.length) {
      revert Errors.Monster_InvalidResourceData(monsterId, itemIds.length, itemAmounts.length);
    }
    uint256 index;
    if (itemIds.length > 1) {
      index = PvE.getCounter(characterId) % itemIds.length;
    }
    uint256 itemId = itemIds[index];
    uint32 amount = itemAmounts[index];
    uint32 itemWeight = Item.getWeight(itemId);
    uint32 newWeight = CharCurrentStats.getWeight(characterId) + itemWeight * amount;
    uint32 maxWeight = CharStats.getWeight(characterId);
    if (newWeight > maxWeight) {
      revert Errors.Character_WeightsExceed(newWeight, maxWeight);
    }
    InventoryItemUtils.addItem(characterId, itemId, amount);
    storePvEExtraData(characterId, itemId, amount);
  }

  function storePvEExtraData(uint256 characterId, uint256 rewardItemId, uint32 rewardItemAmount) public {
    PvEExtraV2Data memory pveExtra = PvEExtraV2Data({
      itemId: rewardItemId,
      itemAmount: rewardItemAmount,
      characterBarrier: CharCStats2.getBarrier(characterId)
    });
    PvEExtraV2.set(characterId, pveExtra);
  }
}
