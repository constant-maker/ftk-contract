pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharRole, City, CharInfo, CityVault, CResourceRequire, CResourceRequireData } from "@codegen/index.sol";
import { RoleType } from "@codegen/common.sol";
import { CharacterPositionUtils, CharacterRoleUtils } from "@utils/index.sol";
import { Errors } from "@common/Errors.sol";

contract CitySystem is System, CharacterAccessControl {
  function upgradeCity(uint256 characterId, uint256 cityId) public onlyAuthorizedWallet(characterId) {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);
    CharacterPositionUtils.mustBeInCity(characterId, cityId);
    uint8 cityKingdomId = City.getKingdomId(cityId);
    if (charKingdomId != cityKingdomId) {
      revert Errors.CitySystem_CityIsNotYourKingdom(charKingdomId, cityKingdomId);
    }
    uint8 currentLevel = City.getLevel(cityId);
    if (currentLevel >= 3) {
      revert Errors.CitySystem_AlreadyMaxLevel(cityId);
    }
    uint8 nextLevel = currentLevel + 1;
    CResourceRequireData memory resourceRequire = CResourceRequire.get(nextLevel);
    uint256[] memory resourceIds = resourceRequire.resourceIds;
    uint32[] memory amounts = resourceRequire.amounts;
    if (resourceIds.length != amounts.length) {
      revert Errors.CitySystem_InvalidResourceRequire(resourceIds.length, amounts.length);
    }
    for (uint256 i = 0; i < resourceIds.length; i++) {
      uint256 resourceId = resourceIds[i];
      uint32 amount = amounts[i];
      if (amount == 0) continue;
      uint32 currentVaultAmount = CityVault.getAmount(cityId, resourceId);
      if (currentVaultAmount < amount) {
        revert Errors.CitySystem_InsufficientVaultAmount(cityId, resourceId, currentVaultAmount, amount);
      }
      CityVault.setAmount(cityId, resourceId, currentVaultAmount - amount);
    }
    City.setLevel(cityId, nextLevel);
  }

  function cityHealing(uint256 characterId, uint256 cityId) public onlyAuthorizedWallet(characterId) {
    CharacterPositionUtils.mustBeInCity(characterId, cityId);
  }

}
