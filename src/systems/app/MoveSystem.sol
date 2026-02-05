pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharPosition, CharPositionData, CharNextPosition, CharPositionV2, CharPositionV2Data
} from "@codegen/index.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { CharacterPositionUtils, MoveSystemUtils, DailyQuestUtils, CharacterBuffUtils } from "@utils/index.sol";
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
    uint16 slowDebuffPercent = CharacterBuffUtils.getSlowDebuff(characterId);
    arriveTimestamp = (arriveTimestamp * (100 + uint256(slowDebuffPercent))) / 100;
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
