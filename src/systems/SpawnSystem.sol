pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { CharState, CharInfo, CharInfoData, CharName, ActiveChar, KingdomV2 } from "@codegen/index.sol";
import { CharStats2 } from "@codegen/tables/CharStats2.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharacterUtils } from "@utils/CharacterUtils.sol";
import { Errors, Events } from "@common/index.sol";

contract SpawnSystem is System {
  /// @dev User call this function to create character, expect to be called once
  function createCharacter(CharInfoData memory data) public {
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
    CharStats2.setFame(characterId, 1000); // default 1000 points

    emit Events.CharacterCreated(characterId, wallet, block.timestamp);
  }

  /// @dev Validate the data to create character
  function _validateCreateCharacterData(CharInfoData memory data) private view {
    uint256 capitalId = KingdomV2.getCapitalId(data.kingdomId);
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

  /// @dev Validate character name
  function _isValidName(string memory name) private pure returns (bool) {
    bytes memory b = bytes(name);

    if (b.length < 3 || b.length > 25) {
      return false;
    }

    // No leading space or trailing space
    if (b[0] == 0x20 || b[b.length - 1] == 0x20) return false;

    bool hasOpenBracket = false;
    bool hasCloseBracket = false;

    for (uint256 i = 0; i < b.length; i++) {
      bytes1 char = b[i];

      // Check for invalid characters and continuous spaces
      if (
        (char == 0x20 && i > 0 && b[i - 1] == 0x20) // continuous spaces
          || !(char >= 0x30 && char <= 0x39) // 0-9
            && !(char >= 0x41 && char <= 0x5A) // A-Z
            && !(char >= 0x61 && char <= 0x7A) // a-z
            && !(char == 0x20) // space
            && !(char == 0x5B) // [
            && !(char == 0x5D) // ]
      ) {
        return false;
      }

      // Track the presence of brackets
      if (char == 0x5B) {
        if (hasOpenBracket) return false; // More than one [
        hasOpenBracket = true;
      } else if (char == 0x5D) {
        if (hasCloseBracket) return false; // More than one ]
        hasCloseBracket = true;
      }
    }

    return true;
  }
}
