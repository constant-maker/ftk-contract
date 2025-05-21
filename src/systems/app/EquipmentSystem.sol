pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharacterItemUtils,
  InventoryEquipmentUtils,
  CharacterStatsUtils,
  EquipmentUtils,
  CharacterEquipmentUtils
} from "@utils/index.sol";
import {
  CharEquipment, CharGrindSlot, Equipment, EquipmentData, EquipmentInfo, Item, CharStats
} from "@codegen/index.sol";
import { SlotType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { EquipData } from "./EquipmentSystem.sol";

struct EquipData {
  SlotType slotType;
  uint256 equipmentId;
}

contract EquipmentSystem is System, CharacterAccessControl {
  /// @dev gear up multi equipments
  function gearUpEquipments(
    uint256 characterId,
    EquipData[] calldata equipDatas
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    for (uint256 i = 0; i < equipDatas.length; ++i) {
      _gearUpEquipment(characterId, equipDatas[i]);
    }
  }

  function updateGrindSlot(uint256 characterId, SlotType slotType) public onlyAuthorizedWallet(characterId) {
    if (
      slotType != SlotType.Weapon && slotType != SlotType.SubWeapon && slotType != SlotType.Mount
        && slotType != SlotType.Armor && slotType != SlotType.Footwear && slotType != SlotType.Headgear
    ) {
      revert Errors.EquipmentSystem_InvalidSlotType(slotType);
    }
    CharGrindSlot.set(characterId, slotType);
  }

  /// @dev gear up equipment
  function _gearUpEquipment(uint256 characterId, EquipData calldata equipData) private {
    uint256 equipmentId = equipData.equipmentId;
    SlotType equipmentSlotType = equipData.slotType;
    if (equipmentId == 0) {
      CharacterEquipmentUtils.unequipEquipment(characterId, equipmentSlotType);
      return;
    }
    if (!InventoryEquipmentUtils.hasEquipment(characterId, equipmentId)) {
      revert Errors.Equipment_NotOwned(characterId, equipmentId);
    }
    EquipmentData memory equipmentData = EquipmentUtils.mustGetEquipmentData(equipmentId);
    _checkCharacterLevel(characterId, equipmentData.itemId);
    CharacterItemUtils.checkCharacterPerkLevelByItemId(characterId, equipmentData.itemId);
    SlotType slotType = EquipmentInfo.getSlotType(equipmentData.itemId);
    if (equipmentSlotType != slotType) {
      revert Errors.EquipmentSystem_UnmatchSlotType(slotType, equipmentSlotType);
    }

    if (slotType == SlotType.Weapon && EquipmentInfo.getTwoHanded(equipmentData.itemId)) {
      // if equipment is a two-handed weapon, we need to unequip subweapon
      CharacterEquipmentUtils.unequipEquipment(characterId, SlotType.SubWeapon);
    } else if (slotType == SlotType.SubWeapon) {
      // if equipment is a subweapon, we need to unequip weapon if it is two-handed
      uint256 currentWeaponId = CharEquipment.get(characterId, SlotType.Weapon);
      if (currentWeaponId != 0 && EquipmentInfo.getTwoHanded(Equipment.getItemId(currentWeaponId))) {
        CharacterEquipmentUtils.unequipEquipmentById(characterId, SlotType.Weapon, currentWeaponId);
      }
    }
    uint256 currentEquipmentId = CharEquipment.get(characterId, slotType);
    if (currentEquipmentId != 0) {
      // move current equipment back to inventory
      InventoryEquipmentUtils.addEquipment(characterId, currentEquipmentId, false);
      // update character stats
      CharacterStatsUtils.removeEquipment(characterId, currentEquipmentId, slotType);
    }
    CharEquipment.set(characterId, slotType, equipmentId);
    // remove equipment from inventory
    InventoryEquipmentUtils.removeEquipment(characterId, equipmentId, false);
    // update character stats
    CharacterStatsUtils.addEquipment(characterId, equipmentId, slotType);
  }

  function _checkCharacterLevel(uint256 characterId, uint256 itemId) private view {
    uint16 level = CharStats.getLevel(characterId);
    uint8 itemTier = Item.getTier(itemId);
    if (level + 10 < uint16(itemTier) * 10) {
      revert Errors.EquipmentSystem_CharacterLevelTooLow(characterId, level, itemTier);
    }
  }
}
