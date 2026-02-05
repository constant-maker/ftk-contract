pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  SalePackage, SalePackageData, CharTotalSpend
} from "@codegen/index.sol";
import { CharAchievementUtils, CharacterFundUtils, InventoryItemUtils } from "@utils/index.sol";
import { Errors } from "@common/index.sol";

contract SaleSystem is CharacterAccessControl, System {
  function buyPackage(uint256 characterId, uint256 packageId, uint16 amount) public onlyCharacterOwner(characterId) {
    // SalePackageData memory salePackage = SalePackage.get(packageId);
    // if (salePackage.price == 0) {
    //   revert Errors.SaleSystem_PackageNotFound(packageId);
    // }
    // uint256 value = _msgValue();
    // if (value < salePackage.price * amount) {
    //   revert Errors.InsufficientPayment(value, salePackage.price * amount);
    // }
    // // update total spend
    // uint256 totalSpend = CharTotalSpend.get(characterId).total;
    // totalSpend += value;
    // CharTotalSpend.set(characterId, totalSpend);

    // // claim package contents
    // if (salePackage.crystal > 0) {
    //   CharacterFundUtils.increaseCrystal(characterId, salePackage.crystal * amount);
    // }
    // if (salePackage.gold > 0) {
    //   CharacterFundUtils.increaseGold(characterId, salePackage.gold * amount);
    // }
    // for (uint16 i = 0; i < salePackage.achievementIds.length; i++) {
    //   uint256 achievementId = salePackage.achievementIds[i];
    //   CharAchievementUtils.addAchievement(characterId, achievementId);
    // }
    // for (uint256 i = 0; i < salePackage.itemIds.length; i++) {
    //   uint256 itemId = salePackage.itemIds[i];
    //   uint32 amount = salePackage.itemAmounts[i];
    //   // add item to character inventory
    //   InventoryItemUtils.addItem(characterId, itemId, amount);
    // }
  }
}
