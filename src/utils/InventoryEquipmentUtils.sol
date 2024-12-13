pragma solidity >=0.8.24;

import { CharInventory, InventoryEquipmentIndex } from "@codegen/index.sol";
import { CharacterWeightUtils } from "@utils/CharacterWeightUtils.sol";
import { Errors } from "@common/Errors.sol";

library InventoryEquipmentUtils {
  /// @dev Add equipments to inventory for character
  function addEquipments(uint256 characterId, uint256[] memory equipmentIds, bool updateWeight) public {
    for (uint256 i = 0; i < equipmentIds.length; i++) {
      _addEquipment(characterId, equipmentIds[i]);
    }
    if (updateWeight) {
      CharacterWeightUtils.addEquipments(characterId, equipmentIds);
    }
  }

  /// @dev Add equipment to inventory for character
  function addEquipment(uint256 characterId, uint256 equipmentId, bool updateWeight) public {
    _addEquipment(characterId, equipmentId);
    if (updateWeight) {
      CharacterWeightUtils.addEquipment(characterId, equipmentId);
    }
  }

  function _addEquipment(uint256 characterId, uint256 equipmentId) private {
    if (hasEquipment(characterId, equipmentId)) {
      revert Errors.Equipment_AlreadyHad(characterId, equipmentId);
    }
    CharInventory.pushEquipmentIds(characterId, equipmentId);
    // The value is stored at length-1, but we add 1 to all indexes
    // and use 0 as a sentinel value
    uint256 index = CharInventory.lengthEquipmentIds(characterId);
    InventoryEquipmentIndex.set(characterId, equipmentId, index);
  }

  /// @dev Remove equipments from inventory for character
  function removeEquipments(uint256 characterId, uint256[] memory equipmentIds, bool updateWeight) public {
    for (uint256 i = 0; i < equipmentIds.length; i++) {
      _removeEquipment(characterId, equipmentIds[i]);
    }
    if (updateWeight) {
      CharacterWeightUtils.removeEquipments(characterId, equipmentIds);
    }
  }

  /// @dev Remove equipment from inventory for character
  function removeEquipment(uint256 characterId, uint256 equipmentId, bool updateWeight) public {
    _removeEquipment(characterId, equipmentId);
    if (updateWeight) {
      CharacterWeightUtils.removeEquipment(characterId, equipmentId);
    }
  }

  function _removeEquipment(uint256 characterId, uint256 equipmentId) private {
    uint256 index = InventoryEquipmentIndex.get(characterId, equipmentId);
    if (index == 0) revert Errors.Equipment_NotOwned(characterId, equipmentId);
    // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
    // the array, and then remove the last element (sometimes called as 'swap and pop').
    // This modifies the order of the array, as noted in {at}.
    uint256 valueIndex = index - 1;
    uint256 lastIndex = CharInventory.lengthEquipmentIds(characterId) - 1;
    if (valueIndex != lastIndex) {
      uint256 lastValue = CharInventory.getItemEquipmentIds(characterId, lastIndex);
      CharInventory.updateEquipmentIds(characterId, valueIndex, lastValue);
      InventoryEquipmentIndex.set(characterId, lastValue, index);
    }
    CharInventory.popEquipmentIds(characterId);
    InventoryEquipmentIndex.deleteRecord(characterId, equipmentId);
  }

  /// @dev Return whether the character has the equipment in inventory
  function hasEquipment(uint256 characterId, uint256 equipmentId) public view returns (bool) {
    uint256 index = InventoryEquipmentIndex.get(characterId, equipmentId);
    return index != 0;
  }
}
