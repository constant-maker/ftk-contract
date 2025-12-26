pragma solidity >=0.8.24;

import { Gacha, GachaItemIndex } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";

library GachaUtils {
  /// @dev Add items to gacha
  function addItems(uint256 gachaId, uint256[] memory itemIds) internal {
    for (uint256 i = 0; i < itemIds.length; i++) {
      addItem(gachaId, itemIds[i]);
    }
  }

  /// @dev Add a item to gacha
  function addItem(uint256 gachaId, uint256 itemId) internal {
    if (hasItem(gachaId, itemId)) {
      revert Errors.Gacha_AlreadyHad(gachaId, itemId);
    }
    Gacha.pushItemIds(gachaId, itemId);
    // The value is stored at length-1, but we add 1 to all indexes
    // and use 0 as a sentinel value
    uint256 index = Gacha.lengthItemIds(gachaId);
    GachaItemIndex.set(gachaId, itemId, index);
  }

  /// @dev Remove items from gacha
  function removeItems(uint256 gachaId, uint256[] memory itemIds) internal {
    for (uint256 i = 0; i < itemIds.length; i++) {
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
    uint256 lastIndex = Gacha.lengthItemIds(gachaId) - 1;
    if (valueIndex != lastIndex) {
      uint256 lastValue = Gacha.getItemItemIds(gachaId, lastIndex);
      Gacha.updateItemIds(gachaId, valueIndex, lastValue);
      GachaItemIndex.set(gachaId, lastValue, index);
    }
    Gacha.popItemIds(gachaId);
    GachaItemIndex.deleteRecord(gachaId, itemId);
  }

  /// @dev Return whether the gacha has the item
  function hasItem(uint256 gachaId, uint256 itemId) internal view returns (bool) {
    uint256 index = GachaItemIndex.get(gachaId, itemId);
    return index != 0;
  }
}
