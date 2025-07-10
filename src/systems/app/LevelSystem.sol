pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import {
  CharStats,
  CharStatsData,
  CharCurrentStats,
  CharCurrentStatsData,
  CharBaseStats,
  CharBaseStatsData,
  CharPerk,
  CharPerkData,
  CharReborn
} from "@codegen/index.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharacterStatsUtils } from "@utils/CharacterStatsUtils.sol";
import { QuestStatusType, QuestType, StatType, ItemType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";
import { IncreaseStatData } from "./LevelSystem.sol";

struct IncreaseStatData {
  StatType statType;
  uint16 amount;
}

contract LevelSystem is System, CharacterAccessControl {
  /// @dev level up
  function levelUp(uint256 characterId, uint16 amount) public {
    if (amount == 0) {
      revert Errors.LevelSystem_InvalidLevelAmount(amount);
    }
    CharStatsData memory characterStats = CharStats.get(characterId);
    uint16 currentLevel = characterStats.level;
    uint16 toLevel = currentLevel + amount;
    if (toLevel > Config.MAX_LEVEL) {
      revert Errors.LevelSystem_ExceedMaxLevel(Config.MAX_LEVEL, toLevel);
    }

    CharCurrentStatsData memory characterCurrentStats = CharCurrentStats.get(characterId);
    uint32 currentExp = characterCurrentStats.exp;
    uint32 requiredExp = _calculateRequiredExp(characterId, currentLevel, toLevel);

    if (requiredExp > currentExp) {
      revert Errors.LevelSystem_InsufficientExp(currentLevel, toLevel, requiredExp, currentExp);
    }
    // update level and exp
    characterStats.level = toLevel;
    characterCurrentStats.exp = currentExp - requiredExp;

    // update stats
    CharBaseStatsData memory characterBaseStats = CharBaseStats.get(characterId);
    // pointsPerLevel is increasing for each 25 levels ([1,25] is 1; [26:50] is 2, ...)
    // current level starts from 1 so currentLevel - 1 is safe
    uint16 pointsPerLevel = (currentLevel - 1) / 25 + 1;
    for (uint16 i = currentLevel + 1; i <= toLevel; i++) {
      if (i % 5 == 0) {
        characterCurrentStats.atk++;
        characterBaseStats.atk++;
        characterCurrentStats.def++;
        characterBaseStats.def++;
        characterCurrentStats.agi++;
        characterBaseStats.agi++;
      }
      if (i % 25 == 1) {
        // adjust pointsPerLevel at the start of each new tier (26, 51, 76 ...)
        pointsPerLevel++;
      }
      characterStats.statPoint += pointsPerLevel;
    }
    characterStats.hp += amount * uint32(Config.HP_GAIN_PER_LEVEL);
    characterCurrentStats.hp = characterStats.hp; // level up will help recover to max hp
    CharStats.set(characterId, characterStats);
    CharCurrentStats.set(characterId, characterCurrentStats);
    CharBaseStats.set(characterId, characterBaseStats);
  }

  /// @dev level up perk of given item types
  function levelUpPerk(uint256 characterId, ItemType itemType, uint8 amount) public onlyAuthorizedWallet(characterId) {
    if (amount == 0) {
      revert Errors.LevelSystem_InvalidPerkLevelAmount(itemType, amount);
    }
    CharPerkData memory characterPerk = CharPerk.get(characterId, itemType);
    uint8 currentLevel = characterPerk.level;
    uint8 toLevel = currentLevel + amount;
    if (toLevel > Config.MAX_PERK_LEVEL) {
      revert Errors.LevelSystem_ExceedMaxPerkLevel(Config.MAX_PERK_LEVEL, toLevel);
    }
    uint32 requiredExp = _calculateRequiredPerkExp(currentLevel, toLevel);
    if (characterPerk.exp < requiredExp) {
      revert Errors.LevelSystem_InsufficientPerkExp(currentLevel, toLevel, requiredExp, characterPerk.exp);
    }
    characterPerk.level = toLevel;
    characterPerk.exp -= requiredExp;
    CharPerk.set(characterId, itemType, characterPerk);
  }

  function increaseStats(
    uint256 characterId,
    IncreaseStatData[] calldata datas
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    uint16 statPoint = CharStats.getStatPoint(characterId);
    for (uint256 i = 0; i < datas.length; i++) {
      if (datas[i].amount == 0) {
        revert Errors.Stats_InvalidAmount(datas[i].amount);
      }
      statPoint = _increaseStat(characterId, statPoint, datas[i]);
    }
    CharStats.setStatPoint(characterId, statPoint);
  }

  function _increaseStat(
    uint256 characterId,
    uint16 statPoint,
    IncreaseStatData calldata data
  )
    private
    returns (uint16)
  {
    uint16 currentBaseStat = CharacterStatsUtils.getBaseStatByStatType(characterId, data.statType);
    uint16 toBaseStat = currentBaseStat + data.amount;
    // if (toBaseStat > Config.MAX_BASE_STAT) {
    //   revert Errors.Stats_ExceedMaxBaseStat(data.statType, Config.MAX_BASE_STAT, toBaseStat);
    // }
    uint16 totalPointToUse;
    uint16 pointPerStat = 1;
    if (currentBaseStat > 0) {
      pointPerStat = (currentBaseStat - 1) / 25 + 1;
    }
    for (uint16 i = currentBaseStat + 1; i <= toBaseStat; i++) {
      if (i > 25 && i % 25 == 1) {
        pointPerStat++;
      }
      totalPointToUse += pointPerStat;
    }
    if (statPoint < totalPointToUse) {
      revert Errors.Stats_NotEnoughPoint(data.statType, currentBaseStat, toBaseStat, statPoint);
    }
    // set base stat
    CharacterStatsUtils.setBaseStatByStatType(characterId, data.statType, toBaseStat);
    // update stat
    uint16 currentStat = CharacterStatsUtils.getStatByStatType(characterId, data.statType);
    uint16 toStat = currentStat + data.amount;
    CharacterStatsUtils.setStatByStatType(characterId, data.statType, toStat);
    return statPoint - totalPointToUse;
  }

  function _calculateRequiredExp(
    uint256 characterId,
    uint16 currentLevel,
    uint16 toLevel
  )
    private
    view
    returns (uint32 requiredExp)
  {
    for (uint16 i = currentLevel + 1; i <= toLevel; i++) {
      uint32 calcNum = i - 1;
      requiredExp += calcNum * 20 + calcNum * calcNum * calcNum / 5;
    }
    uint32 rebornNum = uint32(CharReborn.get(characterId));
    if (rebornNum > 0) {
      // each time the character is reborn, the required exp increases by 10%
      requiredExp = requiredExp * (rebornNum * 10 + 100) / 100;
    }
  }

  function _calculateRequiredPerkExp(uint8 currentLevel, uint8 toLevel) private pure returns (uint32 requiredExp) {
    for (uint8 i = currentLevel + 1; i <= toLevel; i++) {
      // character perk starts from 0 so we don't use i - 1
      if (i >= 6) {
        requiredExp += uint32(1000) * i * i * i;
      } else {
        requiredExp += uint32(750) * i * i * i;
      }
    }
  }
}
