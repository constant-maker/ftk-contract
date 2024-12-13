pragma solidity >=0.8.24;

import { Test } from "forge-std/Test.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { CharState, CharStateData, CharInfoData } from "@codegen/index.sol";
import { CharacterStateUtils } from "@utils/CharacterStateUtils.sol";
import { SystemUtils } from "@utils/SystemUtils.sol";
import { CharacterInfoMock } from "@mocks/index.sol";
import { WorldFixture } from "./fixtures/WorldFixture.sol";
import { SpawnSystem } from "@systems/SpawnSystem.sol";
import { IWorld } from "@codegen/world/IWorld.sol";

contract CharacterStateUtilsTest is WorldFixture {
  function setUp() public virtual override {
    WorldFixture.setUp();
  }

  function initCharacterState(uint256 _characterId) internal {
    vm.startPrank(worldDeployer);
    CharState.set(_characterId, CharacterStateType.Standby, block.timestamp);
    vm.stopPrank();
  }

  function setCharacterState(uint256 _characterId, CharStateData memory playerState) internal {
    vm.startPrank(worldDeployer);
    CharState.set(_characterId, playerState);
    vm.stopPrank();
  }

  function spawnCharacter(address _player, CharInfoData memory characterInfoData) internal {
    vm.startPrank(_player);
    _worldCall_init(address(world), characterInfoData);
    vm.stopPrank();
  }

  function _worldCall_init(address world, CharInfoData memory data) private {
    bytes memory callData = abi.encodeWithSelector(SpawnSystem.createCharacter.selector, data);
    IWorld(world).call(SystemUtils.getRootSystemId("SpawnSystem"), callData);
  }
}

contract CharacterStateUtils_CheckLastActionFinished_Test is CharacterStateUtilsTest {
  address player = makeAddr("alice");
  uint256 characterId = 0;

  function setUp() public override {
    CharacterStateUtilsTest.setUp();
  }

  function test_ShouldReturnImmediately_WhenCharacterStateIsStandby() external {
    initCharacterState(characterId);
    CharacterStateUtils.checkLastActionFinished(characterId, CharacterStateType.Standby);
  }

  function testFail_ShouldReverted_WhenLastCharacterActionIsNotFinished() external {
    spawnCharacter(player, CharacterInfoMock.getCharacterInfoData());
    setCharacterState(characterId, CharStateData({ state: CharacterStateType.Moving, lastUpdated: block.timestamp }));

    CharacterStateUtils.checkLastActionFinished(characterId, CharacterStateType.Farming);
  }
}
