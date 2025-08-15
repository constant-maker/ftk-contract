pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharRole,
  City,
  CityData,
  CharInfo,
  CityVault,
  CResourceRequire,
  CResourceRequireData,
  CharCurrentStats,
  CharStats,
  CharSavePoint,
  TileInfo3
} from "@codegen/index.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { CharacterPositionUtils, CharacterRoleUtils, CharacterFundUtils } from "@utils/index.sol";
import { Errors } from "@common/Errors.sol";

contract CitySystem is System, CharacterAccessControl {
  uint32 constant TELEPORT_COST = 100;

  function upgradeCity(uint256 characterId, uint256 cityId) public onlyAuthorizedWallet(characterId) {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterPositionUtils.mustInCity(characterId, cityId);
    uint8 cityKingdomId = City.getKingdomId(cityId);
    if (charKingdomId != cityKingdomId) {
      revert Errors.CitySystem_CityIsNotYourKingdom(charKingdomId, cityKingdomId);
    }
    _mustBeActive(cityId, cityKingdomId);
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
    _validateCity(characterId, cityId, 1);
    CharacterPositionUtils.mustInCity(characterId, cityId);
    uint32 currentHp = CharCurrentStats.getHp(characterId);
    uint32 maxHp = CharStats.getHp(characterId);
    uint32 missingHp = maxHp - currentHp;
    if (missingHp == 0) return;
    uint32 goldCost = missingHp / 50;
    if (goldCost != 0) {
      CharacterFundUtils.decreaseGold(characterId, goldCost);
    }
    CharCurrentStats.setHp(characterId, maxHp);
  }

  function citySavePoint(uint256 characterId, uint256 cityId) public onlyAuthorizedWallet(characterId) {
    _validateCity(characterId, cityId, 2);
    CharacterPositionUtils.mustInCity(characterId, cityId);
    CityData memory city = City.get(cityId);
    CharSavePoint.set(characterId, cityId, city.x, city.y);
  }

  function cityTeleport(
    uint256 characterId,
    uint256 fromCityId,
    uint256 toCityId
  )
    public
    onlyAuthorizedWallet(characterId)
    mustInState(characterId, CharacterStateType.Standby)
  {
    _validateCity(characterId, toCityId, 3);
    CharacterPositionUtils.mustInCity(characterId, fromCityId);
    CityData memory fromCity = City.get(fromCityId);
    CityData memory toCity = City.get(toCityId);
    if (!fromCity.isCapital) {
      revert Errors.CitySystem_FromCityIsNotCapital(fromCityId);
    }
    if (toCity.isCapital) {
      revert Errors.CitySystem_ToCityIsCapital(toCityId);
    }
    // this ensure fromCity is also from same kingdom with character, because we already check in _validateCity
    if (fromCity.kingdomId != toCity.kingdomId) {
      revert Errors.CitySystem_CitiesNotInSameKingdom(fromCityId, toCityId);
    }
    CharacterFundUtils.decreaseGold(characterId, TELEPORT_COST);
    CharacterPositionUtils.moveToLocation(characterId, toCity.x, toCity.y);
  }

  /// @dev Validate the city for the given action, ensuring it meets the required level
  /// and that the city still belongs to the character's kingdom (by tile).
  function _validateCity(uint256 characterId, uint256 cityId, uint8 requiredLevel) private view {
    if (cityId == 0) {
      revert Errors.InvalidCityId(cityId);
    }

    // character vs city kingdom
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    uint8 cityKingdomId = City.getKingdomId(cityId);
    if (charKingdomId != cityKingdomId) {
      revert Errors.CitySystem_CityIsNotYourKingdom(charKingdomId, cityKingdomId);
    }

    // city level
    uint8 cityLevel = City.getLevel(cityId);
    if (cityLevel < requiredLevel) {
      revert Errors.CitySystem_CityLevelTooLow(cityId, cityLevel);
    }

    _mustBeActive(cityId, cityKingdomId);
  }

  /// @dev Check if city kingdom id same as tile kingdom id
  function _mustBeActive(uint256 cityId, uint8 cityKingdomId) private view {
    // check tile ownership
    int32 x = City.getX(cityId);
    int32 y = City.getY(cityId);
    uint8 tileKingdomId = TileInfo3.getKingdomId(x, y);
    if (tileKingdomId != cityKingdomId) {
      revert Errors.CitySystem_CityBelongsToOtherKingdom(cityKingdomId, tileKingdomId);
    }
  }
}
