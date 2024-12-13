pragma solidity >=0.8.24;

import { CharStorage, StorageEquipmentIndex } from "@codegen/index.sol";
import { StorageWeightUtils } from "./StorageWeightUtils.sol";
import { Errors } from "@common/Errors.sol";

library StorageEquipmentUtils {
  /// @dev Add equipments to storage
  function addEquipments(uint256 characterId, uint256 cityId, uint256[] memory equipmentIds) public {
    for (uint256 i = 0; i < equipmentIds.length; i++) {
      _addEquipment(characterId, cityId, equipmentIds[i]);
    }
    StorageWeightUtils.addEquipments(characterId, cityId, equipmentIds);
  }

  /// @dev Add equipment to storage
  function addEquipment(uint256 characterId, uint256 cityId, uint256 equipmentId) public {
    _addEquipment(characterId, cityId, equipmentId);
    StorageWeightUtils.addEquipment(characterId, cityId, equipmentId);
  }

  function _addEquipment(uint256 characterId, uint256 cityId, uint256 equipmentId) private {
    if (hasEquipment(characterId, cityId, equipmentId)) {
      revert Errors.Equipment_AlreadyHad(characterId, equipmentId);
    }
    CharStorage.pushEquipmentIds(characterId, cityId, equipmentId);
    // The value is stored at length-1, but we add 1 to all indexes
    // and use 0 as a sentinel value
    uint256 index = CharStorage.lengthEquipmentIds(characterId, cityId);
    StorageEquipmentIndex.set(characterId, cityId, equipmentId, index);
  }

  /// @dev Remove equipments from storage
  function removeEquipments(uint256 characterId, uint256 cityId, uint256[] memory equipmentIds) public {
    for (uint256 i = 0; i < equipmentIds.length; i++) {
      _removeEquipment(characterId, cityId, equipmentIds[i]);
    }
    StorageWeightUtils.removeEquipments(characterId, cityId, equipmentIds);
  }

  /// @dev Remove equipment from storage
  function removeEquipment(uint256 characterId, uint256 cityId, uint256 equipmentId) public {
    _removeEquipment(characterId, cityId, equipmentId);
    StorageWeightUtils.removeEquipment(characterId, cityId, equipmentId);
  }

  function _removeEquipment(uint256 characterId, uint256 cityId, uint256 equipmentId) private {
    uint256 index = StorageEquipmentIndex.get(characterId, cityId, equipmentId);
    if (index == 0) revert Errors.Equipment_NotOwned(characterId, equipmentId);
    // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
    // the array, and then remove the last element (sometimes called as 'swap and pop').
    // This modifies the order of the array, as noted in {at}.
    uint256 valueIndex = index - 1;
    uint256 lastIndex = CharStorage.lengthEquipmentIds(characterId, cityId) - 1;
    if (valueIndex != lastIndex) {
      uint256 lastValue = CharStorage.getItemEquipmentIds(characterId, cityId, lastIndex);
      CharStorage.updateEquipmentIds(characterId, cityId, valueIndex, lastValue);
      StorageEquipmentIndex.set(characterId, cityId, lastValue, index);
    }
    CharStorage.popEquipmentIds(characterId, cityId);
    StorageEquipmentIndex.deleteRecord(characterId, cityId, equipmentId);
  }

  /// @dev Return whether the character has the equipment in storage
  function hasEquipment(uint256 characterId, uint256 cityId, uint256 equipmentId) public view returns (bool) {
    uint256 index = StorageEquipmentIndex.get(characterId, cityId, equipmentId);
    return index != 0;
  }
}
