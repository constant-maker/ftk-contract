pragma solidity >=0.8.24;

import { Unmovable, RestrictLocV2, City, CityData, TileInfo3 } from "@codegen/index.sol";
import { Errors } from "@common/index.sol";

library MapUtils {
  function getTileId(int32 x, int32 y) internal pure returns (bytes32) {
    return keccak256(abi.encode(x, y));
  }

  function isTileMovable(int32 x, int32 y) internal view returns (bool) {
    bytes32 tileId = getTileId(x, y);
    return !Unmovable.get(x, y);
  }

  function isValidCityLocation(int32 x, int32 y) internal view returns (bool) {
    return !RestrictLocV2.getIsRestricted(x, y);
  }

  function mustBeActiveCity(uint256 cityId) internal view {
    CityData memory city = City.get(cityId);
    uint8 tileKingdomId = TileInfo3.getKingdomId(city.x, city.y);
    if (tileKingdomId != city.kingdomId) {
      revert Errors.CityBelongsToOtherKingdom(city.kingdomId, tileKingdomId);
    }
  }
}
