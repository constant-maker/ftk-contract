pragma solidity >=0.8.24;

import { WorldFixture } from "@fixtures/WorldFixture.sol";

abstract contract WelcomeSystemFixture is WorldFixture {
  function setUp() public virtual override {
    WorldFixture.setUp();
  }

  function _claimWelcomePackages(address player, uint256 characterId) internal {
    vm.startPrank(player);
    world.app__claimWelcomePackages(characterId);
    vm.stopPrank();
  }
}
