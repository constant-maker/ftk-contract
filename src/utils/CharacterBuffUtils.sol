pragma solidity >=0.8.24;

import {
  CharBuff,
  CharBuffData,
  BuffStatV2,
  BuffStatV2Data,
  BuffItemInfoV2,
  CharCurrentStats,
  CharCurrentStatsData
} from "@codegen/index.sol";
import { BuffType } from "@codegen/common.sol";

library CharacterBuffUtils {
  /// @dev Remove all buffs from character (e.g. on death)
  function dispelAllBuff(uint256 characterId) public {
    CharBuff.deleteRecord(characterId);
  }

  /// @dev Get total buff speed (can be negative)
  function getBuffSpeed(uint256 characterId) public view returns (int16) {
    CharBuffData memory charBuff = CharBuff.get(characterId);
    int16 speedBuff = 0; // wider accumulator to prevent overflow

    for (uint256 i = 0; i < charBuff.buffIds.length; i++) {
      if (charBuff.expireTimes[i] < block.timestamp) continue;

      uint256 buffId = charBuff.buffIds[i];
      if (buffId == 0) continue;

      if (BuffItemInfoV2.getBuffType(buffId) != BuffType.StatsModify) continue;

      int16 buffSpeed = BuffStatV2.getMs(buffId);
      speedBuff += buffSpeed;
    }

    return speedBuff;
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

      if (BuffItemInfoV2.getBuffType(buffId) != BuffType.StatsModify) continue;
      BuffStatV2Data memory statBuff = BuffStatV2.get(buffId);
      totalAtkPercent += statBuff.atkPercent;
      totalDefPercent += statBuff.defPercent;
      totalAgiPercent += statBuff.agiPercent;
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

      if (BuffItemInfoV2.getBuffType(buffId) != BuffType.StatsModify) continue;
      int8 buffSp = BuffStatV2.getSp(buffId);
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
