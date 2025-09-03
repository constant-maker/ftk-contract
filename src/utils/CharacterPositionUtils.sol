pragma solidity >=0.8.24;

import {
  Kingdom,
  City,
  CityData,
  CharPosition,
  CharPositionData,
  CharNextPosition,
  CharNextPositionData,
  CharInfo,
  CharSavePoint,
  CharSavePointData,
  TileInfo3
} from "@codegen/index.sol";
import { Errors, Events } from "@common/index.sol";

library CharacterPositionUtils {
  /// @dev character must be in a capital
  function mustInCapital(uint256 characterId, uint256 capitalId) internal view {
    if (!isInCapital(characterId, capitalId)) {
      CharPositionData memory characterPosition = currentPosition(characterId);
      revert Errors.MustInACapital(capitalId, characterPosition.x, characterPosition.y);
    }
  }

  /// @dev check whether character is in a capital or not
  function isInCapital(uint256 characterId, uint256 capitalId) internal view returns (bool) {
    CityData memory city = City.get(capitalId);
    if (city.kingdomId == 0) {
      revert Errors.InvalidCityId(capitalId);
    }
    if (!city.isCapital) {
      return false;
    }
    CharPositionData memory characterPosition = currentPosition(characterId);
    if (city.x == characterPosition.x && city.y == characterPosition.y) {
      return true;
    }
    return false;
  }

  /// @dev character must be in a city
  function mustInCity(uint256 characterId, uint256 cityId) internal view {
    if (!isInCity(characterId, cityId)) {
      CharPositionData memory characterPosition = currentPosition(characterId);
      revert Errors.MustInACity(cityId, characterPosition.x, characterPosition.y);
    }
  }

  /// @dev check whether character is in a city or not
  function isInCity(uint256 characterId, uint256 cityId) internal view returns (bool) {
    CityData memory city = City.get(cityId);
    if (city.kingdomId == 0) {
      revert Errors.InvalidCityId(cityId);
    }
    CharPositionData memory characterPosition = currentPosition(characterId);
    if (city.x == characterPosition.x && city.y == characterPosition.y) {
      return true;
    }
    return false;
  }

  /// @dev move character to their original capital
  function moveToCapital(uint256 characterId) internal {
    uint8 kingdomId = CharInfo.getKingdomId(characterId);
    uint256 capitalId = Kingdom.getCapitalId(kingdomId);
    // check if character have save point => move back to that point
    CharPositionData memory currentPosition = currentPosition(characterId);
    CharSavePointData memory charSavePoint = CharSavePoint.get(characterId);
    if (charSavePoint.cityId != 0 && charSavePoint.cityId != capitalId) {
      uint8 tileKingdomId = TileInfo3.getKingdomId(charSavePoint.x, charSavePoint.y);
      if (tileKingdomId == kingdomId && (charSavePoint.x != currentPosition.x || charSavePoint.y != currentPosition.y))
      {
        moveToLocation(characterId, charSavePoint.x, charSavePoint.y);
        return;
      }
    }
    // fallback back to capital
    CityData memory city = City.get(capitalId);
    moveToLocation(characterId, city.x, city.y);
  }

  /// @dev move character to a specific location
  function moveToLocation(uint256 characterId, int32 x, int32 y) internal {
    CharPosition.set(characterId, x, y);
    CharNextPosition.set(characterId, x, y, block.timestamp);
    // emit event
    emit Events.PositionChanged(characterId, x, y, x, y, block.timestamp);
  }

  /// @dev get current character position
  function currentPosition(uint256 characterId) internal view returns (CharPositionData memory cpd) {
    CharNextPositionData memory cnpd = CharNextPosition.get(characterId);
    if (block.timestamp >= cnpd.arriveTimestamp) {
      return CharPositionData({ x: cnpd.x, y: cnpd.y });
    }
    return CharPosition.get(characterId);
  }
}
