pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharPosition,
  CharPositionData,
  CharNextPosition,
  CharNextPositionData,
  CharPositionV2,
  CharPositionV2Data,
  TileInfo3,
  MonsterLocation,
  CharStats
} from "@codegen/index.sol";
import { MoveSystemUtils } from "@utils/MoveSystemUtils.sol";
import { CharacterStateUtils } from "@utils/CharacterStateUtils.sol";
import { DailyQuestUtils } from "@utils/DailyQuestUtils.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { Errors } from "@common/index.sol";

contract MoveSystem is CharacterAccessControl, System {
  /// @dev move to a new position (destX, destY)
  function move(
    uint256 characterId,
    int32 destX,
    int32 destY
  )
    public
    onlyAuthorizedWallet(characterId)
    mustInState(characterId, CharacterStateType.Standby)
    validateCurrentWeight(characterId)
  {
    // when character in StandBy state, this will return CharNextPosition
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    // validate player possible movement blocks
    if (!MoveSystemUtils.isMoveValid(characterPosition.x, characterPosition.y, destX, destY)) {
      revert Errors.MoveSystem_MovePositionError(characterPosition.x, characterPosition.y, destX, destY);
    }

    CharPositionData memory charPrevPosition = CharPosition.get(characterId);
    if (charPrevPosition.x != characterPosition.x || charPrevPosition.y != characterPosition.y) {
      CharPosition.set(characterId, characterPosition.x, characterPosition.y);
    }
    // update next position
    uint256 arriveTimestamp = block.timestamp + MoveSystemUtils.getMovementDuration(characterId);
    CharNextPosition.set(characterId, destX, destY, arriveTimestamp);
    CharPositionV2Data memory posV2 = CharPositionV2Data({
      x: characterPosition.x,
      y: characterPosition.y,
      nextX: destX,
      nextY: destY,
      arriveTimestamp: arriveTimestamp
    });
    CharPositionV2.set(characterId, posV2);
    // update daily quest move count
    DailyQuestUtils.updateMoveCount(characterId);
  }
}
