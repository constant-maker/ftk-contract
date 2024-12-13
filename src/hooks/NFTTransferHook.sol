// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { SystemHook } from "@latticexyz/world/src/SystemHook.sol";
import { console2 } from "forge-std/console2.sol";

contract NFTTransferHook is SystemHook {
  bytes4 constant safeTransferFromSelector = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));

  function onBeforeCallSystem(address, ResourceId, bytes memory) public {
    return;
  }

  function onAfterCallSystem(address addr, ResourceId, bytes memory callData) public {
    bytes4 selector = bytes4(callData);
    if (selector == safeTransferFromSelector) {
      (address from, address to, uint256 characterId) =
        abi.decode(_truncateBytes(callData, 4), (address, address, uint256));
      // console2.log("NFT TRANSFER HOOK", from);
      // console2.log("NFT TRANSFER HOOK", to);
      // console2.log("NFT TRANSFER HOOK", characterId);
      // TODO implement later to set owner
    }
  }

  function _truncateBytes(bytes memory callData, uint256 fromIndex) private pure returns (bytes memory result) {
    console2.log("len call data", callData.length);
    require(fromIndex <= callData.length, "fromIndex out of bounds");

    uint256 len = callData.length - fromIndex;
    result = new bytes(len);

    assembly {
      let resultPtr := add(result, 32)
      let callDataPtr := add(add(callData, 32), fromIndex)
      mstore(resultPtr, mload(callDataPtr))

      for { let i := 32 } lt(i, len) { i := add(i, 32) } { mstore(add(resultPtr, i), mload(add(callDataPtr, i))) }
    }
  }
}
