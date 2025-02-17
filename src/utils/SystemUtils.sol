pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

library SystemUtils {
  function getRootSystemId(bytes16 systemName) internal pure returns (ResourceId systemId) {
    return WorldResourceIdLib.encode(RESOURCE_SYSTEM, "", systemName);
  }

  function getSystemId(bytes16 systemName) internal pure returns (ResourceId systemId) {
    return WorldResourceIdLib.encode(RESOURCE_SYSTEM, "app", systemName);
  }

  function getRootSystemAddress(bytes16 systemName) internal returns (address) {
    return Systems.getSystem(getRootSystemId(systemName));
  }

  function getSystemAddress(bytes16 systemName) internal returns (address systemAddress) {
    return Systems.getSystem(getSystemId(systemName));
  }
}
