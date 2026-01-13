pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { Errors } from "@common/Errors.sol";
import { CharacterPositionUtils, CharacterItemUtils, InventoryItemUtils } from "@utils/index.sol";
import { City, CharCollection, CollectionExcV2, CollectionExcV2Data, ItemV2 } from "@codegen/index.sol";
import { ItemCategoryType } from "@codegen/common.sol";

contract CollectionSystem is System, CharacterAccessControl {
  /// @dev delegate to specific session wallet
  function addToCollection(
    uint256 characterId,
    uint256 capitalId,
    uint256[] calldata itemIds,
    uint32[] calldata amounts
  )
    public
    onlyCharacterOwner(characterId)
  {
    if (itemIds.length != amounts.length) {
      revert Errors.CollectionSystem_InvalidParams(itemIds.length, amounts.length);
    }
    CharacterPositionUtils.mustInCapital(characterId, capitalId);

    // deduct from inventory
    InventoryItemUtils.removeItems(characterId, itemIds, amounts);

    // add to collection
    for (uint256 i = 0; i < itemIds.length; i++) {
      uint256 itemId = itemIds[i];
      uint32 amount = amounts[i];
      if (amount == 0) {
        continue;
      }
      uint32 currentAmount = CharCollection.get(characterId, itemId);
      // add to collection
      uint256 newAmount = uint256(currentAmount) + uint256(amount);
      if (newAmount > type(uint32).max) {
        revert Errors.CollectionSystem_ExceedMaxAmount(characterId, itemId);
      }
      CharCollection.set(characterId, itemId, uint32(newAmount));
    }
  }

  function exchangeItem(uint256 characterId, uint256 itemId, uint32 amount) public onlyCharacterOwner(characterId) {
    CollectionExcV2Data memory exchangeData = CollectionExcV2.get(itemId);
    if (exchangeData.inputItemIds.length == 0) {
      revert Errors.CollectionSystem_ExchangeNotExist(itemId);
    }
    // deduct input items
    for (uint256 i = 0; i < exchangeData.inputItemAmounts.length; i++) {
      uint256 inputItemId = exchangeData.inputItemIds[i];
      uint32 amountRequire = exchangeData.inputItemAmounts[i] * uint32(amount);
      uint32 currentAmount = CharCollection.get(characterId, inputItemId);
      if (currentAmount < amountRequire) {
        revert Errors.CollectionSystem_InsufficientItemAmount(
          characterId, inputItemId, itemId, amountRequire, currentAmount
        );
      }
      CharCollection.set(characterId, inputItemId, currentAmount - amountRequire);
    }
    // add output items
    CharacterItemUtils.addNewItem(characterId, itemId, amount); // add to inventory
  }
}
