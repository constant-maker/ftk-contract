// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { SystemHook } from "@latticexyz/world/src/SystemHook.sol";
import { ActiveChar, ActiveCharData } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";

contract NFTTransferHook is SystemHook {
  bytes4 constant TRANSFER_FROM_SELECTOR = bytes4(keccak256("transferFrom(address,address,uint256)"));

  bytes4 constant SAFE_TRANSFER_FROM_SELECTOR = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));

  bytes4 constant SAFE_TRANSFER_FROM_DATA_SELECTOR =
    bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));

  function onBeforeCallSystem(address, ResourceId, bytes memory callData) public {
    if (callData.length < 4) return;

    bytes4 selector = bytes4(callData);

    if (selector == TRANSFER_FROM_SELECTOR || selector == SAFE_TRANSFER_FROM_SELECTOR) {
      (, address to,) = abi.decode(_decodeArgs(callData), (address, address, uint256));
      _validateEOARecipient(to);
    } else if (selector == SAFE_TRANSFER_FROM_DATA_SELECTOR) {
      (, address to,,) = abi.decode(_decodeArgs(callData), (address, address, uint256, bytes));
      _validateEOARecipient(to);
    }
  }

  function onAfterCallSystem(address msgSender, ResourceId, bytes memory callData) public {
    if (callData.length < 4) return;

    bytes4 selector = bytes4(callData);

    if (selector == TRANSFER_FROM_SELECTOR || selector == SAFE_TRANSFER_FROM_SELECTOR) {
      (, address to, uint256 characterId) = abi.decode(_decodeArgs(callData), (address, address, uint256));
      _validateEOARecipient(to);
      _handleTransfer(to, characterId);
    } else if (selector == SAFE_TRANSFER_FROM_DATA_SELECTOR) {
      (, address to, uint256 characterId,) = abi.decode(_decodeArgs(callData), (address, address, uint256, bytes));
      _validateEOARecipient(to);
      _handleTransfer(to, characterId);
    }
  }

  function _handleTransfer(address to, uint256 characterId) private {
    ActiveCharData memory activeCharData = ActiveChar.get(characterId);
    activeCharData.sessionWallet = address(0);
    activeCharData.wallet = to;
    ActiveChar.set(characterId, activeCharData);
  }

  function _validateEOARecipient(address to) private view {
    if (to.code.length > 0) {
      revert Errors.Character_MustBeEOA(to);
    }
  }

  /// @dev remove 4-byte selector, keep ABI-encoded args
  function _decodeArgs(bytes memory data) private pure returns (bytes memory) {
    require(data.length >= 4, "invalid calldata");

    bytes memory args = new bytes(data.length - 4);
    for (uint256 i = 0; i < args.length; ++i) {
      args[i] = data[i + 4];
    }
    return args;
  }
}
