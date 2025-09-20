pragma solidity >=0.8.24;

import {
  CharBuff,
  CharBuffData,
  BuffStat,
  BuffStatData,
  BuffItemInfo,
  CharCurrentStats,
  CharCurrentStatsData
} from "@codegen/index.sol";
import { BuffType } from "@codegen/common.sol";

library CharacterBuffUtils {
  function getBuffSpeed(uint256 characterId) public view returns (int16) {
    CharBuffData memory charBuff = CharBuff.get(characterId);
    int16 speedBuff = 0; // wider accumulator to prevent overflow

    for (uint256 i = 0; i < charBuff.buffIds.length; i++) {
      if (charBuff.expireTimes[i] < block.timestamp) continue;

      uint256 buffId = charBuff.buffIds[i];
      if (buffId == 0) continue;

      if (BuffItemInfo.getBuffType(buffId) != BuffType.StatsModify) continue;

      uint16 buffSpeed = BuffStat.getMs(buffId);
      bool isGained = BuffStat.getIsGained(buffId);
      speedBuff += isGained ? int16(buffSpeed) : -int16(buffSpeed);
    }

    return speedBuff;
  }

  /// @dev Get total buff stats (can be negative)
  function getBuffStats(uint256 characterId) public view returns (int16 atk, int16 def, int16 agi) {
    CharCurrentStatsData memory currentStats = CharCurrentStats.get(characterId);
    CharBuffData memory charBuff = CharBuff.get(characterId);
    atk = 0; // wider accumulator to prevent overflow
    def = 0;
    agi = 0;
    for (uint256 i = 0; i < charBuff.buffIds.length; i++) {
      if (charBuff.expireTimes[i] < block.timestamp) continue;

      uint256 buffId = charBuff.buffIds[i];
      if (buffId == 0) continue;

      if (BuffItemInfo.getBuffType(buffId) != BuffType.StatsModify) continue;
      BuffStatData memory statBuff = BuffStat.get(buffId);
      // if currentStats.atk/def/agi > 0, and buff percent > 0, the change will be at least 1 unit
      // so we ensure that the buff will have some effect and final stat will not be negative
      // e.g. current atk = 1, buff atkPercent = 10%, final atk = 1 + 1 = 2
      // e.g. current atk = 1, debuff atkPercent = 10%, final atk = 1 - 1 = 0
      uint16 atkChange = uint16((uint32(currentStats.atk) * uint32(statBuff.atkPercent)) / 100);
      uint16 buffAtk = currentStats.atk > 0 && atkChange == 0 ? 1 : atkChange; // ensure at least 1 unit change
      uint16 defChange = uint16((uint32(currentStats.def) * uint32(statBuff.defPercent)) / 100);
      uint16 buffDef = currentStats.def > 0 && defChange == 0 ? 1 : defChange; // ensure at least 1 unit change
      uint16 agiChange = uint16((uint32(currentStats.agi) * uint32(statBuff.agiPercent)) / 100);
      uint16 buffAgi = currentStats.agi > 0 && agiChange == 0 ? 1 : agiChange; // ensure at least 1 unit change

      bool isGained = BuffStat.getIsGained(buffId);
      atk += isGained ? int16(buffAtk) : -int16(buffAtk);
      def += isGained ? int16(buffDef) : -int16(buffDef);
      agi += isGained ? int16(buffAgi) : -int16(buffAgi);
    }
  }

  /// @dev Get buff sp (can be negative)
  function getBuffSp(uint256 characterId) public view returns (int8 sp) {
    CharBuffData memory charBuff = CharBuff.get(characterId);
    sp = 0; // wider accumulator to prevent overflow
    for (uint256 i = 0; i < charBuff.buffIds.length; i++) {
      if (charBuff.expireTimes[i] < block.timestamp) continue;

      uint256 buffId = charBuff.buffIds[i];
      if (buffId == 0) continue;

      if (BuffItemInfo.getBuffType(buffId) != BuffType.StatsModify) continue;
      uint8 buffSp = BuffStat.getSp(buffId);
      bool isGained = BuffStat.getIsGained(buffId);
      sp += isGained ? int8(buffSp) : -int8(buffSp);
    }
  }
}
