pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";

library Logging {
  function span(string memory spanName) internal pure {
    console2.log("*----------------------------------- %s -----------------------------------*", spanName);
  }
}
