pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
import {
  SalePackage,
  SalePackageData,
  CharTotalSpend,
  CharFund,
  MarketFeeCrystal,
  CharInfo,
  Kingdom,
  CityVault2V2
} from "@codegen/index.sol";
import { CharAchievementUtils, CharacterFundUtils, InventoryItemUtils } from "@utils/index.sol";
import { UWorldUtils } from "@utils/UWorldUtils.sol";
import { Config, Errors } from "@common/index.sol";

contract PortalSystem is CharacterAccessControl, System {
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
    uint8 kingdomId = CharInfo.getKingdomId(characterId);
    CharacterFundUtils.decreaseCrystal(characterId, amount);
    uint32 platformFeeCrystal = (amount * uint32(Config.PLATFORM_FEE_PERCENTAGE) + 99) / 100;
    uint32 remainAmount = amount - platformFeeCrystal;
    uint8 kingdomFeePercentage = MarketFeeCrystal.getFee(kingdomId);
    uint32 kingdomFeeCrystal = (remainAmount * uint32(kingdomFeePercentage)) / 100;
    uint32 netAmount = remainAmount - kingdomFeeCrystal;

    uint256 platformFeeEth = platformFeeCrystal * Config.CRYSTAL_UNIT_PRICE;
    uint256 receivedEth = netAmount * Config.CRYSTAL_UNIT_PRICE;
    UWorldUtils.transferTo(_msgSender(), receivedEth);
    UWorldUtils.transferToTeam(platformFeeEth);

    // kingdom fee will be sent to city vault
    if (kingdomFeeCrystal > 0) {
      uint256 capitalId = Kingdom.getCapitalId(kingdomId);
      uint256 currentVaultCrystal = CityVault2V2.getCrystal(capitalId);
      CityVault2V2.setCrystal(capitalId, currentVaultCrystal + uint256(kingdomFeeCrystal));
    }
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
