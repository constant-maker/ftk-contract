pragma solidity >=0.8.24;

import { Equipment, Tool2, Item, CharStorage } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";

library StorageWeightUtils {
  /*    Update equipment weight    */
  function removeEquipments(uint256 characterId, uint256 cityId, uint256[] memory equipmentIds) internal {
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, true);
  }

  function removeEquipment(uint256 characterId, uint256 cityId, uint256 equipmentId) internal {
    uint256[] memory equipmentIds = new uint256[](1);
    equipmentIds[0] = equipmentId;
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, true);
  }

  function addEquipments(uint256 characterId, uint256 cityId, uint256[] memory equipmentIds) internal {
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, false);
  }

  function addEquipment(uint256 characterId, uint256 cityId, uint256 equipmentId) internal {
    uint256[] memory equipmentIds = new uint256[](1);
    equipmentIds[0] = equipmentId;
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, false);
  }

  /*    Update tool weight    */
  function removeTools(uint256 characterId, uint256 cityId, uint256[] memory toolIds) internal {
    _updateToolsWeight(characterId, cityId, toolIds, true);
  }

  function removeTool(uint256 characterId, uint256 cityId, uint256 toolId) internal {
    uint256[] memory toolIds = new uint256[](1);
    toolIds[0] = toolId;
    _updateToolsWeight(characterId, cityId, toolIds, true);
  }

  function addTools(uint256 characterId, uint256 cityId, uint256[] memory toolIds) internal {
    _updateToolsWeight(characterId, cityId, toolIds, false);
  }

  function addTool(uint256 characterId, uint256 cityId, uint256 toolId) internal {
    uint256[] memory toolIds = new uint256[](1);
    toolIds[0] = toolId;
    _updateToolsWeight(characterId, cityId, toolIds, false);
  }

  /*    Update item weight    */
  function removeItems(uint256 characterId, uint256 cityId, uint256[] memory itemIds, uint32[] memory amounts) internal {
    _updateItemsWeight(characterId, cityId, itemIds, amounts, true);
  }

  function removeItem(uint256 characterId, uint256 cityId, uint256 itemId, uint32 amount) internal {
    uint256[] memory itemIds = new uint256[](1);
    itemIds[0] = itemId;
    uint32[] memory amounts = new uint32[](1);
    amounts[0] = amount;
    _updateItemsWeight(characterId, cityId, itemIds, amounts, true);
  }

  function addItems(uint256 characterId, uint256 cityId, uint256[] memory itemIds, uint32[] memory amounts) internal {
    _updateItemsWeight(characterId, cityId, itemIds, amounts, false);
  }

  function addItem(uint256 characterId, uint256 cityId, uint256 itemId, uint32 amount) internal {
    uint256[] memory itemIds = new uint256[](1);
    itemIds[0] = itemId;
    uint32[] memory amounts = new uint32[](1);
    amounts[0] = amount;
    _updateItemsWeight(characterId, cityId, itemIds, amounts, false);
  }

  function _updateItemsWeight(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory itemIds,
    uint32[] memory amounts,
    bool isRemoved
  )
    private
  {
    uint256 length = itemIds.length;
    if (length == 0) return;
    // Ensure that the lengths of itemIds and amounts are equal
    require(length == amounts.length, "Mismatched array lengths: itemIds and amounts");

    uint32 totalWeight = 0;
    for (uint256 i = 0; i < length; i++) {
      uint32 itemWeight = Item.getWeight(itemIds[i]) * amounts[i];
      totalWeight += itemWeight;
    }

    uint32 storageWeight = CharStorage.getWeight(characterId, cityId);
    uint32 newWeight;
    if (!isRemoved) {
      newWeight = storageWeight + totalWeight;
    } else if (storageWeight > totalWeight) {
      newWeight = storageWeight - totalWeight;
    }
    _validateAndSetWeight(characterId, cityId, newWeight);
  }

  function _updateToolsWeight(uint256 characterId, uint256 cityId, uint256[] memory toolIds, bool isRemoved) private {
    // Check if the array is empty and return early if so
    uint256 length = toolIds.length;
    if (length == 0) {
      return;
    }

    uint32 totalWeight = 0;
    for (uint256 i = 0; i < length; i++) {
      uint256 itemId = Tool2.getItemId(toolIds[i]);
      if (itemId == 0) {
        revert Errors.Tool_NotExisted(toolIds[i]);
      }
      totalWeight += Item.getWeight(itemId);
    }

    // Update the character's weight
    uint32 storageWeight = CharStorage.getWeight(characterId, cityId);
    uint32 newWeight;
    if (!isRemoved) {
      newWeight = storageWeight + totalWeight;
    } else if (storageWeight > totalWeight) {
      newWeight = storageWeight - totalWeight;
    }
    _validateAndSetWeight(characterId, cityId, newWeight);
  }

  function _updateEquipmentsWeight(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory equipmentIds,
    bool isRemoved
  )
    private
  {
    // Check if the array is empty and return early if so
    uint256 length = equipmentIds.length;
    if (length == 0) return;

    uint32 totalWeight = 0;

    for (uint256 i = 0; i < length; i++) {
      uint256 itemId = Equipment.getItemId(equipmentIds[i]);
      if (itemId == 0) {
        revert Errors.Equipment_NotExisted(equipmentIds[i]);
      }
      totalWeight += Item.getWeight(itemId);
    }

    // Update the character's weight
    uint32 storageWeight = CharStorage.getWeight(characterId, cityId);
    uint32 newWeight;
    if (!isRemoved) {
      newWeight = storageWeight + totalWeight;
    } else if (storageWeight > totalWeight) {
      newWeight = storageWeight - totalWeight;
    }
    _validateAndSetWeight(characterId, cityId, newWeight);
  }

  function _validateAndSetWeight(uint256 characterId, uint256 cityId, uint32 newWeight) private {
    uint32 maxWeight = CharStorage.getMaxWeight(characterId, cityId);
    if (newWeight > maxWeight) {
      revert Errors.Storage_ExceedMaxWeight(maxWeight, newWeight);
    }
    CharStorage.setWeight(characterId, cityId, newWeight);
  }
}
