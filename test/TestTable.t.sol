pragma solidity >=0.8.24;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
import { TestTable, CharCurrentStats, CharCurrentStatsData } from "@codegen/index.sol";
import { TestHelper } from "./TestHelper.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture } from "./fixtures/index.sol";

contract TestTableTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_Hook() external {
    vm.startPrank(worldDeployer);
    TestTable.set(1, 2, 3);
    vm.stopPrank();
  }

  function test_CharacterCurrentStats() external {
    CharCurrentStatsData memory characterCurrentStats = CharCurrentStats.get(characterId);
    console2.log("weight", characterCurrentStats.weight);

    characterCurrentStats.weight = characterCurrentStats.weight + 5;

    vm.startPrank(worldDeployer);
    CharCurrentStats.set(characterId, characterCurrentStats);
    vm.stopPrank();
    console2.log("new weight", characterCurrentStats.weight);
  }
}
