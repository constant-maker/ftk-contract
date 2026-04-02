pragma solidity >=0.8.24;

import { Equipment, Tool, Item, CharCurrentStats, CharOtherItem, CharItemCache } from "@codegen/index.sol";
import { CommonUtils } from "./CommonUtils.sol";
import { EquipmentUtils } from "./EquipmentUtils.sol";
import { Errors } from "@common/Errors.sol";

library CharacterWeightUtils {
  /*    Update equipment weight    */
  function removeEquipments(uint256 characterId, uint256[] memory equipmentIds) internal {
    _updateEquipmentsWeight(characterId, equipmentIds, true);
  }

  function removeEquipment(uint256 characterId, uint256 equipmentId) internal {
    uint256[] memory equipmentIds = CommonUtils.wrapUint256(equipmentId);
    _updateEquipmentsWeight(characterId, equipmentIds, true);
  }

  function addEquipments(uint256 characterId, uint256[] memory equipmentIds) internal {
    _updateEquipmentsWeight(characterId, equipmentIds, false);
  }

  function addEquipment(uint256 characterId, uint256 equipmentId) internal {
    uint256[] memory equipmentIds = CommonUtils.wrapUint256(equipmentId);
    _updateEquipmentsWeight(characterId, equipmentIds, false);
  }

  /*    Update tool weight    */
  function removeTools(uint256 characterId, uint256[] memory toolIds) internal {
    _updateToolsWeight(characterId, toolIds, true);
  }

  function removeTool(uint256 characterId, uint256 toolId) internal {
    uint256[] memory toolIds = CommonUtils.wrapUint256(toolId);
    _updateToolsWeight(characterId, toolIds, true);
  }

  function addTools(uint256 characterId, uint256[] memory toolIds) internal {
    _updateToolsWeight(characterId, toolIds, false);
  }

  function addTool(uint256 characterId, uint256 toolId) internal {
    uint256[] memory toolIds = CommonUtils.wrapUint256(toolId);
    _updateToolsWeight(characterId, toolIds, false);
  }

  /*    Update item weight    */
  function removeItems(uint256 characterId, uint256[] memory itemIds, uint32[] memory amounts) internal {
    _updateItemsWeight(characterId, itemIds, amounts, true);
  }

  function removeItem(uint256 characterId, uint256 itemId, uint32 amount) internal {
    uint256[] memory itemIds = CommonUtils.wrapUint256(itemId);
    uint32[] memory amounts = CommonUtils.wrapUint32(amount);
    _updateItemsWeight(characterId, itemIds, amounts, true);
  }

  function addItems(uint256 characterId, uint256[] memory itemIds, uint32[] memory amounts) internal {
    _updateItemsWeight(characterId, itemIds, amounts, false);
  }

  function addItem(uint256 characterId, uint256 itemId, uint32 amount) internal {
    uint256[] memory itemIds = CommonUtils.wrapUint256(itemId);
    uint32[] memory amounts = CommonUtils.wrapUint32(amount);
    _updateItemsWeight(characterId, itemIds, amounts, false);
  }

  function _updateItemsWeight(
    uint256 characterId,
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

    int64 weightChange = 0;
    for (uint256 i = 0; i < length; i++) {
      weightChange += _updateItemCacheAndGetWeightChange(characterId, itemIds[i], amounts[i], isRemoved);
    }

    uint32 characterWeight = CharCurrentStats.getWeight(characterId);
    uint32 newWeight;
    if (weightChange >= 0) {
      newWeight = characterWeight + uint32(uint64(weightChange));
    } else {
      newWeight = CommonUtils.getNewWeight(characterWeight, uint32(uint64(-weightChange)), true);
    }
    CharCurrentStats.setWeight(characterId, newWeight);
  }

  function _updateToolsWeight(uint256 characterId, uint256[] memory toolIds, bool isRemoved) private {
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
    uint32 characterWeight = CharCurrentStats.getWeight(characterId);
    uint32 newWeight = CommonUtils.getNewWeight(characterWeight, weightChange, isRemoved);
    CharCurrentStats.setWeight(characterId, newWeight);
  }

  function _updateEquipmentsWeight(uint256 characterId, uint256[] memory equipmentIds, bool isRemoved) private {
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
    uint32 characterWeight = CharCurrentStats.getWeight(characterId);
    uint32 newWeight = CommonUtils.getNewWeight(characterWeight, weightChange, isRemoved);
    CharCurrentStats.setWeight(characterId, newWeight);
  }

  function _updateItemCacheAndGetWeightChange(
    uint256 characterId,
    uint256 itemId,
    uint32 amount,
    bool isRemoved
  )
    private
    returns (int64 weightChange)
  {
    if (amount == 0) return 0;

    uint32 currentItemWeight = Item.getWeight(itemId);
    uint32 cachedUnitWeight = CharItemCache.getWeight(characterId, itemId);

    if (!isRemoved) {
      uint32 currentAmount = CharOtherItem.getAmount(characterId, itemId);
      uint32 previousAmount = currentAmount - amount;
      uint64 addedWeight = uint64(currentItemWeight) * uint64(amount);

      if (cachedUnitWeight == 0) {
        CharItemCache.setWeight(characterId, itemId, currentItemWeight);
        return int64(addedWeight);
      }

      weightChange = int64(addedWeight);
      if (currentItemWeight >= cachedUnitWeight) {
        weightChange += int64(uint64(currentItemWeight - cachedUnitWeight) * uint64(previousAmount));
      } else {
        weightChange -= int64(uint64(cachedUnitWeight - currentItemWeight) * uint64(previousAmount));
      }
      CharItemCache.setWeight(characterId, itemId, currentItemWeight);
      return weightChange;
    }

    uint32 currentAmount = CharOtherItem.getAmount(characterId, itemId);
    uint32 unitWeight = cachedUnitWeight;
    if (unitWeight == 0) {
      unitWeight = currentItemWeight;
    }

    if (currentAmount == 0) {
      CharItemCache.deleteRecord(characterId, itemId);
    } else if (cachedUnitWeight == 0) {
      CharItemCache.setWeight(characterId, itemId, unitWeight);
    }

    return -int64(uint64(unitWeight) * uint64(amount));
  }
}
