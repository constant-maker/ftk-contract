pragma solidity >=0.8.24;

import { Errors } from "@common/index.sol";
import { CharPerk } from "@codegen/index.sol";
import { ItemType } from "@codegen/common.sol";

library CharacterPerkUtils {
  /// @dev increase character perk exp
  function increaseCharacterPerkExp(uint256 characterId, ItemType itemType, uint32 gainedExp) internal {
    uint32 characterPerkExp = CharPerk.getExp(characterId, itemType);
    CharPerk.setExp(characterId, itemType, characterPerkExp + gainedExp);
  }

  /// @dev get character perk level (value start from 1, stored as uint8 which starts from 0)
  function getPerkLevel(uint256 characterId, ItemType itemType) internal view returns (uint8) {
    return CharPerk.getLevel(characterId, itemType) + 1;
  }
}
