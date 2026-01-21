pragma solidity >=0.8.24;

import { GachaV4, GachaItemIndex } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";

library GachaUtils {
  /// This lib provides utility functions for managing gacha items, but for LIMITED gacha only.
  /// LIMITED gacha means that once an item is drawn, it is removed from the gacha pool.

  /// @dev Add items to gacha
  function addItems(uint256 gachaId, uint256[] memory itemIds) internal {
    uint256 length = itemIds.length;
    for (uint256 i = 0; i < length; i++) {
      addItem(gachaId, itemIds[i]);
    }
  }

  /// @dev Add a item to gacha
  function addItem(uint256 gachaId, uint256 itemId) internal {
    if (hasItem(gachaId, itemId)) {
      revert Errors.Gacha_AlreadyHad(gachaId, itemId);
    }
    GachaV4.pushItemIds(gachaId, itemId);
    // The value is stored at length-1, but we add 1 to all indexes
    // and use 0 as a sentinel value
    uint256 index = GachaV4.lengthItemIds(gachaId);
    GachaItemIndex.set(gachaId, itemId, index);
  }

  /// @dev Remove items from gacha
  function removeItems(uint256 gachaId, uint256[] memory itemIds) internal {
    uint256 length = itemIds.length;
    for (uint256 i = 0; i < length; i++) {
      removeItem(gachaId, itemIds[i]);
    }
  }

  /// @dev Remove a item from gacha
  function removeItem(uint256 gachaId, uint256 itemId) internal {
    uint256 index = GachaItemIndex.get(gachaId, itemId);
    if (index == 0) revert Errors.Gacha_NoItem(gachaId, itemId);
    // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
    // the array, and then remove the last element (sometimes called as 'swap and pop').
    // This modifies the order of the array, as noted in {at}.
    uint256 valueIndex = index - 1;
    uint256 lastIndex = GachaV4.lengthItemIds(gachaId) - 1;
    if (valueIndex != lastIndex) {
      uint256 lastItemIdValue = GachaV4.getItemItemIds(gachaId, lastIndex);
      GachaV4.updateItemIds(gachaId, valueIndex, lastItemIdValue);
      // Update the index for the moved value
      GachaItemIndex.set(gachaId, lastItemIdValue, index);
    }
    GachaV4.popItemIds(gachaId);
    GachaItemIndex.deleteRecord(gachaId, itemId);
  }

  /// @dev Return whether the gacha has the item
  function hasItem(uint256 gachaId, uint256 itemId) internal view returns (bool) {
    uint256 index = GachaItemIndex.get(gachaId, itemId);
    return index != 0;
  }
}
