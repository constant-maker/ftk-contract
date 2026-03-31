pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { SalePackage, SalePackageData, CharTotalSpend } from "@codegen/index.sol";
import { CharAchievementUtils, CharacterFundUtils, InventoryItemUtils } from "@utils/index.sol";
import { PlatformUtils } from "@utils/PlatformUtils.sol";
import { Errors } from "@common/index.sol";

contract SaleSystem is CharacterAccessControl, System {
  /// @dev Purchase a sale package for a character
  function buyPackage(uint256 characterId, uint256 packageId, uint16 amount) public onlyAuthorizedWallet(characterId) {
    if (amount == 0) {
      revert Errors.SaleSystem_ZeroAmount();
    }

    SalePackageData memory salePackage = SalePackage.get(packageId);
    if (salePackage.crystalPrice == 0 && salePackage.goldPrice == 0) {
      revert Errors.SaleSystem_PackageNotFound(packageId);
    }

    // fail-safe: package should be configured for exactly one payment currency
    if (salePackage.crystalPrice > 0 && salePackage.goldPrice > 0) {
      revert Errors.SaleSystem_InvalidPackagePricing(packageId, salePackage.crystalPrice, salePackage.goldPrice);
    }

    if (salePackage.itemIds.length != salePackage.itemAmounts.length) {
      revert Errors.SaleSystem_InvalidPackageItems(packageId, salePackage.itemIds.length, salePackage.itemAmounts.length);
    }

    if (salePackage.crystalPrice > 0) {
      uint32 totalCost = salePackage.crystalPrice * amount;
      CharacterFundUtils.decreaseCrystal(characterId, totalCost);
      // update total spend
      uint256 totalSpend = CharTotalSpend.get(characterId);
      totalSpend += totalCost;
      CharTotalSpend.set(characterId, totalSpend);
      PlatformUtils.updateAppTeamCrystal(totalCost, true);
    } else {
      uint32 totalCost = salePackage.goldPrice * amount;
      CharacterFundUtils.decreaseGold(characterId, totalCost);
    }

    // claim package contents
    if (salePackage.gold > 0) {
      CharacterFundUtils.increaseGold(characterId, salePackage.gold * amount);
    }
    for (uint16 i = 0; i < salePackage.achievementIds.length; i++) {
      uint256 achievementId = salePackage.achievementIds[i];
      CharAchievementUtils.addAchievement(characterId, achievementId);
    }
    for (uint256 i = 0; i < salePackage.itemIds.length; i++) {
      uint256 itemId = salePackage.itemIds[i];
      uint32 itemAmount = salePackage.itemAmounts[i];
      // add item to character inventory
      InventoryItemUtils.addItem(characterId, itemId, itemAmount * amount);
    }
  }
}
