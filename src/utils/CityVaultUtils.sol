pragma solidity >=0.8.24;

import { CityVault2, Kingdom } from "@codegen/index.sol";
import { Errors } from "@common/index.sol";

library CityVaultUtils {

  /// @dev Update the crystal amount in the kingdom capital vault
  function updateVaultCrystalByKingdomId(uint8 kingdomId, uint256 amount, bool isGained) internal {
    uint256 capitalId = Kingdom.getCapitalId(kingdomId);
    updateVaultCrystal(capitalId, amount, isGained);
  }

  /// @dev Update the crystal amount in the city vault
  function updateVaultCrystal(uint256 cityId, uint256 amount, bool isGained) internal {
    if (amount == 0) return;
    uint256 currentCrystal = CityVault2.getCrystal(cityId);
    if (isGained) {
      CityVault2.setCrystal(cityId, currentCrystal + amount);
      return;
    }
    if (currentCrystal < amount) {
      revert Errors.InsufficientCrystal(currentCrystal, amount);
    }
    CityVault2.setCrystal(cityId, currentCrystal - amount);
  }

  /// @dev Update the gold amount in the city vault
  function updateVaultGold(uint256 cityId, uint256 amount, bool isGained) internal {
    if (amount == 0) return;
    uint256 currentGold = CityVault2.getGold(cityId);
    if (isGained) {
      CityVault2.setGold(cityId, currentGold + amount);
      return;
    }
    if (currentGold < amount) {
      revert Errors.InsufficientGold(currentGold, amount);
    }
    CityVault2.setGold(cityId, currentGold - amount);
  }
}
