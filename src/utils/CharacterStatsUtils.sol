pragma solidity >=0.8.24;

import {
  CharStats,
  CharStatsData,
  CharCurrentStats,
  CharCurrentStatsData,
  CharCStats2,
  CharBaseStats,
  Equipment,
  EquipmentInfo,
  EquipmentInfoData,
  EquipmentInfo2V2,
  EquipmentInfo2V2Data
} from "@codegen/index.sol";
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
    _snapshotStats(characterId, equipmentId, slotType);
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
    uint32 shieldBarrier = CharCStats2.getBarrier(characterId);
    EquipmentInfoData memory equipmentInfo = _getSnapshotEquipmentStats(characterId, slotType, itemId, isRemoved);
    EquipmentInfo2V2Data memory equipmentInfo2V2 = EquipmentInfo2V2.get(itemId);

    if (equipmentInfo.hp > 0) {
      uint32 maxHp = CharStats.getHp(characterId);
      uint32 currentHp = characterCurrentStats.hp;
      bool wasFullHp = (maxHp == currentHp);
      maxHp = isRemoved ? maxHp - equipmentInfo.hp : maxHp + equipmentInfo.hp;
      CharStats.setHp(characterId, maxHp);
      if (wasFullHp || currentHp > maxHp) {
        characterCurrentStats.hp = maxHp;
      }
    }
    if (slotType == SlotType.Mount) {
      _updateMaxWeightWithEquipment(characterId, equipmentInfo2V2.bonusWeight, isRemoved);
    }

    bool shouldUpdateShieldBarrier = equipmentInfo2V2.shieldBarrier > 0;

    if (isRemoved) {
      characterCurrentStats.ms -= equipmentInfo.ms;
      characterCurrentStats.atk -= equipmentInfo.atk;
      characterCurrentStats.def -= equipmentInfo.def;
      characterCurrentStats.agi -= equipmentInfo.agi;
      if (shouldUpdateShieldBarrier) {
        if (shieldBarrier < equipmentInfo2V2.shieldBarrier) {
          shieldBarrier = 0;
        } else {
          shieldBarrier -= equipmentInfo2V2.shieldBarrier;
        }
      }
    } else {
      characterCurrentStats.ms += equipmentInfo.ms;
      characterCurrentStats.atk += equipmentInfo.atk;
      characterCurrentStats.def += equipmentInfo.def;
      characterCurrentStats.agi += equipmentInfo.agi;
      if (shouldUpdateShieldBarrier) {
        shieldBarrier += equipmentInfo2V2.shieldBarrier;
      }
    }

    CharCurrentStats.set(characterId, characterCurrentStats);
    if (shouldUpdateShieldBarrier) {
      CharCStats2.setBarrier(characterId, shieldBarrier);
    }
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
    if (
      equipmentInfo.hp == 0 && equipmentInfo.atk == 0 && equipmentInfo.def == 0 && equipmentInfo.agi == 0
        && equipmentInfo.ms == 0
    ) {
      revert Errors.EquipmentSystem_EquipmentSnapshotStatsNotFound(characterId, itemId, slotType);
    }
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
