pragma solidity >=0.8.24;

import { Equipment, Tool, Item, CharStorage, CharOtherItemStorage, CharStrItemCache } from "@codegen/index.sol";
import { CommonUtils } from "./CommonUtils.sol";
import { EquipmentUtils } from "./EquipmentUtils.sol";
import { Errors } from "@common/Errors.sol";

library StorageWeightUtils {
  /*    Update equipment weight    */
  function removeEquipments(uint256 characterId, uint256 cityId, uint256[] memory equipmentIds) internal {
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, true, false);
  }

  function removeEquipment(uint256 characterId, uint256 cityId, uint256 equipmentId) internal {
    uint256[] memory equipmentIds = CommonUtils.wrapUint256(equipmentId);
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, true, false);
  }

  function addEquipments(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory equipmentIds,
    bool checkMaxWeight
  )
    internal
  {
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, false, checkMaxWeight);
  }

  function addEquipment(uint256 characterId, uint256 cityId, uint256 equipmentId, bool checkMaxWeight) internal {
    uint256[] memory equipmentIds = CommonUtils.wrapUint256(equipmentId);
    _updateEquipmentsWeight(characterId, cityId, equipmentIds, false, checkMaxWeight);
  }

  /*    Update tool weight    */
  function removeTools(uint256 characterId, uint256 cityId, uint256[] memory toolIds) internal {
    _updateToolsWeight(characterId, cityId, toolIds, true, false);
  }

  function removeTool(uint256 characterId, uint256 cityId, uint256 toolId) internal {
    uint256[] memory toolIds = CommonUtils.wrapUint256(toolId);
    _updateToolsWeight(characterId, cityId, toolIds, true, false);
  }

  function addTools(uint256 characterId, uint256 cityId, uint256[] memory toolIds, bool checkMaxWeight) internal {
    _updateToolsWeight(characterId, cityId, toolIds, false, checkMaxWeight);
  }

  function addTool(uint256 characterId, uint256 cityId, uint256 toolId, bool checkMaxWeight) internal {
    uint256[] memory toolIds = CommonUtils.wrapUint256(toolId);
    _updateToolsWeight(characterId, cityId, toolIds, false, checkMaxWeight);
  }

  /*    Update item weight    */
  function removeItems(uint256 characterId, uint256 cityId, uint256[] memory itemIds, uint32[] memory amounts) internal {
    _updateItemsWeight(characterId, cityId, itemIds, amounts, true, false);
  }

  function removeItem(uint256 characterId, uint256 cityId, uint256 itemId, uint32 amount) internal {
    uint256[] memory itemIds = CommonUtils.wrapUint256(itemId);
    uint32[] memory amounts = CommonUtils.wrapUint32(amount);
    _updateItemsWeight(characterId, cityId, itemIds, amounts, true, false);
  }

  function addItems(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory itemIds,
    uint32[] memory amounts,
    bool checkMaxWeight
  )
    internal
  {
    _updateItemsWeight(characterId, cityId, itemIds, amounts, false, checkMaxWeight);
  }

  function addItem(uint256 characterId, uint256 cityId, uint256 itemId, uint32 amount, bool checkMaxWeight) internal {
    uint256[] memory itemIds = CommonUtils.wrapUint256(itemId);
    uint32[] memory amounts = CommonUtils.wrapUint32(amount);
    _updateItemsWeight(characterId, cityId, itemIds, amounts, false, checkMaxWeight);
  }

  function _updateItemsWeight(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory itemIds,
    uint32[] memory amounts,
    bool isRemoved,
    bool checkMaxWeight
  )
    private
  {
    uint256 length = itemIds.length;
    if (length == 0) return;
    // Ensure that the lengths of itemIds and amounts are equal
    require(length == amounts.length, "Mismatched array lengths: itemIds and amounts");

    int64 weightChange = 0;
    for (uint256 i = 0; i < length; i++) {
      weightChange += _updateItemCacheAndGetWeightChange(characterId, cityId, itemIds[i], amounts[i], isRemoved);
    }

    uint32 storageWeight = CharStorage.getWeight(characterId, cityId);
    uint32 newWeight;
    if (weightChange >= 0) {
      newWeight = storageWeight + uint32(uint64(weightChange));
    } else {
      newWeight = CommonUtils.getNewWeight(storageWeight, uint32(uint64(-weightChange)), true);
    }
    _validateAndSetWeight(characterId, cityId, newWeight, checkMaxWeight);
  }

  function _updateToolsWeight(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory toolIds,
    bool isRemoved,
    bool checkMaxWeight
  )
    private
  {
    // Check if the array is empty and return early if so
    uint256 length = toolIds.length;
    if (length == 0) return;

    uint32 weightChange = 0;
    for (uint256 i = 0; i < length; i++) {
      uint256 itemId = Tool.getItemId(toolIds[i]);
      if (itemId == 0) {
        revert Errors.Tool_NotExisted(toolIds[i]);
      }
      weightChange += Item.getWeight(itemId);
    }

    // Update the character's weight
    uint32 storageWeight = CharStorage.getWeight(characterId, cityId);
    uint32 newWeight = CommonUtils.getNewWeight(storageWeight, weightChange, isRemoved);
    _validateAndSetWeight(characterId, cityId, newWeight, checkMaxWeight);
  }

  function _updateEquipmentsWeight(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory equipmentIds,
    bool isRemoved,
    bool checkMaxWeight
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
      weightChange += equipmentWeight;
    }

    // Update the character's weight
    uint32 storageWeight = CharStorage.getWeight(characterId, cityId);
    uint32 newWeight = CommonUtils.getNewWeight(storageWeight, weightChange, isRemoved);
    _validateAndSetWeight(characterId, cityId, newWeight, checkMaxWeight);
  }

  function _validateAndSetWeight(uint256 characterId, uint256 cityId, uint32 newWeight, bool checkMaxWeight) private {
    if (checkMaxWeight) {
      uint32 maxWeight = CharStorage.getMaxWeight(characterId, cityId);
      if (newWeight > maxWeight) {
        revert Errors.Storage_ExceedMaxWeight(maxWeight, newWeight);
      }
    }
    CharStorage.setWeight(characterId, cityId, newWeight);
  }

  function _updateItemCacheAndGetWeightChange(
    uint256 characterId,
    uint256 cityId,
    uint256 itemId,
    uint32 amount,
    bool isRemoved
  )
    private
    returns (int64 weightChange)
  {
    if (amount == 0) return 0;

    uint32 currentItemWeight = Item.getWeight(itemId);
    uint32 cachedUnitWeight = CharStrItemCache.getWeight(characterId, cityId, itemId);

    if (!isRemoved) {
      uint32 currentAmount = CharOtherItemStorage.getAmount(characterId, cityId, itemId);
      uint32 previousAmount = currentAmount - amount;
      uint64 addedWeight = uint64(currentItemWeight) * uint64(amount);

      if (cachedUnitWeight == 0) {
        CharStrItemCache.setWeight(characterId, cityId, itemId, currentItemWeight);
        return int64(addedWeight);
      }

      weightChange = int64(addedWeight);
      if (currentItemWeight >= cachedUnitWeight) {
        weightChange += int64(uint64(currentItemWeight - cachedUnitWeight) * uint64(previousAmount));
      } else {
        weightChange -= int64(uint64(cachedUnitWeight - currentItemWeight) * uint64(previousAmount));
      }
      CharStrItemCache.setWeight(characterId, cityId, itemId, currentItemWeight);
      return weightChange;
    }

    uint32 currentAmount = CharOtherItemStorage.getAmount(characterId, cityId, itemId);
    uint32 unitWeight = cachedUnitWeight;
    if (unitWeight == 0) {
      unitWeight = currentItemWeight;
    }

    if (currentAmount == 0) {
      CharStrItemCache.deleteRecord(characterId, cityId, itemId);
    } else if (cachedUnitWeight == 0) {
      CharStrItemCache.setWeight(characterId, cityId, itemId, unitWeight);
    }

    return -int64(uint64(unitWeight) * uint64(amount));
  }
}
