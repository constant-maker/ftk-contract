pragma solidity >=0.8.24;

import { CharAchievement } from "@codegen/tables/CharAchievement.sol";
import { Achievement, AchievementData } from "@codegen/tables/Achievement.sol";
import { CharAchievementIndex } from "@codegen/tables/CharAchievementIndex.sol";
import { CharCurrentStats, CharCurrentStatsData } from "@codegen/tables/CharCurrentStats.sol";

library CharAchievementUtils {
  /// @dev Add achievement to inventory for character
  function addAchievement(uint256 characterId, uint256 achievementId) public {
    if (hasAchievement(characterId, achievementId)) return;
    CharAchievement.pushAchievementIds(characterId, achievementId);
    // The value is stored at length-1, but we add 1 to all indexes
    // and use 0 as a sentinel value
    uint256 index = CharAchievement.lengthAchievementIds(characterId);
    CharAchievementIndex.set(characterId, achievementId, index);
    _updateStats(characterId, achievementId);
  }

  /// @dev Return whether the character has the achievement in inventory
  function hasAchievement(uint256 characterId, uint256 achievementId) public view returns (bool) {
    uint256 index = CharAchievementIndex.get(characterId, achievementId);
    return index != 0;
  }

  function _updateStats(uint256 characterId, uint256 achievementId) private {
    AchievementData memory achievement = Achievement.get(achievementId);
    CharCurrentStatsData memory charCurrentStats = CharCurrentStats.get(characterId);
    if (achievement.atk > 0) {
      CharCurrentStats.setAtk(characterId, charCurrentStats.atk + achievement.atk);
    }
    if (achievement.def > 0) {
      CharCurrentStats.setDef(characterId, charCurrentStats.def + achievement.def);
    }
    if (achievement.agi > 0) {
      CharCurrentStats.setAgi(characterId, charCurrentStats.agi + achievement.agi);
    }
  }
}
