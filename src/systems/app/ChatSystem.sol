pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { ChatCounter } from "@codegen/tables/ChatCounter.sol";
import { GlobalChat } from "@codegen/tables/GlobalChat.sol";
import { Errors } from "@common/Errors.sol";

contract ChatSystem is System, CharacterAccessControl {
  uint32 constant MAX_RECORD_MESSAGE = 100;
  uint32 constant MAX_MESSAGE_LEN = 200;
  /// @dev Craft item when character has enough resources

  function chat(uint256 characterId, string memory content) public onlyAuthorizedWallet(characterId) {
    _validateChat(content);
    uint256 nextCounter = ChatCounter.get() + 1;
    uint256 id = nextCounter % MAX_RECORD_MESSAGE;
    GlobalChat.set(id, characterId, block.timestamp, nextCounter, content);
    ChatCounter.set(nextCounter);
  }

  /// @dev validate chat message
  function _validateChat(string memory content) private {
    bytes memory b = bytes(content);
    if (b.length == 0 || b.length > MAX_MESSAGE_LEN) {
      revert Errors.ChatSystem_InvalidMessage();
    }
  }
}
