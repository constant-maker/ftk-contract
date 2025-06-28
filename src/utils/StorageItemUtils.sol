pragma solidity >=0.8.24;

import { CharOtherItemStorage } from "@codegen/index.sol";
import { StorageWeightUtils } from "@utils/StorageWeightUtils.sol";
import { Errors } from "@common/Errors.sol";

library StorageItemUtils {
  function addItems(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory itemIds,
    uint32[] memory amounts,
    bool checkMaxWeight
  )
    internal
  {
    require(itemIds.length == amounts.length, "Mismatched array lengths: itemIds and amounts");
    for (uint256 i = 0; i < itemIds.length; i++) {
      _updateItem(characterId, cityId, itemIds[i], amounts[i], false);
    }
    StorageWeightUtils.addItems(characterId, cityId, itemIds, amounts, checkMaxWeight);
  }

  function addItem(uint256 characterId, uint256 cityId, uint256 itemId, uint32 amount, bool checkMaxWeight) internal {
    _updateItem(characterId, cityId, itemId, amount, false);
    StorageWeightUtils.addItem(characterId, cityId, itemId, amount, checkMaxWeight);
  }

  function removeItems(uint256 characterId, uint256 cityId, uint256[] memory itemIds, uint32[] memory amounts) internal {
    require(itemIds.length == amounts.length, "Mismatched array lengths: itemIds and amounts");
    for (uint256 i = 0; i < itemIds.length; i++) {
      _updateItem(characterId, cityId, itemIds[i], amounts[i], true);
    }
    StorageWeightUtils.removeItems(characterId, cityId, itemIds, amounts);
  }

  function removeItem(uint256 characterId, uint256 cityId, uint256 itemId, uint32 amount) internal {
    _updateItem(characterId, cityId, itemId, amount, true);
    StorageWeightUtils.removeItem(characterId, cityId, itemId, amount);
  }

  function _updateItem(uint256 characterId, uint256 cityId, uint256 itemId, uint32 changeAmount, bool isReduce) private {
    if (changeAmount == 0) return;
    uint32 currentAmount = CharOtherItemStorage.getAmount(characterId, cityId, itemId);
    uint32 newAmount;
    if (isReduce) {
      if (changeAmount > currentAmount) {
        revert Errors.Storage_ExceedItemBalance(characterId, cityId, itemId, currentAmount, changeAmount);
      }
      newAmount = currentAmount - changeAmount;
    } else {
      newAmount = currentAmount + changeAmount;
    }
    if (currentAmount == 0) {
      // new record
      CharOtherItemStorage.set(characterId, cityId, itemId, characterId, newAmount);
    } else {
      CharOtherItemStorage.setAmount(characterId, cityId, itemId, newAmount);
    }
  }
}
