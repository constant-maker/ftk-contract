pragma solidity >=0.8.24;

import { IWorldErrors } from "@latticexyz/world/src/IWorldErrors.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

library TestHelper {
  using WorldResourceIdInstance for ResourceId;

  // Expect an error when trying to write from an address that doesn't have access
  function getAccessDeniedError(
    address caller,
    bytes14 namespace,
    bytes16 name,
    bytes2 resourceType
  )
    internal
    pure
    returns (bytes memory)
  {
    return abi.encodeWithSelector(
      IWorldErrors.World_AccessDenied.selector,
      WorldResourceIdLib.encode({ typeId: resourceType, namespace: namespace, name: name }).toString(),
      caller
    );
  }

  function getAccessDeniedError(address caller, ResourceId resourceId) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IWorldErrors.World_AccessDenied.selector, resourceId.toString(), caller);
  }
}
