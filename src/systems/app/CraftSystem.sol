pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { ItemRecipe, ItemRecipeData } from "@codegen/index.sol";
import { Item } from "@codegen/tables/Item.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { CharacterItemUtils } from "@utils/CharacterItemUtils.sol";
import { Errors } from "@common/Errors.sol";
import { ItemCategoryType } from "@codegen/common.sol";

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
    ItemRecipeData memory recipe = ItemRecipe.get(craftItemId);
    uint256 resourcesLength = recipe.itemIds.length;
    if (resourcesLength == 0) {
      revert Errors.CraftSystem_NoRecipeForItem(craftItemId);
    }
    // Spend gold
    CharacterFundUtils.decreaseGold(characterId, recipe.goldCost * craftAmount);
    // Spend resources
    uint32[] memory sumAmounts = new uint32[](resourcesLength);
    for (uint256 i = 0; i < resourcesLength; i++) {
      sumAmounts[i] = recipe.amounts[i] * craftAmount;
    }
    InventoryItemUtils.removeItems(characterId, recipe.itemIds, sumAmounts);
    // Add crafted item
    CharacterItemUtils.addNewItem(characterId, craftItemId, craftAmount);
  }
}
