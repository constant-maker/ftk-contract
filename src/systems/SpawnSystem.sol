pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { CharState, CharInfo, CharInfoData, CharName, ActiveChar, Kingdom } from "@codegen/index.sol";
import { CharStats2 } from "@codegen/tables/CharStats2.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { CharacterPositionUtils, CharacterUtils } from "@utils/index.sol";
import { Errors, Events, Config } from "@common/index.sol";

contract SpawnSystem is System {
  /// @dev User call this function to create character, expect to be called once
  function createCharacter(CharInfoData memory data) public payable {
    if (_msgValue() != Config.CREATE_CHARACTER_FEE) {
      revert Errors.SpawnSystem_InsufficientCreateCharacterFee(_msgValue());
    }
    address wallet = _msgSender();
    // Validate inputs
    _validateCreateCharacterData(data);

    // mint character ERC721
    uint256 characterId = CharacterUtils.mintERC721(wallet);

    // spawn at the capital
    CharInfo.set(characterId, data);
    CharacterPositionUtils.moveToCapital(characterId);
    CharState.set(characterId, CharacterStateType.Standby, block.timestamp);

    // since we have validation for the character name length, we can pack the string into a word
    bytes32 nameHash = LibString.packOne(LibString.lower(data.name));
    CharName.set(nameHash, characterId);
    ActiveChar.set(characterId, wallet, address(0), block.timestamp);

    // init character stats
    CharacterUtils.initCharacterStatsWithTraits(characterId, data.traits);
    CharStats2.setFame(characterId, Config.DEFAULT_FAME);

    emit Events.CharacterCreated(characterId, wallet, block.timestamp);
  }

  /// @dev Validate the data to create character
  function _validateCreateCharacterData(CharInfoData memory data) private view {
    uint256 capitalId = Kingdom.getCapitalId(data.kingdomId);
    if (capitalId == 0) {
      revert Errors.SpawnSystem_InvalidKingdomId(data.kingdomId);
    }

    if (!_isValidName(data.name)) {
      revert Errors.SpawnSystem_InvalidCharacterName(data.name);
    }

    bytes32 nameHash = LibString.packOne(LibString.lower(data.name));
    if (CharName.get(nameHash) > 0) {
      revert Errors.SpawnSystem_CharacterNameExisted(data.name);
    }
  }

  function _isValidName(string memory name) private pure returns (bool) {
    bytes memory b = bytes(name);

    // Length check
    if (b.length < 3 || b.length > 25) {
      return false;
    }

    for (uint256 i = 0; i < b.length; i++) {
      bytes1 char = b[i];

      // Allowed: 0-9, A-Z, a-z only
      if (
        !(char >= 0x30 && char <= 0x39) // digits
          && !(char >= 0x41 && char <= 0x5A) // A-Z
          && !(char >= 0x61 && char <= 0x7A) // a-z
      ) {
        return false;
      }
    }

    return true;
  }
}
