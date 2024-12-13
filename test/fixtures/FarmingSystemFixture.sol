pragma solidity >=0.8.24;

import { CharPosition, CharPositionData, CharOtherItem, CharCurrentStats, TileInfo3 } from "@codegen/index.sol";
import { console2 } from "forge-std/console2.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldFixture } from "./WorldFixture.sol";
import { SystemUtils } from "@utils/SystemUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";

abstract contract FarmingSystemFixture is WorldFixture {
  function setUp() public virtual override {
    WorldFixture.setUp();
  }

  function _startFarming(address _player, uint256 _characterId, uint256 _resourceId, uint256 _toolId) internal {
    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(_characterId);
    vm.startPrank(worldDeployer);
    TileInfo3.setFarmSlot(charPosition.x, charPosition.y, 200);
    vm.stopPrank();

    vm.startPrank(_player);
    world.app__startFarming(_characterId, _resourceId, _toolId);
    vm.stopPrank();
  }

  function _expectStartFarmingReverted(
    address _player,
    uint256 _characterId,
    uint256 _resourceId,
    uint256 _toolId
  )
    internal
  {
    vm.expectRevert();
    vm.startPrank(_player);
    world.app__startFarming(_characterId, _resourceId, _toolId);
    vm.stopPrank();
  }

  function _finishFarming(address _player, uint256 _characterId) internal {
    vm.startPrank(_player);
    world.app__finishFarming(_characterId, false);
    vm.stopPrank();
  }

  function _finishFarmingAndFarmAgain(address _player, uint256 _characterId) internal {
    vm.startPrank(_player);
    world.app__finishFarming(_characterId, true);
    vm.stopPrank();
  }

  function _doFarmingToGetResource(
    address player,
    uint256 characterId,
    uint256 resourceItemId,
    uint256 toolId,
    uint256 times
  )
    internal
  {
    // move to location that has resource
    console2.log("farming times", times);
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, 20, -32);
    TileInfo3.setFarmSlot(20, -32, 200);
    vm.stopPrank();
    console2.log("before weight", CharCurrentStats.getWeight(characterId));
    uint256 counter = 0;
    for (uint256 i = 0; i < times; i++) {
      uint256 newCounter = i / 20;
      if (newCounter > counter) {
        vm.warp(block.timestamp + 3 hours); // reset quota
        counter = newCounter;
      }
      _startFarming(player, characterId, resourceItemId, toolId);
      // console2.log("still ok until here");
      vm.warp(block.timestamp + 2 minutes);
      _finishFarming(player, characterId);
      // console2.log("still ok until here 2");
    }
    console2.log("after weight", CharCurrentStats.getWeight(characterId));
    // uint32 currentResourceAmount = CharOtherItem.getAmount(characterId, resourceItemId);
    // assertEq(currentResourceAmount, 100);
  }
}
