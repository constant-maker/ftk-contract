pragma solidity >=0.8.24;

import {
  Kingdom,
  City,
  CityData,
  CharPosition,
  CharPositionData,
  CharNextPosition,
  CharNextPositionData,
  CharInfo
} from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";

library CharacterPositionUtils {
  /// @dev check whether character is in a capital or not
  function isInCapital(uint256 characterId, uint256 capitalId) internal view returns (bool) {
    CityData memory city = City.get(capitalId);
    if (city.kingdomId == 0) {
      revert Errors.InvalidCityId(capitalId);
    }
    if (!city.isCapital) {
      return false;
    }
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    if (city.x == characterPosition.x && city.y == characterPosition.y) {
      return true;
    }
    return false;
  }

  /// @dev character must be in a city
  function MustInCity(uint256 characterId, uint256 cityId) internal view {
    if (!isInCity(characterId, cityId)) {
      CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
      revert Errors.MustInACity(cityId, characterPosition.x, characterPosition.y);
    }
  }

  /// @dev check whether character is in a city or not
  function isInCity(uint256 characterId, uint256 cityId) internal view returns (bool) {
    CityData memory city = City.get(cityId);
    if (city.kingdomId == 0) {
      revert Errors.InvalidCityId(cityId);
    }
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
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
    CharPosition.set(characterId, city.x, city.y);
    CharNextPosition.set(characterId, city.x, city.y, block.timestamp);
  }

  /// @dev move character to a specific location
  function moveToLocation(uint256 characterId, int32 x, int32 y) internal {
    CharPosition.set(characterId, x, y);
    CharNextPosition.set(characterId, x, y, block.timestamp);
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
