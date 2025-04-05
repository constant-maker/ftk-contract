pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharSkill, Skill } from "@codegen/index.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { Errors } from "@common/Errors.sol";

contract SkillSystem is System, CharacterAccessControl {
  /// @dev update skill order
  function updateSkillOrder(uint256 characterId, uint256[5] calldata skillIds) public onlyAuthorizedWallet(characterId) {
    _validateSkillIds(skillIds);
    CharSkill.set(characterId, skillIds);
  }

  /// @dev Validates that the skillIds array does not contain duplicates of non-zero values.
  /// @param skillIds Array of skill IDs to validate.
  function _validateSkillIds(uint256[5] memory skillIds) private view {
    for (uint256 i = 0; i < skillIds.length; i++) {
      uint256 skillId = skillIds[i];
      // Skip zero since it's allowed to be duplicated
      if (skillId == 0) continue;

      // Check if skill exist
      if (Skill.getTier(skillId) == 0) {
        revert Errors.Skill_NotExist(skillId);
      }

      // Check current element against all following elements
      for (uint256 j = i + 1; j < skillIds.length; j++) {
        // If a duplicate non-zero skill ID is found, return false
        if (skillId == skillIds[j] && skillIds[j] != 0) {
          revert Errors.Skill_DuplicateSkillId(skillId);
        }
      }
    }
  }
}
