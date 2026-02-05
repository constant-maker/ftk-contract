pragma solidity >=0.8.24;

import {
  CharBuff,
  CharBuffData,
  CharDebuff,
  CharDebuffData,
  BuffStatV4,
  BuffStatV4Data,
  BuffItemInfoV3,
  CharCurrentStats,
  CharCurrentStatsData
} from "@codegen/index.sol";
import { BuffType } from "@codegen/common.sol";
import { PvPUtils } from "./PvPUtils.sol";
import { Config } from "@common/index.sol";

library CharacterBuffUtils {
  /// @dev Remove all buffs from character (e.g. on death)
  function dispelAllBuff(uint256 characterId) public {
    CharBuff.deleteRecord(characterId);
    CharDebuffData memory debuffData = CharDebuff.get(characterId);
    for (uint256 i = 0; i < debuffData.debuffIds.length; i++) {
      if (debuffData.debuffIds[i] == Config.LOW_FAME_DEBUFF_ID) continue; // This is permanent debuff for PvP
      debuffData.debuffIds[i] = 0;
      debuffData.expireTimes[i] = 0;
    }
    CharDebuff.set(characterId, debuffData);
  }

  /// @dev Get total buff speed (can be negative)
  function getBuffSpeed(uint256 characterId) public view returns (int16) {
    CharBuffData memory charBuff = CharBuff.get(characterId);
    int16 speedBuff = 0; // wider accumulator to prevent overflow

    for (uint256 i = 0; i < charBuff.buffIds.length; i++) {
      if (charBuff.expireTimes[i] < block.timestamp) continue;

      uint256 buffId = charBuff.buffIds[i];
      if (buffId == 0) continue;

      if (BuffItemInfoV3.getBuffType(buffId) != BuffType.StatsModify) continue;

      int16 buffSpeed = BuffStatV4.getMs(buffId);
      speedBuff += buffSpeed;
    }

    CharDebuffData memory charDebuff = CharDebuff.get(characterId);
    for (uint256 i = 0; i < charDebuff.debuffIds.length; i++) {
      if (charDebuff.expireTimes[i] < block.timestamp) continue;

      uint256 debuffId = charDebuff.debuffIds[i];
      if (debuffId == 0) continue;

      if (BuffItemInfoV3.getBuffType(debuffId) != BuffType.StatsModify) continue;
      int16 debuffSpeed = BuffStatV4.getMs(debuffId);
      speedBuff += debuffSpeed;
    }

    return speedBuff;
  }

  /// @dev Get total slow debuff speed (percent - positive value)
  function getSlowDebuff(uint256 characterId) public view returns (uint16) {
    uint16 slowDebuff = 0;

    CharDebuffData memory charDebuff = CharDebuff.get(characterId);
    for (uint256 i = 0; i < charDebuff.debuffIds.length; i++) {
      if (charDebuff.expireTimes[i] < block.timestamp) continue;

      uint256 debuffId = charDebuff.debuffIds[i];
      if (debuffId == 0) continue;

      if (BuffItemInfoV3.getBuffType(debuffId) != BuffType.StatsModify) continue;
      slowDebuff += BuffStatV4.getSlowPercent(debuffId);
    }

    return slowDebuff;
  }

  /// @dev Get total buff stats (can be negative)
  function getBuffStats(uint256 characterId) public view returns (int16 atk, int16 def, int16 agi) {
    CharBuffData memory charBuff = CharBuff.get(characterId);
    // percent like -120 => minus 120%
    int16 totalAtkPercent = 0;
    int16 totalDefPercent = 0;
    int16 totalAgiPercent = 0;
    for (uint256 i = 0; i < charBuff.buffIds.length; i++) {
      if (charBuff.expireTimes[i] < block.timestamp) continue;

      uint256 buffId = charBuff.buffIds[i];
      if (buffId == 0) continue;

      if (BuffItemInfoV3.getBuffType(buffId) != BuffType.StatsModify) continue;
      BuffStatV4Data memory statBuff = BuffStatV4.get(buffId);
      totalAtkPercent += statBuff.atkPercent;
      totalDefPercent += statBuff.defPercent;
      totalAgiPercent += statBuff.agiPercent;
    }
    CharDebuffData memory charDebuff = CharDebuff.get(characterId);
    for (uint256 i = 0; i < charDebuff.debuffIds.length; i++) {
      if (charDebuff.expireTimes[i] < block.timestamp) continue;

      uint256 debuffId = charDebuff.debuffIds[i];
      if (debuffId == 0) continue;

      if (BuffItemInfoV3.getBuffType(debuffId) != BuffType.StatsModify) continue;
      BuffStatV4Data memory statDebuff = BuffStatV4.get(debuffId);
      // buff or debuff, just accumulate, final calculation will handle positive/negative
      // we have both buff and debuff loop to separate the two effects so they will not be replace each other
      totalAtkPercent += statDebuff.atkPercent;
      totalDefPercent += statDebuff.defPercent;
      totalAgiPercent += statDebuff.agiPercent;
    }
    CharCurrentStatsData memory currentStats = CharCurrentStats.get(characterId);
    atk = _getFinalBuffStat(currentStats.atk, totalAtkPercent);
    def = _getFinalBuffStat(currentStats.def, totalDefPercent);
    agi = _getFinalBuffStat(currentStats.agi, totalAgiPercent);
  }

  /// @dev Get buff sp (can be negative)
  function getBuffSp(uint256 characterId) public view returns (int8 sp) {
    CharBuffData memory charBuff = CharBuff.get(characterId);
    sp = 0; // wider accumulator to prevent overflow
    for (uint256 i = 0; i < charBuff.buffIds.length; i++) {
      if (charBuff.expireTimes[i] < block.timestamp) continue;

      uint256 buffId = charBuff.buffIds[i];
      if (buffId == 0) continue;

      if (BuffItemInfoV3.getBuffType(buffId) != BuffType.StatsModify) continue;
      int8 buffSp = BuffStatV4.getSp(buffId);
      sp += buffSp;
    }
  }

  function _getFinalBuffStat(uint16 originStat, int16 percentChange) private pure returns (int16 buffStat) {
    if (percentChange == 0) return 0;

    uint16 calPercent = percentChange > 0 ? uint16(percentChange) : uint16(-percentChange);
    uint16 change = uint16(uint32(originStat) * uint32(calPercent) / 100);

    // if currentStats.atk/def/agi > 0, and buff percent > 0, the change will be at least 1 unit
    // so we ensure that the buff will have some effect and final stat will not be negative
    // e.g. current atk = 1, buff atkPercent = 10%, final atk = 1 + 1 = 2
    // e.g. current atk = 1, debuff atkPercent = 10%, final atk = 1 - 1 = 0

    if (originStat > 0 && change == 0) {
      change = 1; // ensure at least 1 unit change
    }

    return percentChange > 0 ? int16(change) : -int16(change);
  }
}
