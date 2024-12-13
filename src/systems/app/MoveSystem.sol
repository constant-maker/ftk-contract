pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharPosition, CharPositionData, CharNextPosition, CharNextPositionData } from "@codegen/index.sol";
import { TileInfo3 } from "@codegen/tables/TileInfo3.sol";
import { MonsterLocation } from "@codegen/tables/MonsterLocation.sol";
import { CharStats } from "@codegen/tables/CharStats.sol";
import { MoveSystemUtils } from "@utils/MoveSystemUtils.sol";
import { CharacterStateUtils } from "@utils/CharacterStateUtils.sol";
import { DailyQuestUtils } from "@utils/DailyQuestUtils.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";

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
    CharNextPosition.set(characterId, destX, destY, block.timestamp + MoveSystemUtils.getMovementDuration(characterId));

    // update daily quest move count
    DailyQuestUtils.updateMoveCount(characterId);
  }
}
