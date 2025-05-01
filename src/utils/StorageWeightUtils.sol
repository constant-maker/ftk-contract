pragma solidity >=0.8.24;

import { Equipment, Tool2, Item, CharStorage, CharStorageMigration, ItemWeightCache } from "@codegen/index.sol";
import { CommonUtils } from "./CommonUtils.sol";
import { EquipmentUtils } from "./EquipmentUtils.sol";
import { Errors } from "@common/Errors.sol";

library StorageWeightUtils {
  /*    Update equipment weight    */
  function removeEquipments(uint256 characterId, uint256 cityId, uint256[] memory equipmentIds) internal {
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, true);
  }

  function removeEquipment(uint256 characterId, uint256 cityId, uint256 equipmentId) internal {
    uint256[] memory equipmentIds = CommonUtils.wrapUint256(equipmentId);
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, true);
  }

  function addEquipments(uint256 characterId, uint256 cityId, uint256[] memory equipmentIds) internal {
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, false);
  }

  function addEquipment(uint256 characterId, uint256 cityId, uint256 equipmentId) internal {
    uint256[] memory equipmentIds = CommonUtils.wrapUint256(equipmentId);
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, false);
  }

  /*    Update tool weight    */
  function removeTools(uint256 characterId, uint256 cityId, uint256[] memory toolIds) internal {
    _updateToolsWeight(characterId, cityId, toolIds, true);
  }

  function removeTool(uint256 characterId, uint256 cityId, uint256 toolId) internal {
    uint256[] memory toolIds = CommonUtils.wrapUint256(toolId);
    _updateToolsWeight(characterId, cityId, toolIds, true);
  }

  function addTools(uint256 characterId, uint256 cityId, uint256[] memory toolIds) internal {
    _updateToolsWeight(characterId, cityId, toolIds, false);
  }

  function addTool(uint256 characterId, uint256 cityId, uint256 toolId) internal {
    uint256[] memory toolIds = CommonUtils.wrapUint256(toolId);
    _updateToolsWeight(characterId, cityId, toolIds, false);
  }

  /*    Update item weight    */
  function removeItems(uint256 characterId, uint256 cityId, uint256[] memory itemIds, uint32[] memory amounts) internal {
    _updateItemsWeight(characterId, cityId, itemIds, amounts, true);
  }

  function removeItem(uint256 characterId, uint256 cityId, uint256 itemId, uint32 amount) internal {
    uint256[] memory itemIds = CommonUtils.wrapUint256(itemId);
    uint32[] memory amounts = CommonUtils.wrapUint32(amount);
    _updateItemsWeight(characterId, cityId, itemIds, amounts, true);
  }

  function addItems(uint256 characterId, uint256 cityId, uint256[] memory itemIds, uint32[] memory amounts) internal {
    _updateItemsWeight(characterId, cityId, itemIds, amounts, false);
  }

  function addItem(uint256 characterId, uint256 cityId, uint256 itemId, uint32 amount) internal {
    uint256[] memory itemIds = CommonUtils.wrapUint256(itemId);
    uint32[] memory amounts = CommonUtils.wrapUint32(amount);
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

    uint32 weightChange = 0;
    for (uint256 i = 0; i < length; i++) {
      uint32 itemWeight = Item.getWeight(itemIds[i]) * amounts[i];
      weightChange += itemWeight;
    }

    uint32 storageWeight = CharStorage.getWeight(characterId, cityId);
    uint32 newWeight = CommonUtils.getNewWeight(storageWeight, weightChange, isRemoved);
    _validateAndSetWeight(characterId, cityId, newWeight);
  }

  function _updateToolsWeight(uint256 characterId, uint256 cityId, uint256[] memory toolIds, bool isRemoved) private {
    // Check if the array is empty and return early if so
    uint256 length = toolIds.length;
    if (length == 0) return;

    uint32 weightChange = 0;
    for (uint256 i = 0; i < length; i++) {
      uint256 itemId = Tool2.getItemId(toolIds[i]);
      if (itemId == 0) {
        revert Errors.Tool_NotExisted(toolIds[i]);
      }
      weightChange += Item.getWeight(itemId);
    }

    // Update the character's weight
    uint32 storageWeight = CharStorage.getWeight(characterId, cityId);
    uint32 newWeight = CommonUtils.getNewWeight(storageWeight, weightChange, isRemoved);
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

    uint32 weightChange = 0;

    for (uint256 i = 0; i < length; i++) {
      uint256 equipmentId = equipmentIds[i];
      uint32 equipmentWeight = EquipmentUtils.mustGetEquipmentWeight(equipmentId);
      if (
        isRemoved && equipmentId < Config.MAX_EQUIPMENT_ID_TO_CHECK_CACHE_WEIGHT
          && !CharStorageMigration.getIsMigrate(characterId, cityId, equipmentId)
      ) {
        uint32 cacheWeight = ItemWeightCache.get(Equipment.getItemId(equipmentId));
        if (cacheWeight != 0) {
          equipmentWeight = cacheWeight;
        }
      }
      CharStorageMigration.setIsMigrate(characterId, cityId, equipmentId, true);
      weightChange += equipmentWeight;
    }

    // Update the character's weight
    uint32 storageWeight = CharStorage.getWeight(characterId, cityId);
    uint32 newWeight = CommonUtils.getNewWeight(storageWeight, weightChange, isRemoved);
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
