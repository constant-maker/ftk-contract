pragma solidity >=0.8.24;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";
import { CharPosition, CharPositionData, CharNextPosition, CharNextPositionData, TileInfo3 } from "@codegen/index.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { CharacterStateUtils } from "@utils/CharacterStateUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { Config } from "@common/Config.sol";
import { SpawnSystemFixture, WorldFixture } from "@fixtures/index.sol";
import { MoveSystemFixture } from "@fixtures/MoveSystemFixture.sol";
import { FarmingSystemFixture } from "@fixtures/FarmingSystemFixture.sol";

contract MoveSystemTest is WorldFixture, MoveSystemFixture, SpawnSystemFixture, FarmingSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, MoveSystemFixture, SpawnSystemFixture, FarmingSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
  }

  function test_MoveSuccessfully() external {
    _goUp(player, characterId);
    _goDown(player, characterId);
    _goLeft(player, characterId);
    _goRight(player, characterId);
  }

  function test_CheckMoveState() external {
    CharPositionData memory position = CharacterPositionUtils.currentPosition(characterId);
    console2.log("position x", position.x);
    console2.log("position y", position.y);
    vm.startPrank(player);
    world.app__move(characterId, position.x, position.y + 1);
    vm.stopPrank();

    CharPositionData memory newPosition = CharacterPositionUtils.currentPosition(characterId);
    CharPositionData memory prevPosition = CharPosition.get(characterId);
    CharNextPositionData memory nextPosition = CharNextPosition.get(characterId);
    // character is moving so position is unchanged
    assertEq(newPosition.x, position.x);
    assertEq(newPosition.y, position.y);
    assertEq(prevPosition.x, position.x);
    assertEq(prevPosition.y, position.y);
    assertEq(nextPosition.x, position.x);
    assertEq(nextPosition.y, position.y + 1);
    console2.log("newPosition x", newPosition.x);
    console2.log("newPosition y", newPosition.y);

    CharacterStateType state = CharacterStateUtils.getCharacterState(characterId);
    assertTrue(state == CharacterStateType.Moving);

    vm.warp(block.timestamp + Config.DEFAULT_MOVEMENT_DURATION);
    newPosition = CharacterPositionUtils.currentPosition(characterId);
    assertEq(newPosition.x, position.x);
    assertEq(newPosition.y, position.y + 1);
    console2.log("newPosition x", newPosition.x);
    console2.log("newPosition y", newPosition.y);
    state = CharacterStateUtils.getCharacterState(characterId);
    assertTrue(state == CharacterStateType.Standby);

    vm.startPrank(player);
    world.app__move(characterId, newPosition.x, newPosition.y + 1);
    vm.stopPrank();
    prevPosition = CharPosition.get(characterId);
    assertEq(prevPosition.x, newPosition.x);
    assertEq(prevPosition.y, newPosition.y);
    nextPosition = CharNextPosition.get(characterId);
    assertEq(nextPosition.x, newPosition.x);
    assertEq(nextPosition.y, newPosition.y + 1);
  }

  function test_RevertDoubleMove() external {
    CharPositionData memory position = CharacterPositionUtils.currentPosition(characterId);
    console2.log("position x", position.x);
    console2.log("position y", position.y);
    vm.startPrank(player);
    world.app__move(characterId, position.x, position.y + 1);
    vm.stopPrank();

    CharacterStateType state = CharacterStateUtils.getCharacterState(characterId);
    assertTrue(state == CharacterStateType.Moving);

    vm.expectRevert();
    vm.startPrank(player);
    world.app__move(characterId, position.x, position.y + 2);
    vm.stopPrank();

    vm.warp(block.timestamp + Config.DEFAULT_MOVEMENT_DURATION);
    state = CharacterStateUtils.getCharacterState(characterId);
    assertTrue(state == CharacterStateType.Standby);
    vm.startPrank(player);
    world.app__move(characterId, position.x, position.y + 2);
    vm.stopPrank();
  }

  function test_RevertFarmWhenMove() external {
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, 20, -32);
    vm.stopPrank();

    CharPositionData memory position = CharacterPositionUtils.currentPosition(characterId);
    console2.log("position x", position.x);
    console2.log("position y", position.y);
    vm.startPrank(player);
    world.app__move(characterId, position.x, position.y + 1);
    vm.stopPrank();

    CharacterStateType state = CharacterStateUtils.getCharacterState(characterId);
    assertTrue(state == CharacterStateType.Moving);

    vm.expectRevert();
    vm.startPrank(player);
    world.app__startFarming(characterId, 1, 1, true);
    vm.stopPrank();
  }
}
