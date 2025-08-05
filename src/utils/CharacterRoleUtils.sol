pragma solidity >=0.8.24;

import { KingElection, CharInfo } from "@codegen/index.sol";
import { Errors } from "@common/index.sol";

library CharacterRoleUtils {
  function mustBeKing(uint8 charKingdomId, uint256 characterId) public view {
    uint256 currentKingId = KingElection.getKingId(charKingdomId);
    if (currentKingId != characterId) {
      revert Errors.KingSystem_NotKing(characterId);
    }
  }

  function mustBeKingByCharacterId(uint256 characterId) public view {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    mustBeKing(charKingdomId, characterId);
  }
}
