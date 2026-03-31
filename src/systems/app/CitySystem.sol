pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  City,
  CityData,
  CharInfo,
  CityVault,
  CityVault2,
  CResourceRequire,
  CResourceRequireData,
  CharCurrentStats,
  CharStats,
  CharSavePoint,
  Kingdom
} from "@codegen/index.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { CharacterPositionUtils, CharacterRoleUtils, CharacterFundUtils, MapUtils } from "@utils/index.sol";
import { Errors } from "@common/Errors.sol";

contract CitySystem is System, CharacterAccessControl {
  uint32 constant TELEPORT_COST = 15;
  uint32 constant UPGRADE_GOLD_COST = 5000;
  uint32 constant MAX_CITY_LEVEL = 3;

  function upgradeCity(uint256 characterId, uint256 cityId) public onlyAuthorizedWallet(characterId) {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterPositionUtils.mustInCity(characterId, cityId);
    uint8 cityKingdomId = City.getKingdomId(cityId);
    if (charKingdomId != cityKingdomId) {
      revert Errors.CitySystem_CityIsNotYourKingdom(charKingdomId, cityKingdomId);
    }
    MapUtils.mustBeActiveCity(cityId);
    uint8 currentLevel = City.getLevel(cityId);
    if (currentLevel >= MAX_CITY_LEVEL) {
      revert Errors.CitySystem_AlreadyMaxLevel(cityId);
    }
    uint8 nextLevel = currentLevel + 1;
    CResourceRequireData memory resourceRequire = CResourceRequire.get(nextLevel);
    uint256[] memory resourceIds = resourceRequire.resourceIds;
    uint32[] memory amounts = resourceRequire.amounts;
    if (resourceIds.length != amounts.length) {
      revert Errors.CitySystem_InvalidResourceRequire(resourceIds.length, amounts.length);
    }
    uint256 rLen = resourceIds.length;
    for (uint256 i = 0; i < rLen; i++) {
      uint256 resourceId = resourceIds[i];
      uint32 amount = amounts[i];
      if (amount == 0) continue;
      uint32 currentVaultAmount = CityVault.getAmount(cityId, resourceId);
      if (currentVaultAmount < amount) {
        revert Errors.CitySystem_InsufficientVaultAmount(cityId, resourceId, currentVaultAmount, amount);
      }
      CityVault.setAmount(cityId, resourceId, currentVaultAmount - amount);
    }
    uint32 requiredGold = nextLevel * UPGRADE_GOLD_COST;
    _updateCityGold(cityId, requiredGold, false);
    City.setLevel(cityId, nextLevel);
  }

  function cityHealing(uint256 characterId, uint256 cityId) public onlyAuthorizedWallet(characterId) {
    _validateCity(characterId, cityId, 1); // require city level 1 or above for healing
    CharacterPositionUtils.mustInCity(characterId, cityId);
    uint32 currentHp = CharCurrentStats.getHp(characterId);
    uint32 maxHp = CharStats.getHp(characterId);
    // safe check for overflow, and also if character is already full hp, no need to charge gold
    if (currentHp >= maxHp) return;
    uint32 missingHp = maxHp - currentHp;
    uint32 goldCost = missingHp / 50;
    if (missingHp % 50 != 0) {
      goldCost++;
    }
    CharacterFundUtils.decreaseGold(characterId, goldCost);
    CharCurrentStats.setHp(characterId, maxHp);
    _updateCityGold(cityId, goldCost, true);
  }

  function citySavePoint(uint256 characterId, uint256 cityId) public onlyAuthorizedWallet(characterId) {
    _validateCity(characterId, cityId, 2); // require city level 2 or above for save point
    CharacterPositionUtils.mustInCity(characterId, cityId);
    CharSavePoint.set(characterId, cityId);
  }

  function cityTeleport(
    uint256 characterId,
    uint256 fromCityId,
    uint256 toCityId
  )
    public
    onlyAuthorizedWallet(characterId)
    mustInState(characterId, CharacterStateType.Standby)
    validateCurrentWeight(characterId)
  {
    if (fromCityId == toCityId) {
      revert Errors.CitySystem_SameCityTeleportation(fromCityId);
    }
    // require both cities level 3 or above for teleportation
    _validateCity(characterId, fromCityId, 3);
    _validateCity(characterId, toCityId, 3);
    CharacterPositionUtils.mustInCity(characterId, fromCityId);
    CityData memory toCity = City.get(toCityId);
    CharacterFundUtils.decreaseGold(characterId, TELEPORT_COST);
    CharacterPositionUtils.moveToLocation(characterId, toCity.x, toCity.y);
    _updateCityGold(fromCityId, TELEPORT_COST, true);
  }

  /// @dev Validate the city for the given action, ensuring it meets the required level
  /// and that the city still belongs to the character's kingdom (by tile).
  function _validateCity(uint256 characterId, uint256 cityId, uint8 requiredLevel) private view {
    if (cityId == 0) {
      revert Errors.CityIsNotExist(cityId);
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

    MapUtils.mustBeActiveCity(cityId);
  }

  function _updateCityGold(uint256 cityId, uint32 goldChange, bool isGain) private {
    uint256 currentGold = CityVault2.getGold(cityId);
    if (isGain) {
      CityVault2.setGold(cityId, currentGold + goldChange);
    } else {
      if (currentGold < goldChange) {
        revert Errors.CitySystem_InsufficientVaultGold(cityId, currentGold, goldChange);
      }
      CityVault2.setGold(cityId, currentGold - goldChange);
    }
  }
}
