// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { TileDrop, TileDropData, TileOtherItemIndex } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";

library TileOtherItemUtils {
  /// @dev Add items to tile drop
  function addItems(int32 x, int32 y, uint256[] memory itemIds, uint32[] memory amounts) internal {
    require(itemIds.length == amounts.length, "Mismatched lengths");
    for (uint256 i = 0; i < itemIds.length; i++) {
      _addItem(x, y, itemIds[i], amounts[i]);
    }
  }

  /// @dev Add one item to tile drop
  function addItem(int32 x, int32 y, uint256 itemId, uint32 amount) internal {
    _addItem(x, y, itemId, amount);
  }

  function _addItem(int32 x, int32 y, uint256 itemId, uint32 amount) private {
    uint256 index = TileOtherItemIndex.get(x, y, itemId);

    if (index == 0) {
      TileDrop.pushOtherItemIds(x, y, itemId);
      TileDrop.pushOtherItemAmounts(x, y, amount);
      uint256 newIndex = TileDrop.lengthOtherItemIds(x, y);
      TileOtherItemIndex.set(x, y, itemId, newIndex);
    } else {
      uint256 valueIndex = index - 1;
      uint32 currentAmount = TileDrop.getItemOtherItemAmounts(x, y, valueIndex);
      TileDrop.updateOtherItemAmounts(x, y, valueIndex, currentAmount + amount);
    }
  }

  /// @dev Remove items from tile drop
  function removeItems(int32 x, int32 y, uint256[] memory itemIds, uint32[] memory amounts) internal {
    require(itemIds.length == amounts.length, "Mismatched lengths");
    for (uint256 i = 0; i < itemIds.length; i++) {
      _removeItem(x, y, itemIds[i], amounts[i]);
    }
  }

  /// @dev Remove one item from tile drop
  function removeItem(int32 x, int32 y, uint256 itemId, uint32 amount) internal {
    _removeItem(x, y, itemId, amount);
  }

  function _removeItem(int32 x, int32 y, uint256 itemId, uint32 amount) private {
    uint256 index = TileOtherItemIndex.get(x, y, itemId);
    if (index == 0) revert Errors.TileSystem_ItemNotFound(x, y, itemId);

    uint256 valueIndex = index - 1;
    uint32 currentAmount = TileDrop.getItemOtherItemAmounts(x, y, valueIndex);

    if (amount > currentAmount) {
      revert Errors.TileSystem_ExceedItemBalance(x, y, itemId, currentAmount, amount);
    }

    uint32 newAmount = currentAmount - amount;
    TileDrop.updateOtherItemAmounts(x, y, valueIndex, newAmount);
  }

  /// @dev Check if tile has a specific item
  function hasItem(int32 x, int32 y, uint256 itemId) internal view returns (bool) {
    uint256 index = TileOtherItemIndex.get(x, y, itemId);
    return index != 0;
  }
}
