// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { TileInventory, TileInventoryData, TileOtherItemIndex } from "@codegen/index.sol";
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

  /// @dev Add one item to tile inventory
  function addItem(int32 x, int32 y, uint256 itemId, uint32 amount) public {
    _checkToResetData(x, y);
    _addItem(x, y, itemId, amount);
  }

  function _addItem(int32 x, int32 y, uint256 itemId, uint32 amount) private {
    uint256 index = TileOtherItemIndex.get(x, y, itemId);
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

  /// @dev Add equipment to tile inventory
  function addEquipment(int32 x, int32 y, uint256 equipmentId) public {
    _checkToResetData(x, y);
    TileInventory.pushEquipmentIds(x, y, equipmentId);
    TileInventory.setLastDropTime(x, y, block.timestamp);
  }

  /// @dev Remove equipment from tile inventory by index
  function removeEquipment(int32 x, int32 y, uint256 equipmentIndex) public {
    uint256 length = TileInventory.lengthEquipmentIds(x, y);
    if (equipmentIndex >= length) {
      revert Errors.TileSystem_EquipmentNotFound(x, y, equipmentIndex);
    }
    uint256 lastIndex = length - 1;
    if (equipmentIndex != lastIndex) {
      uint256 lastValue = TileInventory.getItemEquipmentIds(x, y, lastIndex);
      TileInventory.updateEquipmentIds(x, y, equipmentIndex, lastValue);
    }
    TileInventory.popEquipmentIds(x, y);
  }

  /// @dev Check if tile has a specific item
  function hasItem(int32 x, int32 y, uint256 itemId) public view returns (bool) {
    uint256 index = TileOtherItemIndex.get(x, y, itemId);
    return index != 0;
  }

  /// @dev Get the amount of a specific item in the tile inventory
  function _checkToResetData(int32 x, int32 y) private {
    if (TileInventory.getLastDropTime(x, y) + Config.TILE_ITEM_AVAILABLE_DURATION < block.timestamp) {
      TileInventory.deleteRecord(x, y);
    }
  }
}
