pragma solidity >=0.8.24;

import { Equipment, EquipmentData, EquipmentSupply, CharInventory, InvEquipmentIndex } from "@codegen/index.sol";
import { CharacterWeightUtils } from "@utils/CharacterWeightUtils.sol";
import { Errors } from "@common/Errors.sol";

library TestInventoryEquipmentUtils {
  function addNewEquipment(uint256 characterId, uint256 itemId, uint32 amount) internal {
    for (uint32 i = 0; i < amount; i++) {
      uint256 newEquipmentId = EquipmentSupply.get() + 1;
      EquipmentData memory equipmentData =
        EquipmentData({ itemId: itemId, characterId: characterId, authorId: characterId, level: 1 });
      Equipment.set(newEquipmentId, equipmentData);
      _addEquipment(characterId, newEquipmentId);
      CharacterWeightUtils.addEquipment(characterId, newEquipmentId);
      EquipmentSupply.set(newEquipmentId);
    }
  }

  function hasEquipment(uint256 characterId, uint256 equipmentId) internal view returns (bool) {
    return InvEquipmentIndex.get(characterId, equipmentId) != 0;
  }

  function _addEquipment(uint256 characterId, uint256 equipmentId) private {
    if (InvEquipmentIndex.get(characterId, equipmentId) != 0) {
      revert Errors.Equipment_AlreadyHad(characterId, equipmentId);
    }

    CharInventory.pushEquipmentIds(characterId, equipmentId);
    // The value is stored at length-1, but we add 1 to all indexes and use 0 as a sentinel value.
    uint256 index = CharInventory.lengthEquipmentIds(characterId);
    InvEquipmentIndex.set(characterId, equipmentId, index);
  }
}
