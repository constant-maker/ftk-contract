// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import {
  TileInventory,
  TileInventoryData,
  TileOtherItemIndex,
  TileEquipmentIndex,
  ItemV2,
  Equipment
} from "@codegen/index.sol";
import { Errors, Config } from "@common/index.sol";

library TileInventoryUtils {
  /// @dev Add items to tile inventory
  function addItems(int32 x, int32 y, uint256[] memory itemIds, uint32[] memory amounts) public {
    require(itemIds.length == amounts.length, "Mismatched lengths");
    _checkToResetData(x, y);
    for (uint256 i = 0; i < itemIds.length; i++) {
      _addItem(x, y, itemIds[i], amounts[i]);
    }
  }

  /// @dev Add one item to tile inventory, this func WILL NOT RESET DATA
  function addItem(int32 x, int32 y, uint256 itemId, uint32 amount) public {
    // _checkToResetData(x, y);
    _addItem(x, y, itemId, amount);
  }

  function _addItem(int32 x, int32 y, uint256 itemId, uint32 amount) private {
    uint256 index = TileOtherItemIndex.get(x, y, itemId); // 1-based index
    if (index > 0) {
      uint256 lenItemIds = TileInventory.lengthOtherItemIds(x, y);
      bool shouldResetIndexValue = index > lenItemIds; // out of bounds
      if (!shouldResetIndexValue) {
        // check if the itemId at the index matches the itemId we are adding
        shouldResetIndexValue = TileInventory.getItemOtherItemIds(x, y, index - 1) != itemId;
      }
      if (shouldResetIndexValue) {
        // If index is out of bounds or the itemId at that index does not match,
        // we need to reset the index for this itemId.
        // This can happen if items were removed or the inventory was modified.
        // We delete the record and re-add it.
        TileOtherItemIndex.deleteRecord(x, y, itemId);
        index = 0;
      }
    }
    if (index == 0) {
      TileInventory.pushOtherItemIds(x, y, itemId);
      TileInventory.pushOtherItemAmounts(x, y, amount);
      uint256 newIndex = TileInventory.lengthOtherItemIds(x, y);
      TileOtherItemIndex.set(x, y, itemId, newIndex);
    } else {
      uint256 valueIndex = index - 1;
      uint32 currentAmount = TileInventory.getItemOtherItemAmounts(x, y, valueIndex);
      TileInventory.updateOtherItemAmounts(x, y, valueIndex, currentAmount + amount);
    }

    TileInventory.setLastDropTime(x, y, block.timestamp);
  }

  /// @dev Remove items from tile inventory
  function removeItems(int32 x, int32 y, uint256[] memory itemIds, uint32[] memory amounts) public {
    require(itemIds.length == amounts.length, "Mismatched lengths");
    for (uint256 i = 0; i < itemIds.length; i++) {
      _removeItem(x, y, itemIds[i], amounts[i]);
    }
  }

  /// @dev Remove one item from tile inventory
  function removeItem(int32 x, int32 y, uint256 itemId, uint32 amount) public {
    _removeItem(x, y, itemId, amount);
  }

  function _removeItem(int32 x, int32 y, uint256 itemId, uint32 amount) private {
    uint256 index = TileOtherItemIndex.get(x, y, itemId);
    if (index == 0) revert Errors.TileSystem_ItemNotFound(x, y, itemId);

    uint256 valueIndex = index - 1;
    uint32 currentAmount = TileInventory.getItemOtherItemAmounts(x, y, valueIndex);

    if (amount > currentAmount) {
      revert Errors.TileSystem_ExceedItemBalance(x, y, itemId, currentAmount, amount);
    }

    uint32 newAmount = currentAmount - amount;
    TileInventory.updateOtherItemAmounts(x, y, valueIndex, newAmount);
  }

  /// @dev Add equipment to tile inventory, this func WILL NOT RESET DATA
  function addEquipment(int32 x, int32 y, uint256 equipmentId) public {
    // _checkToResetData(x, y);
    if (hasEquipment(x, y, equipmentId)) return;
    TileInventory.pushEquipmentIds(x, y, equipmentId);
    uint256 newIndex = TileInventory.lengthEquipmentIds(x, y);
    TileEquipmentIndex.set(x, y, equipmentId, newIndex);
    TileInventory.setLastDropTime(x, y, block.timestamp);
  }

  /// @dev Add multiple equipments to tile inventory
  function addEquipments(int32 x, int32 y, uint256[] memory equipmentIds) public {
    _checkToResetData(x, y);
    for (uint256 i = 0; i < equipmentIds.length; i++) {
      if (ItemV2.getIsUntradeable(Equipment.getItemId(equipmentIds[i]))) {
        // skip non-tradable equipment, this will be lost forever
        continue;
      }
      addEquipment(x, y, equipmentIds[i]);
    }
  }

  /// @dev Remove equipment from tile inventory by ID using smart index
  function removeEquipment(int32 x, int32 y, uint256 equipmentId) public {
    uint256 index = TileEquipmentIndex.get(x, y, equipmentId);
    if (index == 0) revert Errors.TileSystem_EquipmentNotFound(x, y, equipmentId);

    uint256 valueIndex = index - 1;
    uint256 lastIndex = TileInventory.lengthEquipmentIds(x, y) - 1;
    if (valueIndex != lastIndex) {
      uint256 lastValue = TileInventory.getItemEquipmentIds(x, y, lastIndex);
      TileInventory.updateEquipmentIds(x, y, valueIndex, lastValue);
      TileEquipmentIndex.set(x, y, lastValue, index);
    }
    TileInventory.popEquipmentIds(x, y);
    TileEquipmentIndex.deleteRecord(x, y, equipmentId);
  }

  /// @dev Remove multiple equipments
  function removeEquipments(int32 x, int32 y, uint256[] memory equipmentIds) public {
    for (uint256 i = 0; i < equipmentIds.length; i++) {
      removeEquipment(x, y, equipmentIds[i]);
    }
  }

  /// @dev Check if tile has a specific item
  function hasItem(int32 x, int32 y, uint256 itemId) public view returns (bool) {
    uint256 index = TileOtherItemIndex.get(x, y, itemId);
    return index != 0;
  }

  /// @dev Check if tile has a specific equipment
  function hasEquipment(int32 x, int32 y, uint256 equipmentId) public view returns (bool) {
    return TileEquipmentIndex.get(x, y, equipmentId) != 0;
  }

  /// @dev Get the amount of a specific item in the tile inventory
  function _checkToResetData(int32 x, int32 y) private {
    if (TileInventory.getLastDropTime(x, y) + Config.TILE_ITEM_AVAILABLE_DURATION < block.timestamp) {
      // reset equipment index
      // no need to reset equipment because id is unique but this help reduce size of indexer
      uint256[] memory equipmentIds = TileInventory.getEquipmentIds(x, y);
      for (uint256 i = 0; i < equipmentIds.length; i++) {
        uint256 equipmentId = equipmentIds[i];
        Equipment.deleteRecord(equipmentId);
        TileEquipmentIndex.deleteRecord(x, y, equipmentId);
      }
      // reset other items index
      uint256[] memory itemIds = TileInventory.getOtherItemIds(x, y);
      for (uint256 i = 0; i < itemIds.length; i++) {
        uint256 itemId = itemIds[i];
        TileOtherItemIndex.deleteRecord(x, y, itemId);
      }
      TileInventory.deleteRecord(x, y);
    }
  }
}
