// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { WorldDeployment } from "./WorldDeployment.sol";

contract PostDeploy is WorldDeployment {
  function run(address worldAddress) external {
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    StoreSwitch.setStoreAddress(worldAddress);

    initialize(worldAddress);

    vm.stopBroadcast();
  }
}
