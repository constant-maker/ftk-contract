pragma solidity >=0.8.24;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";
import {
  CharPositionData,
  CharPositionFull,
  CharPositionFullData,
  Tile,
  CharBuff,
  CharBuffData,
  CharDebuff,
  CharDebuffData
} from "@codegen/index.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { CharacterStateUtils } from "@utils/CharacterStateUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { Config } from "@common/Config.sol";
import { SpawnSystemFixture, WorldFixture } from "@fixtures/index.sol";
import { MoveSystemFixture } from "@fixtures/MoveSystemFixture.sol";
import { FarmingSystemFixture } from "@fixtures/FarmingSystemFixture.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { TargetItemData } from "@systems/app/ConsumeSystem.sol";

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
    CharPositionData memory position = CharacterPositionUtils.getCurrentPosition(characterId);
    console2.log("position x", position.x);
    console2.log("position y", position.y);
    vm.startPrank(player);
    world.app__move(characterId, position.x, position.y + 1);
    vm.stopPrank();

    CharPositionFullData memory positionFull = CharPositionFull.get(characterId);

    // character is moving so position is unchanged
    assertEq(positionFull.x, position.x);
    assertEq(positionFull.y, position.y);
    assertEq(positionFull.nextX, position.x);
    assertEq(positionFull.nextY, position.y + 1);
    console2.log("newPosition x", positionFull.nextX);
    console2.log("newPosition y", positionFull.nextY);

    CharacterStateType state = CharacterStateUtils.getCharacterState(characterId);
    assertTrue(state == CharacterStateType.Moving);

    vm.warp(block.timestamp + Config.DEFAULT_MOVEMENT_DURATION);
    CharPositionData memory newPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    assertEq(newPosition.x, position.x);
    assertEq(newPosition.y, position.y + 1);
    console2.log("newPosition x", newPosition.x);
    console2.log("newPosition y", newPosition.y);
    state = CharacterStateUtils.getCharacterState(characterId);
    assertTrue(state == CharacterStateType.Standby);

    vm.startPrank(player);
    world.app__move(characterId, newPosition.x, newPosition.y + 1);
    vm.stopPrank();

    positionFull = CharPositionFull.get(characterId);
    assertEq(positionFull.x, newPosition.x);
    assertEq(positionFull.y, newPosition.y);
    assertEq(positionFull.nextX, newPosition.x);
    assertEq(positionFull.nextY, newPosition.y + 1);
  }

  function test_RevertDoubleMove() external {
    CharPositionData memory position = CharacterPositionUtils.getCurrentPosition(characterId);
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

    CharPositionData memory position = CharacterPositionUtils.getCurrentPosition(characterId);
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

  function test_BuffSpeed() external {
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, 20, -32);
    InventoryItemUtils.addItem(characterId, 356, 1); // gain 5 ms
    InventoryItemUtils.addItem(characterId, 357, 1); // decrease ms by 3
    vm.stopPrank();

    vm.startPrank(player);
    world.app__move(characterId, 20, -33);
    vm.stopPrank();

    vm.warp(block.timestamp + Config.DEFAULT_MOVEMENT_DURATION);

    CharPositionData memory position = CharacterPositionUtils.getCurrentPosition(characterId);
    console2.log("position x", position.x);
    console2.log("position y", position.y);
    assertEq(position.x, 20);
    assertEq(position.y, -33);

    TargetItemData memory targetData;
    targetData.targetPlayers = new uint256[](1);
    targetData.targetPlayers[0] = characterId;
    targetData.x = 20;
    targetData.y = -33;

    vm.startPrank(player);
    world.app__consumeItem(characterId, 356, 1, targetData);
    world.app__move(characterId, 20, -32);
    vm.stopPrank();

    vm.warp(block.timestamp + Config.DEFAULT_MOVEMENT_DURATION - 5);

    position = CharacterPositionUtils.getCurrentPosition(characterId);
    console2.log("position x", position.x);
    console2.log("position y", position.y);
    assertEq(position.x, 20);
    assertEq(position.y, -32);

    // targetData.targetPlayers[0] = characterId;
    targetData.x = 20;
    targetData.y = -32;
    vm.startPrank(player);
    world.app__consumeItem(characterId, 357, 1, targetData);
    world.app__move(characterId, 20, -33);
    vm.stopPrank();

    uint256[2] memory buffIds = CharBuff.getBuffIds(characterId);
    for (uint256 i = 0; i < buffIds.length; i++) {
      console2.log("buff id", buffIds[i]);
    }
    assertEq(buffIds[0], 356);
    uint256[2] memory debuffIds = CharDebuff.getDebuffIds(characterId);
    for (uint256 i = 0; i < debuffIds.length; i++) {
      console2.log("debuff id", debuffIds[i]);
    }
    assertEq(debuffIds[0], 357);

    vm.warp(block.timestamp + Config.DEFAULT_MOVEMENT_DURATION - 5 + 3);

    position = CharacterPositionUtils.getCurrentPosition(characterId);
    console2.log("position x", position.x);
    console2.log("position y", position.y);
    assertEq(position.x, 20);
    assertEq(position.y, -33);
  }

  function test_Rooted() external {
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, 20, -32);
    InventoryItemUtils.addItem(characterId, 356, 1); // gain 5 ms
    InventoryItemUtils.addItem(characterId, 357, 1); // decrease ms by 3
    vm.stopPrank();

    vm.startPrank(player);
    world.app__move(characterId, 20, -33);
    vm.stopPrank();

    vm.warp(block.timestamp + Config.DEFAULT_MOVEMENT_DURATION);

    CharPositionData memory position = CharacterPositionUtils.getCurrentPosition(characterId);
    console2.log("position x", position.x);
    console2.log("position y", position.y);
    assertEq(position.x, 20);
    assertEq(position.y, -33);

    TargetItemData memory targetData;
    targetData.targetPlayers = new uint256[](1);
    targetData.targetPlayers[0] = characterId;
    targetData.x = 20;
    targetData.y = -33;

    vm.warp(block.timestamp + 10);

    vm.startPrank(player);
    world.app__consumeItem(characterId, 357, 1, targetData);
    vm.stopPrank();
    uint256[2] memory debuffIds = CharDebuff.getDebuffIds(characterId);
    for (uint256 i = 0; i < debuffIds.length; i++) {
      console2.log("debuff id", debuffIds[i]);
    }
    assertEq(debuffIds[0], 357); // old buff remained

    vm.expectRevert();
    vm.startPrank(player);
    world.app__move(characterId, 20, -32);
    vm.stopPrank();

    vm.warp(block.timestamp + 301);

    vm.startPrank(player);
    world.app__move(characterId, 20, -32);
    vm.stopPrank();

    vm.warp(block.timestamp + Config.DEFAULT_MOVEMENT_DURATION);

    position = CharacterPositionUtils.getCurrentPosition(characterId);
    console2.log("position x", position.x);
    console2.log("position y", position.y);
    assertEq(position.x, 20);
    assertEq(position.y, -32);
  }
}
