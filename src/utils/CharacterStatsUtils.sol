pragma solidity >=0.8.24;

import { Equipment, EquipmentInfo, EquipmentInfoData, EquipmentInfo3 } from "@codegen/index.sol";
import { CharStats, CharStatsData, CharCurrentStats, CharCurrentStatsData, CharBaseStats } from "@codegen/index.sol";
import { CharEquipStats, CharEquipStatsData } from "@codegen/tables/CharEquipStats.sol";
import { StatType, SlotType } from "@codegen/common.sol";
import { Errors, Config } from "@common/index.sol";

library CharacterStatsUtils {
  function validateCurrentWeight(uint256 characterId) internal view {
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);
    uint32 maxWeight = CharStats.getWeight(characterId);
    if (currentWeight > maxWeight) {
      revert Errors.Character_WeightsExceed(currentWeight, maxWeight);
    }
  }

  function validateWeight(uint256 characterId, uint32 plusWeight) internal view {
    uint32 newWeight = CharCurrentStats.getWeight(characterId) + plusWeight;
    uint32 maxWeight = CharStats.getWeight(characterId);
    if (newWeight > maxWeight) {
      revert Errors.Character_WeightsExceed(newWeight, maxWeight);
    }
  }

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

  function restoreHp(uint256 characterId, uint32 gainedHp) internal {
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

  function removeEquipment(uint256 characterId, uint256 equipmentId, SlotType slotType) internal {
    _updateWithEquipmentStats(characterId, equipmentId, slotType, true);
  }

  function addEquipment(uint256 characterId, uint256 equipmentId, SlotType slotType) internal {
    _updateWithEquipmentStats(characterId, equipmentId, slotType, false);
    _snapshotStats(characterId, equipmentId, slotType);
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
    EquipmentInfoData memory equipmentInfo = _getSnapshotEquipmentStats(characterId, slotType, itemId, isRemoved);

    if (equipmentInfo.hp > 0) {
      uint32 maxHp = CharStats.getHp(characterId);
      uint32 currentHp = characterCurrentStats.hp;
      maxHp = isRemoved ? maxHp - equipmentInfo.hp : maxHp + equipmentInfo.hp;
      CharStats.setHp(characterId, maxHp);
      if (currentHp >= maxHp) {
        // if current hp is greater than or equal to max hp, set it to max hp
        characterCurrentStats.hp = maxHp;
      }
    }
    if (slotType == SlotType.Mount) {
      _updateMaxWeightWithEquipment(characterId, itemId, isRemoved);
    }

    if (isRemoved) {
      characterCurrentStats.ms -= equipmentInfo.ms;
      characterCurrentStats.atk -= equipmentInfo.atk;
      characterCurrentStats.def -= equipmentInfo.def;
      characterCurrentStats.agi -= equipmentInfo.agi;
    } else {
      characterCurrentStats.ms += equipmentInfo.ms;
      characterCurrentStats.atk += equipmentInfo.atk;
      characterCurrentStats.def += equipmentInfo.def;
      characterCurrentStats.agi += equipmentInfo.agi;
    }

    CharCurrentStats.set(characterId, characterCurrentStats);
  }

  function _updateMaxWeightWithEquipment(uint256 characterId, uint256 itemId, bool isRemoved) private {
    uint32 bonusWeight = EquipmentInfo3.getBonusWeight(itemId);
    if (bonusWeight == 0) {
      return;
    }
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

  function _getSnapshotEquipmentStats(
    uint256 characterId,
    SlotType slotType,
    uint256 itemId,
    bool isRemoved
  )
    private
    view
    returns (EquipmentInfoData memory equipmentInfo)
  {
    if (!isRemoved) return EquipmentInfo.get(itemId);
    CharEquipStatsData memory charEquipStats = CharEquipStats.get(characterId, slotType);
    equipmentInfo.hp = charEquipStats.hp;
    equipmentInfo.atk = charEquipStats.atk;
    equipmentInfo.def = charEquipStats.def;
    equipmentInfo.agi = charEquipStats.agi;
    equipmentInfo.ms = charEquipStats.ms;
    return equipmentInfo;
  }

  function _snapshotStats(uint256 characterId, uint256 equipmentId, SlotType slotType) private {
    uint256 itemId = Equipment.getItemId(equipmentId);
    EquipmentInfoData memory equipmentInfo = EquipmentInfo.get(itemId);
    CharEquipStatsData memory charEquipStats = CharEquipStatsData({
      hp: equipmentInfo.hp,
      atk: equipmentInfo.atk,
      def: equipmentInfo.def,
      agi: equipmentInfo.agi,
      ms: equipmentInfo.ms
    });
    CharEquipStats.set(characterId, slotType, charEquipStats);
  }
}
