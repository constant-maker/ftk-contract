pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import {
  CharSocialQuest,
  CharQuestStatus,
  CharPosition,
  CharPositionData,
  QuestLocate,
  QuestLocateData,
  QuestLocateTracking2,
  Npc,
  CityVault
} from "@codegen/index.sol";
import { Quest2 } from "@codegen/tables/Quest2.sol";
import { QuestContribute, QuestContributeData } from "@codegen/tables/QuestContribute.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharacterQuestUtils, InventoryItemUtils, CharacterStatsUtils, CharacterFundUtils } from "@utils/index.sol";
import { QuestStatusType, QuestType, SocialType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharAchievementUtils } from "@utils/CharAchievementUtils.sol";

contract QuestSystem is System, CharacterAccessControl {
  /// @dev receive quest
  function receiveQuest(
    uint256 characterId,
    uint256 fromNpcId,
    uint256 questId
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    CharacterQuestUtils.mustReceiveValidQuest(characterId, fromNpcId, questId);
    CharacterQuestUtils.mustSameNpcPosition(characterId, fromNpcId);

    CharQuestStatus.set(characterId, questId, QuestStatusType.InProgress);
  }

  /// @dev finish quest with a specific npc
  function finishQuest(uint256 characterId, uint256 toNpcId, uint256 questId) public onlyAuthorizedWallet(characterId) {
    QuestType questType = Quest2.getQuestType(questId);
    if (Quest2.getToNpcId(questId) != toNpcId) {
      revert Errors.QuestSystem_FinishWithWrongNpc(toNpcId, questId);
    }
    CharacterQuestUtils.mustFinishInProgressQuest(characterId, questId);
    if (questType == QuestType.Contribute) {
      CharacterQuestUtils.mustSameNpcPosition(characterId, toNpcId);
      _finishContributeQuest(characterId, toNpcId, questId);
    } else if (questType == QuestType.Locate) {
      _finishLocateQuest(characterId, toNpcId, questId);
    }
  }

  /// @dev finish and claim social quest reward
  function finishSocialQuest(uint256 characterId, SocialType socialType) public onlyAuthorizedWallet(characterId) {
    uint32 rewardGold = 10; // this is fixed for social quest
    if (socialType == SocialType.Twitter && !CharSocialQuest.getTwitter(characterId)) {
      CharacterFundUtils.increaseGold(characterId, rewardGold);
      CharSocialQuest.setTwitter(characterId, true);
    } else if (socialType == SocialType.Discord && !CharSocialQuest.getDiscord(characterId)) {
      CharacterFundUtils.increaseGold(characterId, rewardGold);
      CharSocialQuest.setDiscord(characterId, true);
    } else if (socialType == SocialType.Telegram && !CharSocialQuest.getTelegram(characterId)) {
      CharacterFundUtils.increaseGold(characterId, rewardGold);
      CharSocialQuest.setTelegram(characterId, true);
    } else {
      revert Errors.QuestSystem_InvalidSocialTypeOrAlreadyClaimed(characterId, socialType);
    }
  }

  function _finishContributeQuest(uint256 characterId, uint256 npcId, uint256 questId) private {
    QuestContributeData memory questContribute = QuestContribute.get(questId);
    uint256 lenResourceIds = questContribute.itemIds.length;
    uint256 lenAmounts = questContribute.amounts.length;
    if (lenResourceIds != lenAmounts) {
      revert Errors.QuestSystem_InvalidContributeQuest(lenResourceIds, lenAmounts);
    }
    uint256 cityId = Npc.getCityId(npcId);
    for (uint256 i; i < questContribute.itemIds.length; i++) {
      uint256 itemId = questContribute.itemIds[i];
      uint32 amount = questContribute.amounts[i];
      InventoryItemUtils.removeItem(characterId, itemId, amount);
      // update city vault
      uint32 currentResourceAmount = CityVault.getAmount(cityId, itemId);
      CityVault.setAmount(cityId, itemId, currentResourceAmount + amount);
    }
    CharQuestStatus.set(characterId, questId, QuestStatusType.Done);
    _claimReward(characterId, questId);
  }

  function _finishLocateQuest(uint256 characterId, uint256 toNpcId, uint256 questId) private {
    QuestLocateData memory questLocate = QuestLocate.get(questId);
    if (questLocate.xs.length == 0 || questLocate.xs.length != questLocate.ys.length) {
      revert Errors.QuestSystem_InvalidLocateQuest(questLocate.xs.length, questLocate.ys.length);
    }
    uint8 trackIndex = QuestLocateTracking2.get(characterId, questId);
    if (trackIndex == questLocate.xs.length) {
      // already done the locate task
      CharacterQuestUtils.mustSameNpcPosition(characterId, toNpcId);
      if (QuestContribute.lengthItemIds(questId) > 0) {
        _finishContributeQuest(characterId, toNpcId, questId);
      } else {
        CharQuestStatus.set(characterId, questId, QuestStatusType.Done);
        _claimReward(characterId, questId);
      }
      return;
    }
    int32 comparedX = questLocate.xs[trackIndex];
    int32 comparedY = questLocate.ys[trackIndex];
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    if (characterPosition.x == comparedX && characterPosition.y == comparedY) {
      QuestLocateTracking2.set(characterId, questId, trackIndex + 1);
    } else {
      revert Errors.QuestSystem_WrongLocation(comparedX, comparedY, characterPosition.x, characterPosition.y);
    }
  }

  function _claimReward(uint256 characterId, uint256 questId) private {
    uint32 questExp = Quest2.getExp(questId);
    CharacterStatsUtils.updateExp(characterId, questExp, true);
    uint32 questGold = Quest2.getGold(questId);
    CharacterFundUtils.increaseGold(characterId, questGold);
    uint256 achievementId = Quest2.getAchievementId(questId);
    if (achievementId > 0) {
      CharAchievementUtils.addAchievement(characterId, achievementId);
    }
  }
}
