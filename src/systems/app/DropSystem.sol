pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { Tool2, Equipment } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { InventoryToolUtils, InventoryEquipmentUtils } from "@utils/index.sol";
import { ItemsActionData } from "@common/Types.sol";

contract DropSystem is System, CharacterAccessControl {
  /// @dev drop resources, items
  function drop(uint256 characterId, ItemsActionData calldata dropData) public onlyAuthorizedWallet(characterId) {
    _dropTools(characterId, dropData.toolIds);
    _dropEquipments(characterId, dropData.equipmentIds);
    _dropItems(characterId, dropData.itemIds, dropData.itemAmounts);
  }

  /// @dev drop tools
  function _dropTools(uint256 characterId, uint256[] memory toolIds) private {
    for (uint256 i = 0; i < toolIds.length; i++) {
      uint256 toolId = toolIds[i];
      if (!InventoryToolUtils.hasTool(characterId, toolId)) {
        revert Errors.Tool_NotOwned(characterId, toolId);
      }
      Tool2.deleteRecord(toolId);
    }
  }

  /// @dev drop equipments
  function _dropEquipments(uint256 characterId, uint256[] memory equipmentIds) private {
    for (uint256 i = 0; i < equipmentIds.length; i++) {
      uint256 equipmentId = equipmentIds[i];
      if (!InventoryEquipmentUtils.hasEquipment(characterId, equipmentId)) {
        revert Errors.Equipment_NotOwned(characterId, equipmentId);
      }
      Equipment.deleteRecord(equipmentId);
    }
  }

  /// @dev drop items
  function _dropItems(uint256 characterId, uint256[] memory itemIds, uint32[] memory amounts) private {
    if (itemIds.length == 0) return;
    InventoryItemUtils.removeItems(characterId, itemIds, amounts);
  }
}
