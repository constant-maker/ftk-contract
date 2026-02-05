pragma solidity >=0.8.24;

import {
  CharPositionData, CharStats2, PvPBattleCounter, PvPEnemyCounter, PvPExtraV3, KingSetting
} from "@codegen/index.sol";
import { CharAchievementUtils } from "./CharAchievementUtils.sol";
import { ZoneInfo, KingdomUtils } from "./KingdomUtils.sol";
import { ConsumeUtils } from "./ConsumeUtils.sol";
import { ZoneType } from "@codegen/common.sol";
import { Config } from "@common/index.sol";

library PvPUtils {
  uint32 constant MIN_PROTECT_FAME = 500; // minimum fame to be protected in green zone
  uint32 constant GREEN_ZONE_FAME_PENALTY = 50;
  uint32 constant MIN_FAME = 1;
  uint32 constant LOST_FAME_PENALTY = 20;
  uint32 constant GAINED_FAME_REWARD = 10;
  uint32 constant MIN_FAME_THRESHOLD = 1070;

  function updateCharacterFame(
    uint256 attackerId,
    uint32 attackerHp,
    uint256 defenderId,
    uint32 defenderHp,
    CharPositionData memory position
  )
    public
  {
    if (attackerHp != 0 && defenderHp != 0) {
      return; // both alive, no fame change
    }
    int32 attackerFameChange = 0;
    int32 defenderFameChange = 0;
    uint32 attackerFame = CharStats2.getFame(attackerId);
    uint32 defenderFame = CharStats2.getFame(defenderId);
    ZoneInfo memory zoneInfo = KingdomUtils.getZoneTypeFull(position.x, position.y, attackerId, defenderId);
    bool isAlliance = KingdomUtils.getIsAlliance(zoneInfo.attackerKingdomId, zoneInfo.defenderKingdomId);

    // Apply alliance adjustment to zoneType (only if attacker owns tile)
    bool isSameSide = (
      zoneInfo.attackerKingdomId == zoneInfo.defenderKingdomId && zoneInfo.tileKingdomId == zoneInfo.attackerKingdomId
    ) || isAlliance;

    if (isSameSide && defenderHp == 0) {
      if (
        (zoneInfo.attackerZoneType == ZoneType.Green || zoneInfo.defenderZoneType == ZoneType.Green)
          && defenderFame > MIN_PROTECT_FAME
      ) {
        attackerFame = attackerFame > GREEN_ZONE_FAME_PENALTY ? attackerFame - GREEN_ZONE_FAME_PENALTY : MIN_FAME;
        CharStats2.set(attackerId, attackerFame);
        attackerFameChange = -int32(GREEN_ZONE_FAME_PENALTY);
      } else {
        uint32 famePenalty = KingSetting.getPvpFamePenalty(zoneInfo.attackerKingdomId);
        if (famePenalty > 0) {
          attackerFameChange = -int32(famePenalty);
          attackerFame = attackerFame > famePenalty ? attackerFame - famePenalty : MIN_FAME;
          CharStats2.set(attackerId, attackerFame);
        }
      }
      if (attackerFame < MIN_PROTECT_FAME) {
        // apply debuff to attacker
        _applyDebuff(attackerId);
      }
      _storeFameChange(attackerFameChange, 0, attackerId, defenderId);
      return;
    }

    if (zoneInfo.attackerKingdomId == zoneInfo.defenderKingdomId) return; // same kingdom, no fame change

    if (attackerHp == 0 && attackerFame >= MIN_FAME_THRESHOLD && zoneInfo.attackerZoneType != ZoneType.Green) {
      _setFame(attackerId, defenderId, -int32(LOST_FAME_PENALTY), int32(GAINED_FAME_REWARD)); // fame transfer from
        // attacker to defender
      _checkAndGiveAchievement(defenderId, zoneInfo);
    } else if (defenderHp == 0 && defenderFame >= MIN_FAME_THRESHOLD && zoneInfo.defenderZoneType != ZoneType.Green) {
      _setFame(attackerId, defenderId, int32(GAINED_FAME_REWARD), -int32(LOST_FAME_PENALTY)); // fame transfer from
        // defender to attacker
      _checkAndGiveAchievement(attackerId, zoneInfo);
    }
  }

  function _setFame(uint256 attackerId, uint256 defenderId, int32 attackerChange, int32 defenderChange) private {
    int32 attackerFameChange = attackerChange;
    int32 defenderFameChange = defenderChange;

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

  function _checkAndGiveAchievement(uint256 characterId, ZoneInfo memory zoneInfo) private {
    if (zoneInfo.attackerKingdomId == zoneInfo.defenderKingdomId) {
      return;
    }
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

  function _applyDebuff(uint256 characterId) private {
    ConsumeUtils.applyStatsBadBuff(characterId, Config.LOW_FAME_DEBUFF_ID);
  }
}
