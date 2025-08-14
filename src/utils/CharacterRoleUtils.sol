pragma solidity >=0.8.24;

import { KingElection, CharInfo } from "@codegen/index.sol";
import { RoleType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { CharAchievementUtils } from "./CharAchievementUtils.sol";

library CharacterRoleUtils {
  uint256 constant VAULT_KEEPER_ACHIEVEMENT_ID = 17;

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

  function updateRoleAchievement(uint256 characterId, RoleType roleType, bool isRemoved) public {
    if (isRemoved) {
      if (roleType == RoleType.VaultKeeper) {
        CharAchievementUtils.removeAchievement(characterId, VAULT_KEEPER_ACHIEVEMENT_ID);
      }
    } else {
      if (roleType == RoleType.VaultKeeper) {
        CharAchievementUtils.addAchievement(characterId, VAULT_KEEPER_ACHIEVEMENT_ID);
      }
    }
  }
}
