pragma solidity >=0.8.24;

import { Equipment, EquipmentInfo, Item, ItemData, CharCurrentStats, CharEquipment } from "@codegen/index.sol";
import { AdvantageType, SlotType, SkinSlotType, ItemType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";
import { InventoryEquipmentUtils } from "./InventoryEquipmentUtils.sol";
import { CharacterStatsUtils } from "./CharacterStatsUtils.sol";
import { CharacterPerkUtils } from "./CharacterPerkUtils.sol";

struct EquipData {
  SlotType slotType;
  uint256 equipmentId;
}

struct EquipSkinData {
  SkinSlotType slotType;
  uint256 itemId;
}

library CharacterEquipmentUtils {
  uint8 constant MAX_SLOT_TYPE = uint8(SlotType.Ring);

  /// @dev unequip all equipments
  function unequipAllEquipment(uint256 characterId) internal {
    for (uint8 i = 0; i <= MAX_SLOT_TYPE; i++) {
      SlotType slotType = SlotType(i);
      unequipEquipment(characterId, slotType);
    }
  }

  /// @dev unequip equipment
  function unequipEquipment(uint256 characterId, SlotType slotType) internal {
    uint256 currentEquipmentId = CharEquipment.get(characterId, slotType);
    if (currentEquipmentId == 0) return;
    unequipEquipmentById(characterId, slotType, currentEquipmentId);
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
    uint256 weaponId = CharEquipment.getEquipmentId(characterId, SlotType.Weapon);
    return _getWeaponAdvantageType(weaponId);
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

  function getAllCharacterEquipments(uint256 characterId) internal view returns (uint256[] memory equipmentIds) {
    equipmentIds = new uint256[](MAX_SLOT_TYPE + 1);
    for (uint8 i = 0; i <= MAX_SLOT_TYPE; i++) {
      equipmentIds[i] = CharEquipment.getEquipmentId(characterId, SlotType(i));
    }
    return equipmentIds;
  }

  /// @dev Check whether character perk level is enough to equip item
  function checkCharacterPerkLevelByItemId(uint256 characterId, uint256 itemId) internal view {
    ItemData memory item = Item.get(itemId);
    if (item.itemType == ItemType.Mount || item.itemType == ItemType.Ring || item.itemType == ItemType.Pet) {
      // no perk level requirement for mount, ring, pet
      return;
    }
    uint8 perkLevel = CharacterPerkUtils.getPerkLevel(characterId, item.itemType);
    if (perkLevel < item.tier) {
      revert Errors.Character_PerkLevelTooLow(characterId, perkLevel, item.itemType, item.tier);
    }
  }
}
