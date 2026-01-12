pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { Errors } from "@common/Errors.sol";
import { CharacterPositionUtils, CharacterItemUtils, InventoryItemUtils } from "@utils/index.sol";
import { City, CharCollection, CollectionExchange, ItemV2 } from "@codegen/index.sol";
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

  function exchangeItem(
    uint256 characterId,
    uint256 inputItemId,
    uint256 outputItemId,
    uint32 outputItemAmount
  )
    public
    onlyCharacterOwner(characterId)
  {
    uint32 inputAmountRequire = CollectionExchange.get(inputItemId, outputItemId);
    if (inputAmountRequire == 0) {
      revert Errors.CollectionSystem_ExchangeNotExist(inputItemId, outputItemId);
    }
    // total input amount required
    uint32 totalAmountRequire = inputAmountRequire * outputItemAmount;
    uint32 currentAmount = CharCollection.get(characterId, inputItemId);
    if (currentAmount < totalAmountRequire) {
      revert Errors.CollectionSystem_InsufficientItemAmount(
        characterId, inputItemId, outputItemId, totalAmountRequire, currentAmount
      );
    }
    // deduct input items
    CharCollection.set(characterId, inputItemId, currentAmount - totalAmountRequire);
    // add output items
    CharacterItemUtils.addNewItem(characterId, outputItemId, outputItemAmount); // add to inventory
  }
}
