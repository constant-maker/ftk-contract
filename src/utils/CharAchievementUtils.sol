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
    _updateStats(characterId, achievementId, false);
  }

  // @dev Remove achievement from inventory for character
  function removeAchievement(uint256 characterId, uint256 achievementId) public {
    uint256 index = CharAchievementIndex.get(characterId, achievementId);
    if (index == 0) return; // Achievement not found
    // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
    // the array, and then remove the last element (sometimes called as 'swap and pop').
    // This modifies the order of the array, as noted in {at}.
    uint256 valueIndex = index - 1;
    uint256 lastIndex = CharAchievement.lengthAchievementIds(characterId) - 1;
    if (valueIndex != lastIndex) {
      uint256 lastValue = CharAchievement.getItemAchievementIds(characterId, lastIndex);
      CharAchievement.updateAchievementIds(characterId, valueIndex, lastValue);
      CharAchievementIndex.set(characterId, lastValue, index);
    }
    CharAchievement.popAchievementIds(characterId);
    CharAchievementIndex.deleteRecord(characterId, achievementId);
    _updateStats(characterId, achievementId, true);
  }

  /// @dev Return whether the character has the achievement in inventory
  function hasAchievement(uint256 characterId, uint256 achievementId) public view returns (bool) {
    uint256 index = CharAchievementIndex.get(characterId, achievementId);
    return index != 0;
  }

  function _updateStats(uint256 characterId, uint256 achievementId, bool isRemove) private {
    AchievementData memory achievement = Achievement.get(achievementId);
    CharCurrentStatsData memory charCurrentStats = CharCurrentStats.get(characterId);
    _applyStatChange(characterId, charCurrentStats.atk, achievement.atk, isRemove, CharCurrentStats.setAtk);
    _applyStatChange(characterId, charCurrentStats.def, achievement.def, isRemove, CharCurrentStats.setDef);
    _applyStatChange(characterId, charCurrentStats.agi, achievement.agi, isRemove, CharCurrentStats.setAgi);
  }

  function _applyStatChange(
    uint256 characterId,
    uint16 current,
    uint16 delta,
    bool isRemove,
    function(uint256, uint16) internal setFn
  )
    private
  {
    if (delta == 0) return;

    uint16 newValue = isRemove ? (current > delta ? current - delta : 0) : current + delta;

    setFn(characterId, newValue);
  }
}
