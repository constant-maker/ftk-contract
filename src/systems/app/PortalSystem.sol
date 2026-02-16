pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
import { SalePackage, SalePackageData, CharTotalSpend, CharFund } from "@codegen/index.sol";
import { CharAchievementUtils, CharacterFundUtils, InventoryItemUtils } from "@utils/index.sol";
import { UWorldUtils } from "@utils/UWorldUtils.sol";
import { Config, Errors } from "@common/index.sol";

contract PortalSystem is CharacterAccessControl, System {
  uint256 constant SELL_CRYSTAL_FEE_PERCENTAGE = 5; // 5% fee when selling crystals

  function buyCrystal(uint256 characterId, uint32 amount) public payable onlyAuthorizedWallet(characterId) {
    _validateCrystalAmount(amount);
    uint256 value = _msgValue();
    uint256 requiredPayment = amount * Config.CRYSTAL_UNIT_PRICE;
    if (value != requiredPayment) {
      revert Errors.InsufficientPayment(value, requiredPayment);
    }
    CharacterFundUtils.increaseCrystal(characterId, amount);
  }

  function sellCrystal(uint256 characterId, uint32 amount) public onlyAuthorizedWallet(characterId) {
    uint32 currentCrystals = CharFund.getCrystal(characterId);
    if (currentCrystals < amount) {
      revert Errors.PortalSystem_InsufficientCrystal(currentCrystals, amount);
    }
    _validateCrystalAmount(amount);
    CharacterFundUtils.decreaseCrystal(characterId, amount);
    uint256 rawPayment = amount * Config.CRYSTAL_UNIT_PRICE;
    uint256 fee = (rawPayment * SELL_CRYSTAL_FEE_PERCENTAGE + 99) / 100; // rounding up
    uint256 paymentAmount = rawPayment - fee;
    UWorldUtils.transferTo(_msgSender(), paymentAmount);
    UWorldUtils.transferToTeam(fee);
  }

  function _validateCrystalAmount(uint32 amount) private view {
    if (amount < Config.MIN_CRYSTALS_PER_PURCHASE) {
      revert Errors.PortalSystem_CrystalAmountTooSmall(amount, Config.MIN_CRYSTALS_PER_PURCHASE);
    }
    if (amount % Config.MIN_CRYSTALS_PER_PURCHASE != 0) {
      revert Errors.InvalidCrystalAmount(amount, Config.MIN_CRYSTALS_PER_PURCHASE);
    }
  }
}
