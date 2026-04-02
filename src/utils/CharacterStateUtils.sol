pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { CharState, CharStateData, CharPositionFull, Item, CharFarmingState } from "@codegen/index.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { Errors, Config } from "@common/index.sol";

library CharacterStateUtils {
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

    uint256 nextActionTimestamp;
    if (characterState.state == CharacterStateType.Moving) {
      nextActionTimestamp = CharPositionFull.getArriveTimestamp(characterId);
    } else {
      uint256 lastUpdated = characterState.lastUpdated;
      uint16 characterLastActionDuration = _getCharacterActionDuration(characterId, characterState.state);
      nextActionTimestamp = lastUpdated + characterLastActionDuration;
    }

    if (block.timestamp < nextActionTimestamp) {
      revert Errors.Character_LastActionNotFinished(characterState.state, nextActionTimestamp);
    }
  }

  /// @dev get current character state data (custom)
  function getCharacterStateData(uint256 characterId) internal view returns (CharStateData memory characterStateData) {
    characterStateData = CharState.get(characterId);
    if (characterStateData.state == CharacterStateType.Standby) {
      uint256 arriveTimestamp = CharPositionFull.getArriveTimestamp(characterId);
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
      uint256 arriveTimestamp = CharPositionFull.getArriveTimestamp(characterId);
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
      revert Errors.Character_MustInStateStandByOrMoving(characterState, block.timestamp);
    }
  }

  /// @dev Return character action duration base on current character state.
  /// Each action has its own base duration.
  function _getCharacterActionDuration(uint256 characterId, CharacterStateType state) private view returns (uint16) {
    if (state == CharacterStateType.Farming) {
      uint256 itemId = CharFarmingState.getItemId(characterId);
      uint8 tier = Item.getTier(itemId);
      if (tier > 0) {
        return Config.DEFAULT_PLAYER_ACTION_DURATION * uint16(tier);
      }
    }
    return Config.DEFAULT_PLAYER_ACTION_DURATION;
  }
}
