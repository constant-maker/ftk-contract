pragma solidity >=0.8.24;

import { WorldContextConsumerLib } from "@latticexyz/world/src/WorldContext.sol";
import { CharacterUtils } from "@utils/CharacterUtils.sol";
import { CharacterStateUtils } from "@utils/CharacterStateUtils.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { CharacterStatsUtils } from "@utils/CharacterStatsUtils.sol";
import { CharState, CharFarmingState, CharFarmingStateData } from "@codegen/index.sol";
import { Errors } from "@common/index.sol";

abstract contract CharacterAccessControl {
  /// @dev only character owner access control
  modifier onlyCharacterOwner(uint256 characterId) {
    address _sender = WorldContextConsumerLib._msgSender();
    CharacterUtils.checkCharacterOwner(characterId, _sender);
    _;
  }

  /// @dev only character owner or session wallet can access control
  modifier onlyAuthorizedWallet(uint256 characterId) {
    address _sender = WorldContextConsumerLib._msgSender();
    CharacterUtils.checkCharacterAuthorized(characterId, _sender);
    _;
  }

  /// @dev ensure that the last action is finished
  modifier mustFinishLastAction(uint256 characterId, CharacterStateType requiredCharacterState) {
    CharacterStateUtils.checkLastActionFinished(characterId, requiredCharacterState);
    _;
  }

  /// @dev ensure that character must be in a specific state
  modifier mustInState(uint256 characterId, CharacterStateType requiredCharacterState) {
    CharacterStateType characterState = CharacterStateUtils.getCharacterState(characterId);
    if (characterState != requiredCharacterState) {
      revert Errors.Character_MustInState(requiredCharacterState);
    }
    _;
  }

  /// @dev ensure current weight didn't exceed max weight
  modifier validateCurrentWeight(uint256 characterId) {
    CharacterStatsUtils.validateCurrentWeight(characterId);
    _;
  }
}
