pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { ItemV2, ItemRecipeV3, ItemRecipeV3Data, CharPerk, CharStats2 } from "@codegen/index.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { CharacterItemUtils } from "@utils/CharacterItemUtils.sol";
import { Errors } from "@common/Errors.sol";
import { ItemCategoryType, ItemType } from "@codegen/common.sol";

contract CraftSystem is System, CharacterAccessControl {
  /// @dev Craft item when character has enough resources
  function craftItem(
    uint256 characterId,
    uint256 cityId,
    uint256 craftItemId,
    uint32 craftAmount
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    if (!CharacterPositionUtils.isInCity(characterId, cityId)) {
      revert Errors.CraftSystem_MustInACity(characterId);
    }
    if (craftAmount == 0) {
      revert Errors.CraftSystem_CraftAmountIsZero();
    }
    ItemRecipeV3Data memory recipe = ItemRecipeV3.get(craftItemId);
    // Check perk requirement
    _validateRecipe(characterId, craftItemId, recipe);
    // Spend gold
    CharacterFundUtils.decreaseGold(characterId, recipe.goldCost * craftAmount);
    // Spend fame
    _spendFame(characterId, recipe.fameCost * craftAmount);
    // Spend resources
    uint256 resourcesLength = recipe.itemIds.length;
    if (resourcesLength > 0) {
      uint32[] memory sumAmounts = new uint32[](resourcesLength);
      for (uint256 i = 0; i < resourcesLength; i++) {
        sumAmounts[i] = recipe.amounts[i] * craftAmount;
      }
      InventoryItemUtils.removeItems(characterId, recipe.itemIds, sumAmounts);
    }
    // Add crafted item
    CharacterItemUtils.addNewItem(characterId, craftItemId, craftAmount);
  }

  function _spendFame(uint256 characterId, uint32 fameCost) private {
    if (fameCost == 0) {
      return;
    }
    uint32 charFame = CharStats2.getFame(characterId);
    if (charFame < fameCost) {
      revert Errors.CraftSystem_NotEnoughFame(characterId, charFame, fameCost);
    }
    CharStats2.setFame(characterId, charFame - fameCost);
  }

  function _validateRecipe(uint256 characterId, uint256 craftItemId, ItemRecipeV3Data memory recipe) private view {
    if (recipe.fameCost == 0 && recipe.itemIds.length == 0) {
      revert Errors.CraftSystem_NoRecipeForItem(craftItemId);
    }
    uint256 lenPerkTypes = recipe.perkTypes.length;
    if (lenPerkTypes > 0) {
      if (lenPerkTypes != recipe.requiredPerkLevels.length) {
        revert Errors.CraftSystem_InvalidRecipeData(craftItemId);
      }
      for (uint256 i = 0; i < lenPerkTypes; i++) {
        uint8 currentPerk = CharPerk.getLevel(characterId, ItemType(recipe.perkTypes[i])) + 1; // +1 because perk start
          // from 0
        if (currentPerk < recipe.requiredPerkLevels[i]) {
          revert Errors.CraftSystem_PerkLevelIsNotEnough(characterId, craftItemId);
        }
      }
    }
  }
}
