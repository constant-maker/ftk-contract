pragma solidity >=0.8.24;

import { Test } from "forge-std/Test.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { console2 } from "forge-std/console2.sol";

abstract contract WorldFixture is Test {
  address public worldAddress;
  address public creator;
  address public worldDeployer;

  IWorld public world;

  function setUp() public virtual {
    // run mud test will pass the created world address to env WORLD_ADDRESS
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    worldDeployer = vm.addr(vm.envUint("PRIVATE_KEY"));

    StoreSwitch.setStoreAddress(worldAddress);

    world = IWorld(worldAddress);
    creator = world.creator();

    vm.label(worldAddress, "WORLD");
    vm.label(creator, "WORLD_CREATOR");
    vm.label(worldDeployer, "WORLD_DEPLOYER");

    // set block timestamp so we can pass some test cases
    vm.warp(1);
  }

  modifier doPrank(address sender) {
    vm.startPrank(sender);
    _;
    vm.stopPrank();
  }
}
