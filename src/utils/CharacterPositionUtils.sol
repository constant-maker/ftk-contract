pragma solidity >=0.8.24;

import {
  Kingdom,
  City,
  CityData,
  CharPositionFull,
  CharPositionFullData,
  CharPositionData,
  CharInfo,
  CharSavePoint,
  Tile
} from "@codegen/index.sol";
import { Errors } from "@common/index.sol";

library CharacterPositionUtils {
  /// @dev character must be in a capital
  function mustInCapital(uint256 characterId, uint256 capitalId) internal view {
    if (!isInCapital(characterId, capitalId)) {
      CharPositionData memory characterPosition = getCurrentPosition(characterId);
      revert Errors.MustInACapital(capitalId, characterPosition.x, characterPosition.y);
    }
  }

  /// @dev check whether character is in a capital or not
  function isInCapital(uint256 characterId, uint256 capitalId) internal view returns (bool) {
    CityData memory city = City.get(capitalId);
    if (city.kingdomId == 0) {
      revert Errors.CityIsNotExist(capitalId);
    }
    if (!city.isCapital) {
      return false;
    }
    CharPositionData memory characterPosition = getCurrentPosition(characterId);
    if (city.x == characterPosition.x && city.y == characterPosition.y) {
      return true;
    }
    return false;
  }

  /// @dev character must be in a city
  function mustInCity(uint256 characterId, uint256 cityId) internal view {
    if (!isInCity(characterId, cityId)) {
      CharPositionData memory characterPosition = getCurrentPosition(characterId);
      revert Errors.MustInACity(cityId, characterPosition.x, characterPosition.y);
    }
  }

  /// @dev check whether character is in a city or not
  function isInCity(uint256 characterId, uint256 cityId) internal view returns (bool) {
    CityData memory city = City.get(cityId);
    if (city.kingdomId == 0) {
      revert Errors.CityIsNotExist(cityId);
    }
    CharPositionData memory characterPosition = getCurrentPosition(characterId);
    if (city.x == characterPosition.x && city.y == characterPosition.y) {
      return true;
    }
    return false;
  }

  /// @dev move character to their original capital
  function moveToCapital(uint256 characterId) internal {
    uint8 kingdomId = CharInfo.getKingdomId(characterId);
    uint256 capitalId = Kingdom.getCapitalId(kingdomId);
    CityData memory city = City.get(capitalId);
    moveToLocation(characterId, city.x, city.y);
  }

  /// @dev move character to their original capital
  function moveToCapitalWithArriveTime(uint256 characterId, uint256 arriveTimestamp) internal {
    uint8 kingdomId = CharInfo.getKingdomId(characterId);
    uint256 capitalId = Kingdom.getCapitalId(kingdomId);
    CityData memory city = City.get(capitalId);
    moveToLocationWithArriveTime(characterId, city.x, city.y, arriveTimestamp);
  }

  /// @dev move character to saved point (or capital if saved point is invalid)
  function moveToSavedPoint(uint256 characterId) internal {
    moveToSavedPointWithArriveTime(characterId, block.timestamp);
  }

  /// @dev move character to saved point (or capital if saved point is invalid) with arrive time
  function moveToSavedPointWithArriveTime(uint256 characterId, uint256 arriveTimestamp) internal {
    uint256 savedCityId = CharSavePoint.getCityId(characterId);
    bool shouldMoveToCapital = false;
    CityData memory savedCity;
    if (savedCityId == 0) {
      shouldMoveToCapital = true;
    } else {
      savedCity = City.get(savedCityId);
      uint8 kingdomId = CharInfo.getKingdomId(characterId);
      uint8 tileKingdomId = Tile.getKingdomId(savedCity.x, savedCity.y);
      if (tileKingdomId != kingdomId) {
        // saved city was conquered and no longer belongs to character's kingdom
        shouldMoveToCapital = true;
      }
    }
    if (shouldMoveToCapital) {
      moveToCapitalWithArriveTime(characterId, arriveTimestamp);
      return;
    }
    // move to saved point
    CharPositionData memory currentPosition = getCurrentPosition(characterId);
    if (savedCity.x != currentPosition.x || savedCity.y != currentPosition.y) {
      // only move if not already in saved point
      moveToLocationWithArriveTime(characterId, savedCity.x, savedCity.y, arriveTimestamp);
    }
  }

  /// @dev move character to a specific location
  function moveToLocation(uint256 characterId, int32 x, int32 y) internal {
    moveToLocationWithArriveTime(characterId, x, y, block.timestamp);
  }

  /// @dev move character to a specific location with a given arrive time
  function moveToLocationWithArriveTime(uint256 characterId, int32 x, int32 y, uint256 arriveTimestamp) internal {
    CharPositionData memory currentPosition = getCurrentPosition(characterId);
    int32 currentX = currentPosition.x;
    int32 currentY = currentPosition.y;
    if (arriveTimestamp == block.timestamp) {
      // instant move to location
      currentX = x;
      currentY = y;
    }
    CharPositionFull.set(characterId, currentX, currentY, x, y, arriveTimestamp);
  }

  /// @dev get current character position base on current timestamp and character position data
  function getCurrentPosition(uint256 characterId) internal view returns (CharPositionData memory cpd) {
    CharPositionFullData memory cpf = CharPositionFull.get(characterId);
    if (block.timestamp >= cpf.arriveTimestamp) {
      return CharPositionData({ x: cpf.nextX, y: cpf.nextY });
    }
    return CharPositionData({ x: cpf.x, y: cpf.y });
  }
}
