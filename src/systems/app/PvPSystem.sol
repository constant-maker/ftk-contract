pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharPositionData,
  CharCurrentStats,
  CharStats,
  CharBattle,
  PvP,
  PvPData,
  PvPChallenge,
  PvPChallengeData,
  PvPExtraV3,
  PvPExtraV3Data,
  PvPBattleCounter,
  TileInfo3,
  CharStats2,
  CharCStats2,
  KingSetting,
  PvPEnemyCounter
} from "@codegen/index.sol";
import { BattleInfo, BattleUtils } from "@utils/BattleUtils.sol";
import { DailyQuestUtils, CharacterPositionUtils, CharAchievementUtils, BattleUtils2 } from "@utils/index.sol";
import { CharacterStateType, ZoneType } from "@codegen/common.sol";
import { Errors, Config } from "@common/index.sol";
import { ZoneInfo, KingdomUtils } from "@utils/KingdomUtils.sol";

contract PvPSystem is System, CharacterAccessControl {
  /// @dev character init a battle with other player
  function battlePvP(
    uint256 attackerId,
    uint256 defenderId
  )
    public
    onlyAuthorizedWallet(attackerId)
    mustInState(attackerId, CharacterStateType.Standby)
    validateCurrentWeight(attackerId)
  {
    CharPositionData memory attackerPosition = CharacterPositionUtils.currentPosition(attackerId);
    CharPositionData memory defenderPosition = CharacterPositionUtils.currentPosition(defenderId);
    if (attackerPosition.x != defenderPosition.x || attackerPosition.y != defenderPosition.y) {
      revert Errors.PvP_NotSamePosition(attackerPosition.x, attackerPosition.y, defenderPosition.x, defenderPosition.y);
    }
    _checkIsReadyToBattle(attackerId, defenderId);

    (uint32 attackerHp, uint32 defenderHp) = _battle(attackerId, defenderId, false);

    _updateCharacterFame(attackerId, attackerHp, defenderId, defenderHp, attackerPosition);
    _handleBattleResult(attackerId, attackerHp, attackerPosition); // handle attacker result
    _handleBattleResult(defenderId, defenderHp, defenderPosition); // handle defender result

    DailyQuestUtils.updatePvpCount(attackerId);
  }

  /// @dev character try to challenge with other player, result is only win or lose, no hp or exp update
  function challengePvP(uint256 attackerId, uint256 defenderId) public onlyAuthorizedWallet(attackerId) {
    _battle(attackerId, defenderId, true);
    // check and update daily quest
    DailyQuestUtils.updatePvpCount(attackerId);
  }

  function _updateCharacterFame(
    uint256 attackerId,
    uint32 attackerHp,
    uint256 defenderId,
    uint32 defenderHp,
    CharPositionData memory position
  )
    private
  {
    if (attackerHp != 0 && defenderHp != 0) {
      return; // both alive, no fame change
    }
    int32 attackerFameChange = 0;
    int32 defenderFameChange = 0;
    uint32 attackerFame = CharStats2.getFame(attackerId);
    ZoneInfo memory zoneInfo = KingdomUtils.getZoneTypeFull(position.x, position.y, attackerId, defenderId);
    bool isAlliance = KingdomUtils.getIsAlliance(zoneInfo.attackerKingdomId, zoneInfo.defenderKingdomId);

    ZoneType zoneType = zoneInfo.zoneType;

    // Apply alliance adjustment to zoneType (only if attacker owns tile)
    if (
      TileInfo3.getZoneType(position.x, position.y) != ZoneType.Black && isAlliance
        && zoneInfo.attackerKingdomId == zoneInfo.tileKingdomId
    ) {
      zoneType = ZoneType.Green;
    }
    bool isSameSide = (
      zoneInfo.attackerKingdomId == zoneInfo.defenderKingdomId && zoneInfo.tileKingdomId == zoneInfo.attackerKingdomId
    ) || isAlliance;

    if (isSameSide && defenderHp == 0) {
      if (zoneType == ZoneType.Green) {
        attackerFame = attackerFame > 50 ? attackerFame - 50 : 1; // min fame is 1
        CharStats2.set(attackerId, attackerFame);
        attackerFameChange = -50;
      } else {
        uint32 famePenalty = KingSetting.getPvpFamePenalty(zoneInfo.attackerKingdomId);
        if (famePenalty > 0) {
          attackerFameChange = -int32(famePenalty);
          attackerFame = attackerFame > famePenalty ? attackerFame - famePenalty : 1; // min fame is 1
          CharStats2.set(attackerId, attackerFame);
        }
      }
      _storeFameChange(attackerFameChange, 0, attackerId, defenderId);
      return;
    }

    uint32 defenderFame = CharStats2.getFame(defenderId);
    if (attackerHp == 0 && attackerFame >= 1020) {
      _setFame(attackerId, defenderId, -20); // fame transfer from attacker to defender
    } else if (defenderHp == 0 && defenderFame >= 1020 && zoneType != ZoneType.Green) {
      _setFame(attackerId, defenderId, 20); // fame transfer from defender to attacker
      if (zoneInfo.attackerKingdomId != zoneInfo.defenderKingdomId) {
        _checkAndGiveAchievement(attackerId);
      }
    }
  }

  function _setFame(uint256 attackerId, uint256 defenderId, int32 fameChange) private {
    int32 attackerFameChange = fameChange;
    int32 defenderFameChange = -fameChange;

    uint32 attackerFame = CharStats2.getFame(attackerId);
    uint32 defenderFame = CharStats2.getFame(defenderId);
    int32 newAttackerFame = int32(attackerFame) + attackerFameChange;
    int32 newDefenderFame = int32(defenderFame) + defenderFameChange;
    CharStats2.set(attackerId, uint32(newAttackerFame));
    CharStats2.set(defenderId, uint32(newDefenderFame));

    _storeFameChange(attackerFameChange, defenderFameChange, attackerId, defenderId);
  }

  function _storeFameChange(
    int32 attackerFameChange,
    int32 defenderFameChange,
    uint256 attackerId,
    uint256 defenderId
  )
    private
  {
    uint256 pvpId = PvPBattleCounter.getCounter(); // this return the current pvpId
    int32[2] memory fameChanges = [attackerFameChange, defenderFameChange];
    PvPExtraV3.setFames(pvpId, fameChanges);
  }

  function _checkAndGiveAchievement(uint256 characterId) private {
    uint256 currentKills = PvPEnemyCounter.get(characterId);
    uint256 newKills = currentKills + 1;
    PvPEnemyCounter.set(characterId, newKills);

    if (newKills >= 20) {
      CharAchievementUtils.addAchievement(characterId, 12);
    }
    if (newKills >= 50) {
      CharAchievementUtils.addAchievement(characterId, 13);
    }
    if (newKills >= 100) {
      CharAchievementUtils.addAchievement(characterId, 14);
    }
    if (newKills >= 250) {
      CharAchievementUtils.addAchievement(characterId, 15);
    }
    if (newKills >= 500) {
      CharAchievementUtils.addAchievement(characterId, 16);
    }
  }

  function _handleBattleResult(uint256 characterId, uint32 characterHp, CharPositionData memory position) private {
    if (characterHp == 0) {
      BattleUtils2.checkAndForceStopAFK(characterId, position);
      BattleUtils2.applyLoss(characterId, position);
      CharCurrentStats.setHp(characterId, CharStats.getHp(characterId)); // set character hp to max hp
    } else {
      CharCurrentStats.setHp(characterId, characterHp);
    }
  }

  /// @dev _battle returns attacker and defender final hp
  function _battle(uint256 attackerId, uint256 defenderId, bool isChallenge) private returns (uint32, uint32) {
    uint256[5] memory attackerSkills = BattleUtils.getCharacterSkillIds(attackerId);
    uint256[5] memory defenderSkills = BattleUtils.getCharacterSkillIds(defenderId);
    // perform the fight and get results
    uint32[2] memory originHps = _getOriginHps(attackerId, defenderId, isChallenge);
    (uint256 firstAttackerId, uint32[2] memory hps, uint32[11] memory damages, uint256[11] memory skillIds) =
      _performFight(attackerId, defenderId, attackerSkills, defenderSkills, originHps);

    // store PvEData
    if (isChallenge) {
      _storePvPChallengeData(attackerId, defenderId, firstAttackerId, skillIds, damages, originHps);
    } else {
      _storePvPData(attackerId, defenderId, firstAttackerId, skillIds, damages, originHps);
    }

    return (hps[0], hps[1]);
  }

  function _storePvPData(
    uint256 attackerId,
    uint256 defenderId,
    uint256 firstAttackerId,
    uint256[11] memory skillIds,
    uint32[11] memory damages,
    uint32[2] memory hps
  )
    private
  {
    uint256[2] memory prevPvpIds = [CharBattle.getLastPvpId(attackerId), CharBattle.getLastPvpId(defenderId)];
    PvPData memory pvp = PvPData({
      attackerId: attackerId,
      defenderId: defenderId,
      firstAttackerId: firstAttackerId,
      timestamp: block.timestamp,
      prevPvpIds: prevPvpIds,
      skillIds: skillIds,
      damages: damages,
      hps: hps
    });
    uint256 newId = PvPBattleCounter.getCounter() + 1;
    PvP.set(newId, pvp);
    CharBattle.setLastPvpId(attackerId, newId);
    CharBattle.setLastPvpId(defenderId, newId);
    CharBattle.setPvpLastAtkTime(attackerId, block.timestamp);
    CharBattle.setPvpLastDefTime(defenderId, block.timestamp);
    PvPBattleCounter.setCounter(newId);
    _storePvPExtraData(newId, attackerId, defenderId);
  }

  function _storePvPChallengeData(
    uint256 attackerId,
    uint256 defenderId,
    uint256 firstAttackerId,
    uint256[11] memory skillIds,
    uint32[11] memory damages,
    uint32[2] memory hps
  )
    private
  {
    PvPChallengeData memory pvpChallenge = PvPChallengeData({
      defenderId: defenderId,
      firstAttackerId: firstAttackerId,
      timestamp: block.timestamp,
      skillIds: skillIds,
      damages: damages,
      hps: hps
    });
    PvPChallenge.set(attackerId, pvpChallenge);
  }

  function _storePvPExtraData(uint256 pvpId, uint256 attackerId, uint256 defenderId) private {
    uint256[6] memory attackerEquipmentIds = BattleUtils.getCharacterEquipments(attackerId);
    uint256[6] memory defenderEquipmentIds = BattleUtils.getCharacterEquipments(defenderId);
    uint32[2] memory barriers;
    barriers[0] = CharCStats2.getBarrier(attackerId);
    barriers[1] = CharCStats2.getBarrier(defenderId);
    int32[2] memory fames; // this will be update later
    PvPExtraV3Data memory pvpExtra = PvPExtraV3Data({
      characterLevels: [CharStats.getLevel(attackerId), CharStats.getLevel(defenderId)],
      characterSps: [CharStats.getSp(attackerId), CharStats.getSp(defenderId)],
      barriers: barriers,
      fames: fames,
      equipmentIds: _mergeEquipmentIds(attackerEquipmentIds, defenderEquipmentIds)
    });
    PvPExtraV3.set(pvpId, pvpExtra);
  }

  function _mergeEquipmentIds(
    uint256[6] memory attackerEquipmentIds,
    uint256[6] memory defenderEquipmentIds
  )
    private
    pure
    returns (uint256[12] memory equipmentIds)
  {
    for (uint256 i = 0; i < 6; i++) {
      equipmentIds[i] = attackerEquipmentIds[i];
      equipmentIds[i + 6] = defenderEquipmentIds[i];
    }
    return equipmentIds;
  }

  /// @dev _performFight returns fight result,
  /// hps is final hp of attacker and defender
  /// skills the corresponding skills used by both players in the battle
  function _performFight(
    uint256 attackerId,
    uint256 defenderId,
    uint256[5] memory attackerSkills,
    uint256[5] memory defenderSkills,
    uint32[2] memory originHps
  )
    private
    view
    returns (uint256 firstAttackerId, uint32[2] memory hps, uint32[11] memory damages, uint256[11] memory skills)
  {
    // Build battle information for attacker and defender
    BattleInfo memory attackerBattleInfo =
      BattleUtils.buildCharacterBattleInfo(attackerId, attackerSkills, originHps[0]);
    BattleInfo memory defenderBattleInfo =
      BattleUtils.buildCharacterBattleInfo(defenderId, defenderSkills, originHps[1]);

    // Determine the first attacker based on agility
    if (attackerBattleInfo.agi >= defenderBattleInfo.agi) {
      firstAttackerId = attackerId;
      (hps, damages) = BattleUtils.fight(attackerBattleInfo, defenderBattleInfo);
      skills = _usedSkillsOrder(attackerSkills, defenderSkills);
    } else {
      firstAttackerId = defenderId;
      (hps, damages) = BattleUtils.fight(defenderBattleInfo, attackerBattleInfo);
      // hps now is [defenderHP, attackerHP], we need to revert it to [attackerHP, defenderHP]
      (hps[0], hps[1]) = (hps[1], hps[0]);
      skills = _usedSkillsOrder(defenderSkills, attackerSkills);
    }

    return (firstAttackerId, hps, damages, skills);
  }

  function _usedSkillsOrder(
    uint256[5] memory firstAttackerSkills,
    uint256[5] memory secondAttackerSkills
  )
    private
    pure
    returns (uint256[11] memory skills)
  {
    uint256 index = 0;
    skills[index++] = Config.NORMAL_ATTACK_SKILL_ID;

    for (uint256 i = 0; i < 5; i++) {
      skills[index++] = firstAttackerSkills[i];
      skills[index++] = secondAttackerSkills[i];
    }
    return skills;
  }

  function _checkIsReadyToBattle(uint256 attackerId, uint256 defenderId) private view {
    uint256 nextAttackTime = CharBattle.getPvpLastAtkTime(attackerId) + Config.ATTACK_COOLDOWN;
    if (block.timestamp < nextAttackTime) {
      revert Errors.PvP_NotReadyToAttack(nextAttackTime);
    }
    // uint256 nextTimeToBeAttacked = CharBattle.getPvpLastDefTime(defenderId) + Config.PROTECTION_DURATION;
    // if (block.timestamp < nextTimeToBeAttacked) {
    //   revert Errors.PvP_NotReadyToBeAttacked(nextTimeToBeAttacked);
    // }
  }

  function _getOriginHps(
    uint256 attackerId,
    uint256 defenderId,
    bool isChallenge
  )
    private
    view
    returns (uint32[2] memory hps)
  {
    return isChallenge
      ? [CharStats.getHp(attackerId), CharStats.getHp(defenderId)]
      : [CharCurrentStats.getHp(attackerId), CharCurrentStats.getHp(defenderId)];
  }
}
