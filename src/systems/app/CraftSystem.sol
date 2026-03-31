pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { Item, ItemRecipe, ItemRecipeData, CharPerk } from "@codegen/index.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { CharacterItemUtils } from "@utils/CharacterItemUtils.sol";
import { CharacterPerkUtils } from "@utils/CharacterPerkUtils.sol";
import { Errors } from "@common/Errors.sol";
import { ItemCategoryType, ItemType } from "@codegen/common.sol";
import { Config } from "@common/index.sol";

contract CraftSystem is System, CharacterAccessControl {
  /// @dev craft item when character has enough resources
  function craftItem(
    uint256 characterId,
    uint256 cityId,
    uint256 craftItemId,
    uint32 craftAmount
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    CharacterPositionUtils.mustInExactCapital(characterId, cityId);
    if (craftAmount == 0) {
      revert Errors.CraftSystem_CraftAmountIsZero();
    }
    ItemRecipeData memory recipe = ItemRecipe.get(craftItemId);
    // check perk requirement
    _validateRecipe(characterId, craftItemId, recipe);
    // spend gold
    CharacterFundUtils.decreaseGold(characterId, recipe.goldCost * craftAmount);
    // spend resources
    uint256 resourcesLength = recipe.itemIds.length;
    if (resourcesLength > 0) {
      uint32[] memory sumAmounts = new uint32[](resourcesLength);
      for (uint256 i = 0; i < resourcesLength; i++) {
        sumAmounts[i] = recipe.amounts[i] * craftAmount;
      }
      InventoryItemUtils.removeItems(characterId, recipe.itemIds, sumAmounts);
    }
    // add crafted item
    CharacterItemUtils.addNewItem(characterId, craftItemId, craftAmount);
  }

  function _validateRecipe(uint256 characterId, uint256 craftItemId, ItemRecipeData memory recipe) private view {
    if (recipe.itemIds.length == 0) {
      revert Errors.CraftSystem_NoRecipeForItem(craftItemId);
    }
    if (recipe.itemIds.length != recipe.amounts.length) {
      revert Errors.CraftSystem_InvalidRecipeData(craftItemId);
    }
    uint256 lenPerkTypes = recipe.perkTypes.length;
    if (lenPerkTypes > 0) {
      if (lenPerkTypes != recipe.requiredPerkLevels.length) {
        revert Errors.CraftSystem_InvalidRecipeData(craftItemId);
      }
      for (uint256 i = 0; i < lenPerkTypes; i++) {
        uint8 currentPerk = CharacterPerkUtils.getPerkLevel(characterId, ItemType(recipe.perkTypes[i]));
        if (currentPerk < recipe.requiredPerkLevels[i]) {
          revert Errors.CraftSystem_PerkLevelIsNotEnough(characterId, craftItemId);
        }
      }
    }
  }
}
