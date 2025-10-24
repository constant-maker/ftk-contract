pragma solidity >=0.8.24;

import { Equipment, EquipmentInfo, ItemV2, CharCurrentStats, CharEquipment } from "@codegen/index.sol";
import { AdvantageType, SlotType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";
import { InventoryEquipmentUtils } from "./InventoryEquipmentUtils.sol";
import { CharacterStatsUtils } from "./CharacterStatsUtils.sol";

library CharacterEquipmentUtils {
  /// @dev unequip all equipments
  function unequipAllEquipment(uint256 characterId) internal {
    for (uint8 i = 0; i <= uint8(SlotType.Mount); i++) {
      SlotType slotType = SlotType(i);
      unequipEquipment(characterId, slotType);
    }
  }

  /// @dev unequip equipment
  function unequipEquipment(uint256 characterId, SlotType slotType) internal {
    uint256 currentEquipmentId = CharEquipment.get(characterId, slotType);
    if (currentEquipmentId == 0) {
      // current slot is empty
      return;
    }
    unequipEquipmentById(characterId, slotType, currentEquipmentId);
  }

  /// @dev get all equipped equipment
  function getAllEquippedEquipment(uint256 characterId) internal view returns (uint256[] memory) {
    uint256[] memory equipmentIds = new uint256[](uint8(SlotType.Mount) + 1);
    for (uint8 i = 0; i <= uint8(SlotType.Mount); i++) {
      SlotType slotType = SlotType(i);
      equipmentIds[i] = CharEquipment.get(characterId, slotType);
    }
    return equipmentIds;
  }

  /// @dev unequip equipment by id
  function unequipEquipmentById(uint256 characterId, SlotType slotType, uint256 currentEquipmentId) internal {
    // move current equipment back to inventory
    InventoryEquipmentUtils.addEquipment(characterId, currentEquipmentId, false);
    // update character stats
    CharacterStatsUtils.removeEquipment(characterId, currentEquipmentId, slotType);
    CharEquipment.set(characterId, slotType, 0);
  }

  function getCharacterAdvantageType(uint256 characterId) internal view returns (AdvantageType characterAdvantageType) {
    uint256 weaponId = getCharacterWeaponId(characterId);
    return _getWeaponAdvantageType(weaponId);
  }

  function getCharacterWeaponId(uint256 characterId) internal view returns (uint256 weaponId) {
    return CharEquipment.getEquipmentId(characterId, SlotType.Weapon);
  }

  function _getWeaponAdvantageType(uint256 weaponId) private view returns (AdvantageType) {
    if (weaponId == 0) {
      return AdvantageType.Grey;
    }
    uint256 itemId = Equipment.getItemId(weaponId);
    if (itemId == 0) {
      revert Errors.Equipment_NotExisted(weaponId);
    }
    return EquipmentInfo.getAdvantageType(itemId);
  }
}
