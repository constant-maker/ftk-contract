pragma solidity >=0.8.24;

import { Equipment, EquipmentData, ItemV2 } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";

library EquipmentUtils {
  /// @dev Return equipment data, revert if it is not exist
  function mustGetEquipmentData(uint256 equipmentId) internal view returns (EquipmentData memory equipmentData) {
    equipmentData = Equipment.get(equipmentId);
    if (equipmentData.itemId == 0) {
      revert Errors.Equipment_NotExisted(equipmentId);
    }
    return equipmentData;
  }

  /// @dev Return equipment weight, revert if it is not exist
  function mustGetEquipmentWeight(uint256 equipmentId) internal view returns (uint32 weight) {
    uint256 itemId = Equipment.getItemId(equipmentId);
    if (itemId == 0) {
      revert Errors.Equipment_NotExisted(equipmentId);
    }
    return ItemV2.getWeight(itemId);
  }
}
