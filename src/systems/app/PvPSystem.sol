pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharPosition,
  CharPositionData,
  CharCurrentStats,
  CharStats,
  CharBattle,
  PvP,
  PvPData,
  PvPChallenge,
  PvPChallengeData,
  PvPExtra,
  PvPExtraData,
  PvPBattleCounter,
  TileInfo3,
  CharInfo,
  CharStats2,
  AllianceV2,
  AllianceV2Data
} from "@codegen/index.sol";
import { BattleInfo, BattleUtils } from "@utils/BattleUtils.sol";
import { DailyQuestUtils, InventoryItemUtils, CharacterPositionUtils } from "@utils/index.sol";
import { CharacterStateType, ZoneType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";

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
    // _checkIsReadyToBattle(attackerId, defenderId);

    (uint32 attackerHp, uint32 defenderHp) = _battle(attackerId, defenderId, false);

    _updateCharacterFame(attackerId, attackerHp, defenderId, defenderHp, attackerPosition);
    _handleBattleResult(attackerId, attackerHp, attackerPosition);
    _handleBattleResult(defenderId, defenderHp, defenderPosition);

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
      // no need to update fame if both characters are alive
      return;
    }
    uint32 attackerFame = CharStats2.getFame(attackerId);
    uint8 attackerKingdomId = CharInfo.getKingdomId(attackerId);
    uint8 defenderKingdomId = CharInfo.getKingdomId(defenderId);
    uint8 tileKingdomId = TileInfo3.getKingdomId(position.x, position.y);
    ZoneType zoneType = TileInfo3.getZoneType(position.x, position.y); // for defender
    if (zoneType == ZoneType.Black && defenderKingdomId == tileKingdomId) {
      zoneType = ZoneType.Red;
    } else if (zoneType != ZoneType.Black) {
      zoneType = (defenderKingdomId == tileKingdomId) ? ZoneType.Green : ZoneType.Red;
    }
    AllianceV2Data memory allianceData = AllianceV2.get(attackerKingdomId, defenderKingdomId);
    bool isAlliance = allianceData.isAlliance && allianceData.isApproved;
    if (!isAlliance) {
      allianceData = AllianceV2.get(defenderKingdomId, attackerKingdomId);
      isAlliance = allianceData.isAlliance && allianceData.isApproved;
    }
    if (isAlliance && attackerKingdomId == tileKingdomId) {
      zoneType = ZoneType.Green;
    }
    bool isSameSide = (attackerKingdomId == defenderKingdomId && tileKingdomId == attackerKingdomId) || isAlliance;
    if (isSameSide && defenderHp == 0 && zoneType == ZoneType.Green) {
      attackerFame = attackerFame > 50 ? attackerFame - 50 : 1; // min is 1
      CharStats2.set(attackerId, attackerFame);
      return;
    }
    uint32 defenderFame = CharStats2.getFame(defenderId);
    if (attackerHp == 0 && attackerFame >= 1020) {
      attackerFame -= 20;
      defenderFame += 20;
      CharStats2.set(defenderId, defenderFame);
      CharStats2.set(attackerId, attackerFame);
    } else if (defenderHp == 0 && defenderFame >= 1020 && zoneType != ZoneType.Green) {
      attackerFame += 20;
      defenderFame -= 20;
      CharStats2.set(defenderId, defenderFame);
      CharStats2.set(attackerId, attackerFame);
    }
  }

  function _handleBattleResult(uint256 characterId, uint32 characterHp, CharPositionData memory position) private {
    if (characterHp == 0) {
      CharacterPositionUtils.moveToCapital(characterId);
      CharCurrentStats.setHp(characterId, CharStats.getHp(characterId)); // set character hp to max hp
      BattleUtils.applyLoss(characterId, position);
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
    PvPExtraData memory pvpExtra = PvPExtraData({
      characterLevels: [CharStats.getLevel(attackerId), CharStats.getLevel(defenderId)],
      characterSps: [CharStats.getSp(attackerId), CharStats.getSp(defenderId)],
      equipmentIds: _mergeEquipmentIds(attackerEquipmentIds, defenderEquipmentIds)
    });
    PvPExtra.set(pvpId, pvpExtra);
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

  // function _checkIsReadyToBattle(uint256 attackerId, uint256 defenderId) private view {
  //   uint256 nextAttackTime = CharBattle.getPvpLastAtkTime(attackerId) + Config.ATTACK_COOLDOWN;
  //   if (block.timestamp < nextAttackTime) {
  //     revert Errors.PvP_NotReadyToAttack(nextAttackTime);
  //   }
  //   uint256 nextTimeToBeAttacked = CharBattle.getPvpLastDefTime(defenderId) + Config.PROTECTION_DURATION;
  //   if (block.timestamp < nextTimeToBeAttacked) {
  //     revert Errors.PvP_NotReadyToBeAttacked(nextTimeToBeAttacked);
  //   }
  // }

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
