pragma solidity >=0.8.24;

import { Equipment, EquipmentData } from "@codegen/index.sol";
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
}
