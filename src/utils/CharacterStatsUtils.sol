pragma solidity >=0.8.24;

import {
  CharStats,
  CharCurrentStats,
  CharCurrentStatsData,
  CharBaseStats,
  Equipment,
  EquipmentInfo,
  EquipmentInfoData,
  EquipmentInfo2,
  EquipmentInfo2Data,
  CharReborn,
  Item,
  CharEquipmentCache,
  CharEquipmentCacheData,
  EPetStats,
  EPetStatsData
} from "@codegen/index.sol";
import { StatType, SlotType, ItemType } from "@codegen/common.sol";
import { Errors, Config } from "@common/index.sol";

library CharacterStatsUtils {
  /// @dev calculate the required exp to level up
  function calculateRequiredExp(
    uint256 characterId,
    uint16 currentLevel,
    uint16 toLevel
  )
    internal
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

  /// @dev validate current weight of character, revert if current weight exceed max weight
  function validateCurrentWeight(uint256 characterId) internal view {
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);
    uint32 maxWeight = CharStats.getWeight(characterId);
    if (currentWeight > maxWeight) {
      revert Errors.Character_WeightsExceed(currentWeight, maxWeight);
    }
  }

  /// @dev validate weight after adding new weight, revert if new weight exceed max weight
  function validateWeight(uint256 characterId, uint32 plusWeight) internal view {
    uint32 newWeight = CharCurrentStats.getWeight(characterId) + plusWeight;
    uint32 maxWeight = CharStats.getWeight(characterId);
    if (newWeight > maxWeight) {
      revert Errors.Character_WeightsExceed(newWeight, maxWeight);
    }
  }

  /// @dev update char exp
  function updateExp(uint256 characterId, uint32 exp, bool isGained) internal {
    uint32 currentExp = CharCurrentStats.getExp(characterId);
    uint32 newExp;
    if (isGained) {
      newExp = currentExp + exp;
    } else {
      if (currentExp > exp) {
        newExp = currentExp - exp;
      } else {
        newExp = 0;
      }
    }
    CharCurrentStats.setExp(characterId, newExp);
  }

  /// @dev restore hp for character, the new hp will not exceed max hp
  function restoreHp(uint256 characterId, uint32 gainedHp) internal {
    if (gainedHp == 0) return;
    uint32 maxHp = CharStats.getHp(characterId);
    uint32 currentHp = CharCurrentStats.getHp(characterId);
    uint32 newHp = currentHp + gainedHp;
    if (newHp > maxHp) {
      newHp = maxHp;
    }
    CharCurrentStats.setHp(characterId, newHp);
  }

  function setStatByStatType(uint256 characterId, StatType statType, uint16 value) internal {
    if (statType == StatType.ATK) {
      CharCurrentStats.setAtk(characterId, value);
    } else if (statType == StatType.DEF) {
      CharCurrentStats.setDef(characterId, value);
    } else if (statType == StatType.AGI) {
      CharCurrentStats.setAgi(characterId, value);
    } else {
      revert Errors.Stats_InvalidStatType(statType);
    }
  }

  /// @dev set new hp if it's != current hp
  function setNewHp(uint256 characterId, uint32 newHp) internal {
    uint32 currentHp = CharCurrentStats.getHp(characterId);
    if (currentHp != newHp) {
      CharCurrentStats.setHp(characterId, newHp);
    }
  }

  /// @dev get stat by stat type (ATK, DEF, AGI)
  function getStatByStatType(uint256 characterId, StatType statType) internal view returns (uint16) {
    if (statType == StatType.ATK) {
      return CharCurrentStats.getAtk(characterId);
    } else if (statType == StatType.DEF) {
      return CharCurrentStats.getDef(characterId);
    } else if (statType == StatType.AGI) {
      return CharCurrentStats.getAgi(characterId);
    } else {
      revert Errors.Stats_InvalidStatType(statType);
    }
  }

  /// @dev set base stat by stat type (ATK, DEF, AGI)
  function setBaseStatByStatType(uint256 characterId, StatType statType, uint16 value) internal {
    if (statType == StatType.ATK) {
      CharBaseStats.setAtk(characterId, value);
    } else if (statType == StatType.DEF) {
      CharBaseStats.setDef(characterId, value);
    } else if (statType == StatType.AGI) {
      CharBaseStats.setAgi(characterId, value);
    } else {
      revert Errors.Stats_InvalidStatType(statType);
    }
  }

  /// @dev get base stat by stat type (ATK, DEF, AGI)
  function getBaseStatByStatType(uint256 characterId, StatType statType) internal view returns (uint16) {
    if (statType == StatType.ATK) {
      return CharBaseStats.getAtk(characterId);
    } else if (statType == StatType.DEF) {
      return CharBaseStats.getDef(characterId);
    } else if (statType == StatType.AGI) {
      return CharBaseStats.getAgi(characterId);
    } else {
      revert Errors.Stats_InvalidStatType(statType);
    }
  }

  /// @dev remove equipment stats from character current stats, use the snapshot stats to update
  function removeEquipment(uint256 characterId, uint256 equipmentId, SlotType slotType) internal {
    _updateWithEquipmentStats(characterId, equipmentId, slotType, true);
  }

  /// @dev add equipment stats to character current stats,
  function addEquipment(uint256 characterId, uint256 equipmentId, SlotType slotType) internal {
    // we snapshot the equipment stats when equip equipment,
    // so we can use the snapshot to update character stats when unequip or remove equipment,
    // no need to calculate the stats again which will save gas,
    // and also avoid the issue of change the item stats
    _snapshotEquipmentStats(characterId, equipmentId, slotType);
    _updateWithEquipmentStats(characterId, equipmentId, slotType, false);
  }

  function _updateWithEquipmentStats(
    uint256 characterId,
    uint256 equipmentId,
    SlotType slotType,
    bool isRemoved
  )
    private
  {
    uint256 itemId = Equipment.getItemId(equipmentId);
    if (itemId == 0) {
      return;
    }

    CharCurrentStatsData memory characterCurrentStats = CharCurrentStats.get(characterId);
    CharEquipmentCacheData memory equipmentSnapshot = CharEquipmentCache.get(characterId, slotType);

    if (equipmentSnapshot.hp > 0) {
      uint32 maxHp = CharStats.getHp(characterId);
      uint32 currentHp = characterCurrentStats.hp;
      maxHp = isRemoved ? maxHp - equipmentSnapshot.hp : maxHp + equipmentSnapshot.hp;
      CharStats.setHp(characterId, maxHp);
      if (currentHp > maxHp) {
        // if current hp is greater than max hp, set it to max hp
        characterCurrentStats.hp = maxHp;
      }
    }
    // only mount equipment has weight, and weight will affect max weight of character,
    // so we need to update max weight when equip or unequip mount equipment
    if (slotType == SlotType.Mount) {
      _updateMaxWeightWithEquipment(characterId, equipmentSnapshot.weight, isRemoved);
    }

    if (isRemoved) {
      characterCurrentStats.ms -= equipmentSnapshot.ms;
      characterCurrentStats.atk -= equipmentSnapshot.atk;
      characterCurrentStats.def -= equipmentSnapshot.def;
      characterCurrentStats.agi -= equipmentSnapshot.agi;
      characterCurrentStats.barrier -= equipmentSnapshot.barrier;
    } else {
      characterCurrentStats.ms += equipmentSnapshot.ms;
      characterCurrentStats.atk += equipmentSnapshot.atk;
      characterCurrentStats.def += equipmentSnapshot.def;
      characterCurrentStats.agi += equipmentSnapshot.agi;
      characterCurrentStats.barrier += equipmentSnapshot.barrier;
    }

    CharCurrentStats.set(characterId, characterCurrentStats);
  }

  function _updateMaxWeightWithEquipment(uint256 characterId, uint32 bonusWeight, bool isRemoved) private {
    if (bonusWeight == 0) return;
    uint32 currentMaxWeight = CharStats.getWeight(characterId);
    uint32 newMaxWeight;
    if (isRemoved) {
      if (currentMaxWeight < bonusWeight + Config.DEFAULT_WEIGHT) {
        // This case should never happen, but safe fallback
        newMaxWeight = Config.DEFAULT_WEIGHT;
      } else {
        newMaxWeight = currentMaxWeight - bonusWeight;
      }
    } else {
      newMaxWeight = currentMaxWeight + bonusWeight;
    }
    CharStats.setWeight(characterId, newMaxWeight);
  }

  /// @dev Get equipment stats and snapshot them for the character.
  function _snapshotEquipmentStats(uint256 characterId, uint256 equipmentId, SlotType slotType) private {
    CharEquipmentCacheData memory equipmentSnapshot = _getUpgradedEquipmentStats(equipmentId);
    CharEquipmentCache.set(characterId, slotType, equipmentSnapshot);
  }

  /// @dev Get the upgraded equipment stats for a given equipment ID. Higher level equipment provides better stats.
  function _getUpgradedEquipmentStats(uint256 equipmentId)
    private
    view
    returns (CharEquipmentCacheData memory equipmentSnapshot)
  {
    uint256 itemId = Equipment.getItemId(equipmentId);
    if (itemId == 0) {
      revert Errors.Equipment_NotExisted(equipmentId);
    }
    EquipmentInfoData memory equipmentInfo = EquipmentInfo.get(itemId);
    if (Item.getItemType(itemId) == ItemType.Pet) {
      // pet stats will take from this table
      EPetStatsData memory petStats = EPetStats.get(itemId);
      // replace equipment info with pet stats for pet equipment, only atk, def, agi
      equipmentInfo.atk = petStats.atk;
      equipmentInfo.def = petStats.def;
      equipmentInfo.agi = petStats.agi;
    }
    EquipmentInfo2Data memory equipmentInfo2 = EquipmentInfo2.get(itemId);
    uint8 level = Equipment.getLevel(equipmentId);

    if (level == 1) {
      equipmentSnapshot = CharEquipmentCacheData({
        hp: equipmentInfo.hp,
        barrier: equipmentInfo2.shieldBarrier,
        weight: equipmentInfo2.bonusWeight,
        atk: equipmentInfo.atk,
        def: equipmentInfo.def,
        agi: equipmentInfo.agi,
        ms: equipmentInfo.ms
      });

      return equipmentSnapshot;
    }

    // bonus stats
    uint16 percentGain = _getStatBonusPercent(itemId, level);
    uint16 multiplier = 100 + percentGain;

    equipmentSnapshot = CharEquipmentCacheData({
      barrier: _calculateNewStat(equipmentInfo2.shieldBarrier, multiplier, level),
      hp: _calculateNewStat(equipmentInfo.hp, multiplier, level),
      atk: uint16(_calculateNewStat(equipmentInfo.atk, multiplier, level)),
      def: uint16(_calculateNewStat(equipmentInfo.def, multiplier, level)),
      agi: uint16(_calculateNewStat(equipmentInfo.agi, multiplier, level)),
      ms: equipmentInfo.ms, // unchanged
      weight: _calculateNewStat(equipmentInfo2.bonusWeight, multiplier, level)
    });

    return equipmentSnapshot;
  }

  function _calculateNewStat(uint32 originStat, uint16 mul, uint8 level) private pure returns (uint32) {
    if (originStat == 0) return 0;
    if (originStat < 8) {
      // some equipment has very low dmg, so the % will be 0
      // max at level 3 now is 25% gain and 7 * 0.25 = 1.75 => 1 same as 7 * 0.15 = 1.05 => 1 (level 2)
      return originStat + (level - 1);
    }
    return (originStat * mul) / 100;
  }

  function _getStatBonusPercent(uint256 itemId, uint8 level) private view returns (uint16) {
    if (level <= 1) return 0;

    uint8 tier = Item.getTier(itemId);

    uint16 bonusPercent = sumOfArithmeticSeries(level - 1, 5, 5);

    if (tier > 7 && level >= 4) {
      bonusPercent += (level - 3) * 5 * (tier - 7);
    }

    return bonusPercent;
  }

  function sumOfArithmeticSeries(uint16 levelChange, uint16 base, uint16 step) internal pure returns (uint16) {
    uint16 sumBase = base * levelChange;
    uint16 sumStep = (step * levelChange * (levelChange + 1)) / 2;
    return sumBase + sumStep;
  }
}
