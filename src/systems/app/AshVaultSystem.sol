pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { Errors } from "@common/Errors.sol";
import { CharacterPositionUtils, CharacterItemUtils, InventoryItemUtils } from "@utils/index.sol";
import { City, CharAshVault, AshVaultExc, AshVaultExcData, Item } from "@codegen/index.sol";
import { ItemCategoryType } from "@codegen/common.sol";

contract AshVaultSystem is System, CharacterAccessControl {
  /// @dev delegate to specific session wallet
  function addToAshVault(
    uint256 characterId,
    uint256 capitalId,
    uint256[] calldata itemIds,
    uint32[] calldata amounts
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    if (itemIds.length != amounts.length) {
      revert Errors.AshVaultSystem_InvalidParams(itemIds.length, amounts.length);
    }
    CharacterPositionUtils.mustInCapital(characterId, capitalId);

    // deduct from inventory
    InventoryItemUtils.removeItems(characterId, itemIds, amounts);

    // add to ash vault
    uint256 iLen = itemIds.length;
    for (uint256 i = 0; i < iLen; i++) {
      uint256 itemId = itemIds[i];
      uint32 amount = amounts[i];
      if (amount == 0) {
        continue;
      }
      uint32 currentAmount = CharAshVault.get(characterId, itemId);
      // add to ash vault
      uint256 newAmount = uint256(currentAmount) + uint256(amount);
      if (newAmount > type(uint32).max) {
        revert Errors.AshVaultSystem_ExceedMaxAmount(characterId, itemId);
      }
      CharAshVault.set(characterId, itemId, uint32(newAmount));
    }
  }

  function exchangeItem(uint256 characterId, uint256 itemId, uint32 amount) public onlyAuthorizedWallet(characterId) {
    AshVaultExcData memory exchangeData = AshVaultExc.get(itemId);
    if (exchangeData.inputItemIds.length == 0) {
      revert Errors.AshVaultSystem_ExchangeNotExist(itemId);
    }
    // deduct input items
    uint256 len = exchangeData.inputItemIds.length;
    for (uint256 i = 0; i < len; i++) {
      uint256 inputItemId = exchangeData.inputItemIds[i];
      uint32 amountRequire = exchangeData.inputItemAmounts[i] * uint32(amount);
      uint32 currentAmount = CharAshVault.get(characterId, inputItemId);
      if (currentAmount < amountRequire) {
        revert Errors.AshVaultSystem_InsufficientItemAmount(
          characterId, inputItemId, itemId, amountRequire, currentAmount
        );
      }
      CharAshVault.set(characterId, inputItemId, currentAmount - amountRequire);
    }
    // add output items
    CharacterItemUtils.addNewItem(characterId, itemId, amount); // add to inventory
  }
}
