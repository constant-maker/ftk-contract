pragma solidity >=0.8.24;

import { CharPosition, CharPositionData, CharQuestStatus, Npc, NpcData, QuestV4, QuestV4Data } from "@codegen/index.sol";
import { QuestStatusType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { CharacterPositionUtils } from "./CharacterPositionUtils.sol";
import { CharAchievementUtils } from "./CharAchievementUtils.sol";

library CharacterQuestUtils {
  /// @dev Verify whether the player character and the NPC are at the same position.
  function mustSameNpcPosition(uint256 characterId, uint256 npcId) internal view {
    NpcData memory npc = Npc.get(npcId);
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);

    if (characterPosition.x != npc.x || characterPosition.y != npc.y) {
      revert Errors.QuestSystem_NotSamePositionWithNpc(characterPosition.x, characterPosition.y, npc.x, npc.y);
    }
  }

  /// @dev Check if character receives quest from right npc, quest is not done yet,
  /// and the character has completed all previous quests
  function mustReceiveValidQuest(uint256 characterId, uint256 npcId, uint256 questId) internal view {
    QuestV4Data memory questData = QuestV4.get(questId);
    if (questData.fromNpcId == 0 && questData.exp == 0 && questData.gold == 0) {
      revert Errors.QuestSystem_QuestNotFound(questId);
    }
    if (questData.fromNpcId != npcId) {
      revert Errors.QuestSystem_ReceiveFromWrongNpc(npcId, questId);
    }
    if (CharQuestStatus.getQuestStatus(characterId, questId) != QuestStatusType.NotReceived) {
      revert Errors.QuestSystem_AlreadyReceived(npcId, questId);
    }
    for (uint256 i; i < questData.requiredAchievementIds.length; i++) {
      uint256 achievementId = questData.requiredAchievementIds[i];
      if (!CharAchievementUtils.hasAchievement(characterId, achievementId)) {
        revert Errors.QuestSystem_RequiredAchievementNotCompleted(characterId, achievementId);
      }
    }
    uint256[] memory requiredDoneQuestIds = questData.requiredDoneQuestIds;
    for (uint256 i; i < requiredDoneQuestIds.length; i++) {
      if (CharQuestStatus.getQuestStatus(characterId, requiredDoneQuestIds[i]) != QuestStatusType.Done) {
        revert Errors.QuestSystem_RequiredQuestsAreNotDone(characterId, requiredDoneQuestIds[i]);
      }
    }
  }

  function mustFinishInProgressQuest(uint256 characterId, uint256 questId) internal view {
    if (CharQuestStatus.getQuestStatus(characterId, questId) != QuestStatusType.InProgress) {
      revert Errors.QuestSystem_MustFinishInProgressQuest(characterId, questId);
    }
  }
}
