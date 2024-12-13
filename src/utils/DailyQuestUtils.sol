pragma solidity >=0.8.24;

import { CharDailyQuest, DailyQuestConfig } from "@codegen/index.sol";

library DailyQuestUtils {
  uint256 public constant ONE_DAY_SECONDS = 86_400;

  /// @dev Update move count in character daily quest
  function updateMoveCount(uint256 characterId) internal {
    if (!isValidQuestTime(characterId)) return;
    uint8 moveNum = DailyQuestConfig.getMoveNum();
    uint8 moveCount = CharDailyQuest.getMoveCount(characterId);
    if (moveCount >= moveNum) return;
    CharDailyQuest.setMoveCount(characterId, moveCount + 1);
  }

  /// @dev Update farm count in character daily quest
  function updateFarmCount(uint256 characterId) internal {
    if (!isValidQuestTime(characterId)) return;
    uint8 farmNum = DailyQuestConfig.getFarmNum();
    uint8 farmCount = CharDailyQuest.getFarmCount(characterId);
    if (farmCount >= farmNum) return;
    CharDailyQuest.setFarmCount(characterId, farmCount + 1);
  }

  /// @dev Update pve count in character daily quest
  function updatePveCount(uint256 characterId) internal {
    if (!isValidQuestTime(characterId)) return;
    uint8 pveNum = DailyQuestConfig.getPveNum();
    uint8 pveCount = CharDailyQuest.getPveCount(characterId);
    if (pveCount >= pveNum) return;
    CharDailyQuest.setPveCount(characterId, pveCount + 1);
  }

  /// @dev Update pvp count in character daily quest
  function updatePvpCount(uint256 characterId) internal {
    if (!isValidQuestTime(characterId)) return;
    uint8 pvpNum = DailyQuestConfig.getPvpNum();
    uint8 pvpCount = CharDailyQuest.getPvpCount(characterId);
    if (pvpCount >= pvpNum) return;
    CharDailyQuest.setPvpCount(characterId, pvpCount + 1);
  }

  /// @dev Check if the current time is valid or not
  function isValidQuestTime(uint256 characterId) internal view returns (bool) {
    uint256 startTime = CharDailyQuest.getStartTime(characterId);
    if (startTime == 0 || block.timestamp < startTime || block.timestamp > startTime + ONE_DAY_SECONDS) return false; // quest
      // timeout
    return true;
  }
}
