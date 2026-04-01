// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { TileInventory, TileOtherItemIndex } from "@codegen/index.sol";

library TestTileInventoryUtils {
  /// @dev Test-only helper mirroring TileInventoryUtils.addItem behavior.
  function addItem(int32 x, int32 y, uint256 itemId, uint32 amount) internal {
    if (amount == 0) return;

    uint256 index = TileOtherItemIndex.get(x, y, itemId); // 1-based index
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
}
