pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharStats, CharStatsData } from "@codegen/tables/CharStats.sol";
import {
  Equipment,
  EquipmentInfo,
  EquipmentInfoData,
  CharEquipment,
  CharCurrentStats,
  CharCurrentStatsData,
  CharBaseStats,
  CharBaseStatsData,
  CharReborn
} from "@codegen/index.sol";
import { CharAchievementUtils } from "@utils/CharAchievementUtils.sol";
import { SlotType } from "@codegen/common.sol";
import { Errors, Config } from "@common/index.sol";

contract RebornSystem is System, CharacterAccessControl {
  function reborn(uint256 characterId) public onlyAuthorizedWallet(characterId) {
    // require character level 99
    CharStatsData memory charStats = CharStats.get(characterId);
    if (charStats.level < Config.MAX_LEVEL) {
      revert Errors.RebornSystem_MustBeMaxLevel(characterId);
    }
    // reset stat and gain extra points
    // update current stats
    CharBaseStatsData memory characterBaseStats = CharBaseStats.get(characterId);
    CharCurrentStatsData memory charCurrentStats = CharCurrentStats.get(characterId);

    charCurrentStats = _getRebornCurrentStats(characterId, characterBaseStats, charCurrentStats);
    CharCurrentStats.set(characterId, charCurrentStats);

    // update stats
    charStats.level = 1;
    charStats.hp = charCurrentStats.hp;
    charStats.statPoint += 20;
    CharStats.set(characterId, charStats);

    // reset base stats
    CharBaseStats.deleteRecord(characterId);

    // update reborn counter
    CharReborn.set(characterId, CharReborn.get(characterId) + 1);

    // add achievement
    CharAchievementUtils.addAchievement(characterId, 9); // Ascended Soul
  }

  function _getRebornCurrentStats(
    uint256 characterId,
    CharBaseStatsData memory characterBaseStats,
    CharCurrentStatsData memory charCurrentStats
  )
    private
    view
    returns (CharCurrentStatsData memory)
  {
    (uint32 eHp, uint16 eAtk, uint16 eDef, uint16 eAgi) = _getTotalEquipmentStats(characterId);
    // hp
    charCurrentStats.hp = Config.DEFAULT_HP + eHp;
    // atk
    if (charCurrentStats.atk > characterBaseStats.atk + eAtk) {
      charCurrentStats.atk = charCurrentStats.atk - characterBaseStats.atk;
    } else {
      charCurrentStats.atk = 4 + eAtk;
    }
    // def
    if (charCurrentStats.def > characterBaseStats.def + eDef) {
      charCurrentStats.def = charCurrentStats.def - characterBaseStats.def;
    } else {
      charCurrentStats.def = block.number % 2 == 0 ? 3 : 2 + eDef;
    }
    // agi
    if (charCurrentStats.agi > characterBaseStats.agi + eAgi) {
      charCurrentStats.agi = charCurrentStats.agi - characterBaseStats.agi;
    } else {
      charCurrentStats.agi = block.number % 2 == 0 ? 2 : 3 + eAgi;
    }
    return charCurrentStats;
  }

  function _getTotalEquipmentStats(uint256 characterId)
    private
    view
    returns (uint32 hp, uint16 atk, uint16 def, uint16 agi)
  {
    SlotType[] memory slotTypes = _getAllSlotType();
    for (uint256 i = 0; i < slotTypes.length; i++) {
      uint256 equipmentId = CharEquipment.getEquipmentId(characterId, slotTypes[i]);
      if (equipmentId > 0) {
        uint256 itemId = Equipment.getItemId(equipmentId);
        EquipmentInfoData memory equipmentInfo = EquipmentInfo.get(itemId);
        hp += equipmentInfo.hp;
        atk += equipmentInfo.atk;
        def += equipmentInfo.def;
        agi += equipmentInfo.agi;
      }
    }
    return (hp, atk, def, agi);
  }

  function _getAllSlotType() private pure returns (SlotType[] memory slotTypes) {
    SlotType[] memory slotTypes = new SlotType[](6);
    slotTypes[0] = SlotType.Weapon;
    slotTypes[1] = SlotType.SubWeapon;
    slotTypes[3] = SlotType.Headgear;
    slotTypes[2] = SlotType.Armor;
    slotTypes[4] = SlotType.Footwear;
    slotTypes[5] = SlotType.Mount;
    return slotTypes;
  }
}
