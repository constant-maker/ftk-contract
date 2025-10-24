pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { CharState, CharStateData, CharNextPosition, ItemV2, CharFarmingState } from "@codegen/index.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { MoveSystemUtils } from "./MoveSystemUtils.sol";
import { Errors, Config } from "@common/index.sol";

library CharacterStateUtils {
  /// @dev Return character action duration base on current character state
  /// Each action has it's own base duration
  /// For simplicity, the default base duration is 15 mins
  function getCharacterActionDuration(uint256 characterId, CharacterStateType state) internal view returns (uint16) {
    if (state == CharacterStateType.Moving) {
      return MoveSystemUtils.getMovementDuration(characterId);
    }
    if (state == CharacterStateType.Farming) {
      uint256 itemId = CharFarmingState.getItemId(characterId);
      uint8 tier = ItemV2.getTier(itemId);
      if (tier > 0) {
        return Config.DEFAULT_PLAYER_ACTION_DURATION * uint16(tier);
      }
    }
    return Config.DEFAULT_PLAYER_ACTION_DURATION;
  }

  /// @dev Revert when the character last action is not finished and character state is not equal to the required
  /// state
  function checkLastActionFinished(uint256 characterId, CharacterStateType requiredCharacterState) internal view {
    // get current character state
    CharStateData memory characterState = getCharacterStateData(characterId);

    // need character at specific state
    if (characterState.state != requiredCharacterState) {
      revert Errors.Character_MustInState(characterState.state, requiredCharacterState, block.timestamp);
    }

    if (characterState.state == CharacterStateType.Standby) {
      return;
    }

    uint256 lastUpdated = characterState.lastUpdated;
    uint16 characterLastActionDuration = getCharacterActionDuration(characterId, characterState.state);
    uint256 nextActionTimestamp = lastUpdated + characterLastActionDuration;

    if (block.timestamp < nextActionTimestamp) {
      revert Errors.Character_LastActionNotFinished(characterState.state, nextActionTimestamp);
    }
  }

  /// @dev get current character state data (custom)
  function getCharacterStateData(uint256 characterId) internal view returns (CharStateData memory characterStateData) {
    characterStateData = CharState.get(characterId);
    if (characterStateData.state == CharacterStateType.Standby) {
      uint256 arriveTimestamp = CharNextPosition.getArriveTimestamp(characterId);
      if (arriveTimestamp > 0 && arriveTimestamp > block.timestamp) {
        characterStateData.state = CharacterStateType.Moving;
      }
    }
    return characterStateData;
  }

  /// @dev get current character state (custom)
  function getCharacterState(uint256 characterId) internal view returns (CharacterStateType) {
    CharacterStateType characterState = CharState.getState(characterId);
    if (characterState == CharacterStateType.Standby) {
      uint256 arriveTimestamp = CharNextPosition.getArriveTimestamp(characterId);
      if (arriveTimestamp > 0 && arriveTimestamp > block.timestamp) {
        return CharacterStateType.Moving;
      }
    }
    return characterState;
  }

  function mustInState(uint256 characterId, CharacterStateType requiredCharacterState) internal view {
    CharacterStateType characterState = getCharacterState(characterId);
    if (characterState != requiredCharacterState) {
      revert Errors.Character_MustInState(characterState, requiredCharacterState, block.timestamp);
    }
  }

  function mustInStateStandByOrMoving(uint256 characterId) internal view {
    CharacterStateType characterState = getCharacterState(characterId);
    if (characterState != CharacterStateType.Standby && characterState != CharacterStateType.Moving) {
      revert Errors.Character_MustInState(characterState, CharacterStateType.Standby, block.timestamp);
    }
  }
}
