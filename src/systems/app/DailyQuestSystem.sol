pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharDailyQuest, CharDailyQuestData, DailyQuestConfig, DailyQuestConfigData } from "@codegen/index.sol";
import { DailyQuestUtils } from "@utils/DailyQuestUtils.sol";
import { CharacterStatsUtils } from "@utils/CharacterStatsUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { Errors } from "@common/Errors.sol";

contract DailyQuestSystem is System, CharacterAccessControl {
  uint8 constant MAX_STREAK = 10;
  uint8 constant BONUS_REWARD_PERCENT = 10; // bonus base on streak

  function refreshQuest(uint256 characterId) public onlyAuthorizedWallet(characterId) {
    uint256 startTime = CharDailyQuest.getStartTime(characterId);
    if (startTime != 0 && block.timestamp < startTime) {
      revert Errors.DailyQuestSystem_CannotRefreshAtCurrentTime(startTime);
    }
    CharDailyQuestData memory dailyQuestData = CharDailyQuestData({
      moveCount: 0,
      farmCount: 0,
      pvpCount: 0,
      pveCount: 0,
      streak: 0,
      startTime: block.timestamp
    });
    CharDailyQuest.set(characterId, dailyQuestData);
  }

  function finishQuest(uint256 characterId) public onlyAuthorizedWallet(characterId) {
    if (!DailyQuestUtils.isValidQuestTime(characterId)) {
      revert Errors.DailyQuestSystem_InvalidQuestTime(block.timestamp, CharDailyQuest.getStartTime(characterId));
    }
    CharDailyQuestData memory dailyQuestData = CharDailyQuest.get(characterId);
    DailyQuestConfigData memory dailyQuestConfig = DailyQuestConfig.get();
    if (
      dailyQuestData.moveCount >= dailyQuestConfig.moveNum && dailyQuestData.farmCount >= dailyQuestConfig.farmNum
        && dailyQuestData.pveCount >= dailyQuestConfig.pveNum && dailyQuestData.pvpCount >= dailyQuestConfig.pvpNum
    ) {
      uint32 rewardExp = dailyQuestConfig.rewardExp * (100 + BONUS_REWARD_PERCENT * dailyQuestData.streak) / 100;
      CharacterStatsUtils.updateExp(characterId, rewardExp, true);
      uint32 rewardGold = dailyQuestConfig.rewardGold * (100 + BONUS_REWARD_PERCENT * dailyQuestData.streak) / 100;
      CharacterFundUtils.increaseGold(characterId, rewardGold);
      uint8 newStreak = dailyQuestData.streak + 1;
      if (newStreak > MAX_STREAK) {
        newStreak = MAX_STREAK;
      }
      dailyQuestData = CharDailyQuestData({
        moveCount: 0,
        farmCount: 0,
        pvpCount: 0,
        pveCount: 0,
        streak: newStreak,
        startTime: dailyQuestData.startTime + DailyQuestUtils.ONE_DAY_SECONDS
      });
      CharDailyQuest.set(characterId, dailyQuestData);
    } else {
      revert Errors.DailyQuestSystem_TasksAreNotDone();
    }
  }
}
