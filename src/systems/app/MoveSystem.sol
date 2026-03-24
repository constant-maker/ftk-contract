pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharPositionData, CharPositionFull, CharPositionFullData } from "@codegen/index.sol";
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
    CharPositionData memory characterPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    // validate player possible movement blocks
    if (!MoveSystemUtils.isMoveValid(characterPosition.x, characterPosition.y, destX, destY)) {
      revert Errors.MoveSystem_MovePositionError(characterPosition.x, characterPosition.y, destX, destY);
    }

    // update position
    uint16 moveDuration = MoveSystemUtils.getMovementDuration(characterId);
    uint16 slowDebuffPercent = CharacterBuffUtils.getSlowDebuff(characterId);
    moveDuration = (moveDuration * (100 + slowDebuffPercent)) / 100;
    uint256 arriveTimestamp = block.timestamp + moveDuration;

    CharPositionFull.set(characterId, characterPosition.x, characterPosition.y, destX, destY, arriveTimestamp);
    // update daily quest move count
    DailyQuestUtils.updateMoveCount(characterId);
  }
}
