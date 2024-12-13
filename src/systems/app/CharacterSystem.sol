pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { ActiveChar, Contracts } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";
import { IERC721Mintable } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";

contract CharacterSystem is System, CharacterAccessControl {
  /// @dev delegate to specific session wallet
  function delegateSessionWallet(uint256 characterId, address sessionWallet) public onlyCharacterOwner(characterId) {
    ActiveChar.setSessionWallet(characterId, sessionWallet);
  }

  /// @dev revoke session wallet
  function revokeSessionWallet(uint256 characterId) public onlyCharacterOwner(characterId) {
    ActiveChar.setSessionWallet(characterId, address(0));
  }

  /// @dev link character to a new account and set current owner to session wallet
  function linkMainAccount(uint256 characterId, address newOwner) public onlyCharacterOwner(characterId) {
    address currentOwner = _msgSender();
    _transferOwnership(currentOwner, newOwner, characterId);

    ActiveChar.setWallet(characterId, newOwner);
    ActiveChar.setSessionWallet(characterId, currentOwner);
  }

  function _transferOwnership(address currentOwner, address newOwner, uint256 characterId) private {
    IERC721Mintable token = IERC721Mintable(Contracts.getErc721Token());
    token.safeTransferFrom(currentOwner, newOwner, characterId);
  }
}
