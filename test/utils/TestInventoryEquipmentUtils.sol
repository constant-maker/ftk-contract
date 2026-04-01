pragma solidity >=0.8.24;

import { InvEquipmentIndex } from "@codegen/index.sol";

library TestInventoryEquipmentUtils {
  function hasEquipment(uint256 characterId, uint256 equipmentId) internal view returns (bool) {
    return InvEquipmentIndex.get(characterId, equipmentId) != 0;
  }
}
