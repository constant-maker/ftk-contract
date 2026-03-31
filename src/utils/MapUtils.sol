pragma solidity >=0.8.24;

import { Unmovable, RestrictLoc, City, CityData, Tile } from "@codegen/index.sol";
import { Errors } from "@common/index.sol";

library MapUtils {
  function getTileId(int32 x, int32 y) internal pure returns (bytes32) {
    return keccak256(abi.encode(x, y));
  }

  function isTileMovable(int32 x, int32 y) internal view returns (bool) {
    return !Unmovable.get(x, y);
  }

  /// @dev A location is valid if it is not restricted
  function isValidCityLocation(int32 x, int32 y) internal view returns (bool) {
    return !RestrictLoc.getIsRestricted(x, y);
  }

  /// @dev A city is active if it is located within its kingdom territory
  function mustBeActiveCity(uint256 cityId) internal view {
    CityData memory city = City.get(cityId);
    uint8 tileKingdomId = Tile.getKingdomId(city.x, city.y);
    if (!city.isCapital && tileKingdomId != city.kingdomId) {
      // capitals are always ready to get resources
      revert Errors.CityBelongsToOtherKingdom(city.kingdomId, tileKingdomId);
    }
  }

  /// @dev A city must be a capital
  function mustBeCapital(uint256 cityId) internal view {
    CityData memory city = City.get(cityId);
    if (!city.isCapital) {
      revert Errors.CityIsNotCapital(cityId);
    }
  }
}
