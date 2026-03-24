pragma solidity >=0.8.24;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { CharPositionFull, CharPositionFullData, CharPositionData, CharState, CharStateData } from "@codegen/index.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { WorldFixture } from "./WorldFixture.sol";
import { MoveSystemUtils } from "@utils/MoveSystemUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharacterStateUtils } from "@utils/CharacterStateUtils.sol";

abstract contract MoveSystemFixture is WorldFixture {
  /// @dev Setup fixture
  function setUp() public virtual override {
    WorldFixture.setUp();
  }

  /// @dev Go up one tile and finish action
  function _goUp(address player, uint256 characterId) internal doPrank(player) {
    CharPositionData memory characterPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    world.app__move(characterId, characterPosition.x, characterPosition.y + 1);
    assertTrue(CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Moving);
    uint16 moveDuration = MoveSystemUtils.getMovementDuration(characterId);
    vm.warp(block.timestamp + moveDuration);

    CharPositionData memory newCharacterPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    assertEq(newCharacterPosition.y, characterPosition.y + 1);
    assertTrue(CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Standby);
  }

  /// @dev Go down one tile and finish the action
  function _goDown(address player, uint256 characterId) internal doPrank(player) {
    CharPositionData memory characterPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    world.app__move(characterId, characterPosition.x, characterPosition.y - 1);
    assertTrue(CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Moving);
    uint16 moveDuration = MoveSystemUtils.getMovementDuration(characterId);
    vm.warp(block.timestamp + moveDuration);

    CharPositionData memory newCharacterPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    assertEq(newCharacterPosition.y, characterPosition.y - 1);
    assertTrue(CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Standby);
  }

  /// @dev Go left one tile and finish the action
  function _goLeft(address player, uint256 characterId) internal doPrank(player) {
    CharPositionData memory characterPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    world.app__move(characterId, characterPosition.x - 1, characterPosition.y);
    assertTrue(CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Moving);
    uint16 moveDuration = MoveSystemUtils.getMovementDuration(characterId);
    vm.warp(block.timestamp + moveDuration);

    CharPositionData memory newCharacterPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    assertEq(newCharacterPosition.x, characterPosition.x - 1);
    assertTrue(CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Standby);
  }

  /// @dev Go right one tile and finish the action
  function _goRight(address player, uint256 characterId) internal doPrank(player) {
    CharPositionData memory characterPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    world.app__move(characterId, characterPosition.x + 1, characterPosition.y);
    assertTrue(CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Moving);
    uint16 moveDuration = MoveSystemUtils.getMovementDuration(characterId);
    vm.warp(block.timestamp + moveDuration);

    CharPositionData memory newCharacterPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    assertEq(newCharacterPosition.x, characterPosition.x + 1);
    assertTrue(CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Standby);
  }

  /// @dev Move via world call
  function _move(uint256 characterId, int32 nextX, int32 nextY) internal {
    world.app__move(characterId, nextX, nextY);

    CharStateData memory characterState = CharacterStateUtils.getCharacterStateData(characterId);
    assertTrue(characterState.state == CharacterStateType.Moving, "Character state should be Moving");

    CharPositionFullData memory positionFull = CharPositionFull.get(characterId);
    assertEq(positionFull.nextX, nextX);
    assertEq(positionFull.nextY, nextY);
  }

  function _moveToMonsterLocation(uint256 characterId) internal {
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, 30, -35);
    vm.stopPrank();
  }

  function _moveToBossLocation(uint256 characterId) internal {
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, -50, -17);
    vm.stopPrank();
  }
}
