pragma solidity >=0.8.24;

import { CharOtherItem } from "@codegen/index.sol";
import { CharacterWeightUtils } from "@utils/CharacterWeightUtils.sol";
import { Errors } from "@common/Errors.sol";

library InventoryItemUtils {
  function addItems(uint256 characterId, uint256[] memory itemIds, uint32[] memory amounts) internal {
    require(itemIds.length == amounts.length, "Mismatched array lengths: itemIds and amounts");
    for (uint256 i = 0; i < itemIds.length; i++) {
      _updateItem(characterId, itemIds[i], amounts[i], false);
    }
    CharacterWeightUtils.addItems(characterId, itemIds, amounts);
  }

  function addItem(uint256 characterId, uint256 itemId, uint32 amount) internal {
    _updateItem(characterId, itemId, amount, false);
    CharacterWeightUtils.addItem(characterId, itemId, amount);
  }

  function removeItems(uint256 characterId, uint256[] memory itemIds, uint32[] memory amounts) internal {
    require(itemIds.length == amounts.length, "Mismatched array lengths: itemIds and amounts");
    for (uint256 i = 0; i < itemIds.length; i++) {
      _updateItem(characterId, itemIds[i], amounts[i], true);
    }
    CharacterWeightUtils.removeItems(characterId, itemIds, amounts);
  }

  function removeItem(uint256 characterId, uint256 itemId, uint32 amount) internal {
    _updateItem(characterId, itemId, amount, true);
    CharacterWeightUtils.removeItem(characterId, itemId, amount);
  }

  function _updateItem(uint256 characterId, uint256 itemId, uint32 changeAmount, bool isReduce) private {
    if (changeAmount == 0) return;
    uint32 currentAmount = CharOtherItem.getAmount(characterId, itemId);
    uint32 newAmount;
    if (isReduce) {
      if (changeAmount > currentAmount) {
        revert Errors.Inventory_ExceedItemBalance(characterId, itemId, currentAmount, changeAmount);
      }
      newAmount = currentAmount - changeAmount;
    } else {
      newAmount = currentAmount + changeAmount;
    }
    if (currentAmount == 0) {
      // new record
      CharOtherItem.set(characterId, itemId, characterId, newAmount);
    } else {
      CharOtherItem.setAmount(characterId, itemId, newAmount);
    }
  }
}
