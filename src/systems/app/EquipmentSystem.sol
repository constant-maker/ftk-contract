pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { InventoryEquipmentUtils } from "@utils/InventoryEquipmentUtils.sol";
import { CharacterStatsUtils } from "@utils/CharacterStatsUtils.sol";
import { EquipmentUtils } from "@utils/EquipmentUtils.sol";
import { CharacterEquipmentUtils, EquipData } from "@utils/CharacterEquipmentUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import {
  CharEquipment, CharGrindSlot, Equipment, EquipmentData, EquipmentInfo, Item, CharStats
} from "@codegen/index.sol";
import { SlotType, CharacterStateType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";

contract EquipmentSystem is System, CharacterAccessControl {
  uint8 constant LOW_TIER_MAX_LEVEL = 4;
  uint8 constant HIGH_TIER_MAX_LEVEL = 3;
  uint32 constant LOW_TIER_GOLD_MULTIPLY = 20;
  uint32 constant HIGH_TIER_GOLD_MULTIPLY = 100;

  /// @dev gear up multi equipments
  function gearUpEquipments(
    uint256 characterId,
    EquipData[] calldata equipDatas
  )
    public
    mustInStateStandByOrMoving(characterId)
    onlyAuthorizedWallet(characterId)
  {
    uint256 length = equipDatas.length;
    if (length == 0) {
      revert Errors.EquipmentSystem_EquipDataIsEmpty();
    }
    for (uint256 i = 0; i < length; ++i) {
      _gearUpEquipment(characterId, equipDatas[i]);
    }
  }

  /// @dev gear up equipment, if equipmentId is 0, it means unequip
  function _gearUpEquipment(uint256 characterId, EquipData calldata equipData) private {
    uint256 equipmentId = equipData.equipmentId;
    SlotType equipmentSlotType = equipData.slotType;
    if (equipmentId == 0) {
      // unequip equipment
      CharacterEquipmentUtils.unequipEquipment(characterId, equipmentSlotType);
      return;
    }
    if (!InventoryEquipmentUtils.hasEquipment(characterId, equipmentId)) {
      revert Errors.Equipment_NotOwned(characterId, equipmentId);
    }
    EquipmentData memory equipmentData = EquipmentUtils.mustGetEquipmentData(equipmentId);
    SlotType slotType = EquipmentInfo.getSlotType(equipmentData.itemId);
    if (equipmentSlotType != slotType) {
      revert Errors.EquipmentSystem_UnmatchSlotType(slotType, equipmentSlotType);
    }
    _checkCharacterLevel(characterId, equipmentData.itemId);
    CharacterEquipmentUtils.checkCharacterPerkLevelByItemId(characterId, equipmentData.itemId);

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

  /// @dev check character level requirement for equipment
  function _checkCharacterLevel(uint256 characterId, uint256 itemId) private view {
    uint16 level = CharStats.getLevel(characterId);
    uint8 itemTier = Item.getTier(itemId);
    if (level + 10 < uint16(itemTier) * 10) {
      revert Errors.EquipmentSystem_CharacterLevelTooLow(characterId, level, itemTier);
    }
  }

  /// @dev update grind slot to gain perk exp
  function updateGrindSlot(uint256 characterId, SlotType slotType) public onlyAuthorizedWallet(characterId) {
    bool isValidSlotType = false;
    // only allow weapon, subweapon, armor, headgear, footwear as grind slot
    for (uint8 i = 0; i <= uint8(SlotType.Footwear); i++) {
      if (slotType == SlotType(i)) {
        isValidSlotType = true;
        break;
      }
    }
    if (!isValidSlotType) {
      revert Errors.EquipmentSystem_InvalidSlotType(slotType);
    }
    CharGrindSlot.set(characterId, slotType);
  }

  /// @dev upgrade equipment by consuming same equipment as material
  function upgradeEquipment(
    uint256 characterId,
    uint256 targetEquipmentId,
    uint256 materialEquipmentId
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    if (targetEquipmentId == materialEquipmentId) {
      revert Errors.EquipmentSystem_SameEquipmentId(targetEquipmentId);
    }
    // ensure ownership of target equipment and it's not equipped
    if (!InventoryEquipmentUtils.hasEquipment(characterId, targetEquipmentId)) {
      revert Errors.Equipment_NotOwned(characterId, targetEquipmentId);
    }
    if (!InventoryEquipmentUtils.hasEquipment(characterId, materialEquipmentId)) {
      revert Errors.Equipment_NotOwned(characterId, materialEquipmentId);
    }
    EquipmentData memory targetEquipmentData = EquipmentUtils.mustGetEquipmentData(targetEquipmentId);
    EquipmentData memory materialEquipmentData = EquipmentUtils.mustGetEquipmentData(materialEquipmentId);
    if (
      targetEquipmentData.itemId != materialEquipmentData.itemId
        || targetEquipmentData.level != materialEquipmentData.level
    ) {
      revert Errors.EquipmentSystem_UnmatchEquipmentId(targetEquipmentId, materialEquipmentId);
    }
    uint8 nextLevel = targetEquipmentData.level + 1;
    _validateUpgradeLevel(nextLevel, targetEquipmentData.itemId);
    uint32 upgradeCost = _getUpgradeCost(targetEquipmentData.level, targetEquipmentData.itemId);
    CharacterFundUtils.decreaseGold(characterId, upgradeCost);

    // must update weight before deleting equipment record
    InventoryEquipmentUtils.removeEquipment(characterId, materialEquipmentId, true);
    Equipment.deleteRecord(materialEquipmentId);

    Equipment.setLevel(targetEquipmentId, nextLevel);
  }

  function _validateUpgradeLevel(uint8 nextLevel, uint256 itemId) private view {
    uint8 itemTier = Item.getTier(itemId);
    if (itemTier < 7 && nextLevel > LOW_TIER_MAX_LEVEL) {
      revert Errors.EquipmentSystem_ExceedMaxLevel(LOW_TIER_MAX_LEVEL);
    }
    if (itemTier >= 7 && nextLevel > HIGH_TIER_MAX_LEVEL) {
      revert Errors.EquipmentSystem_ExceedMaxLevel(HIGH_TIER_MAX_LEVEL);
    }
  }

  function _getUpgradeCost(uint8 level, uint256 itemId) private view returns (uint32 cost) {
    uint32 goldMultiply = LOW_TIER_GOLD_MULTIPLY;
    uint8 itemTier = Item.getTier(itemId);
    if (itemTier >= 7) {
      goldMultiply = HIGH_TIER_GOLD_MULTIPLY;
    }
    cost = uint32(itemTier) * uint32(level) * goldMultiply;
  }
}
