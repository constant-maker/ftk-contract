pragma solidity >=0.8.24;

import { Errors } from "@common/index.sol";
import { CharPerk, CharPerkData } from "@codegen/index.sol";
import { ItemType } from "@codegen/common.sol";

library CharacterPerkUtils {
  /// @dev update character perk exp
  function updateCharacterPerkExp(uint256 characterId, ItemType itemType, uint32 gainedExp) internal {
    uint32 characterPerkExp = CharPerk.getExp(characterId, itemType);
    CharPerk.setExp(characterId, itemType, characterPerkExp + gainedExp);
  }
}
