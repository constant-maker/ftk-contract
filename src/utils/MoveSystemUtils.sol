pragma solidity >=0.8.24;

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import { MovementConfig, CharCurrentStats } from "@codegen/index.sol";
import { TileInfo3 } from "@codegen/tables/TileInfo3.sol";
import { CharInfo } from "@codegen/tables/CharInfo.sol";
import { CharPositionData } from "@codegen/tables/CharPosition.sol";
import { MapUtils } from "./MapUtils.sol";
import { CharacterPositionUtils } from "./CharacterPositionUtils.sol";

library MoveSystemUtils {
  /// @dev Get character movement speed that not exceeds max movement speed and at minimum of 1
  function getCharacterMovementSpeed(uint256 characterId) internal view returns (uint16) {
    uint16 maxMovementSpeed = MovementConfig.getMaxMovementSpeed();
    uint16 characterMovementSpeed = CharCurrentStats.getMs(characterId);

    if (characterMovementSpeed > maxMovementSpeed) {
      characterMovementSpeed = maxMovementSpeed;
    } else if (characterMovementSpeed == 0) {
      characterMovementSpeed = 1;
    }

    return characterMovementSpeed;
  }

  /// @dev Get character movement duration, character movement speed should not exceed base duration
  function getMovementDuration(uint256 characterId) internal view returns (uint16) {
    uint16 baseDuration = MovementConfig.getDuration();
    uint16 characterMovementSpeed = (getCharacterMovementSpeed(characterId) - 1);
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    uint8 tileKingdomId = TileInfo3.getKingdomId(characterPosition.x, characterPosition.y);
    if (tileKingdomId != 0 && tileKingdomId == CharInfo.getKingdomId(characterId)) {
      characterMovementSpeed += 2; // bonus speed
    }

    // extra check to make sure if the baseDuration is configured too small so that character movement speed could >
    // baseDuration
    if (characterMovementSpeed > baseDuration) {
      return 0;
    }

    return baseDuration - characterMovementSpeed;
  }

  /// @dev Check if move valid
  function isMoveValid(int32 x, int32 y, int32 newX, int32 newY) internal view returns (bool) {
    if (x == newX && y == newY) {
      return false;
    }
    if (!MapUtils.isTileMovable(newX, newY)) {
      return false;
    }
    SD59x18 deltaX = sd(int256(newX)) - sd(int256(x));
    SD59x18 deltaY = sd(int256(newY)) - sd(int256(y));
    return deltaX.abs() + deltaY.abs() == sd(1);
  }
}
