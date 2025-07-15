pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { WorldContextProviderLib } from "@latticexyz/world/src/WorldContext.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharEquipment,
  CharGrindSlot,
  CharPositionData,
  CharCurrentStats,
  CharStats,
  MonsterLocation,
  MonsterLocationData,
  Monster,
  Equipment,
  Item,
  PvEExtraV2,
  ExpAmpConfig,
  ExpAmpConfigData
} from "@codegen/index.sol";
import { CharacterPositionUtils, CharacterPerkUtils } from "@utils/index.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { BattleUtils } from "@utils/BattleUtils.sol";
import { BattlePvEUtils } from "@utils/BattlePvEUtils.sol";
import { DailyQuestUtils } from "@utils/DailyQuestUtils.sol";
import { SystemUtils } from "@utils/SystemUtils.sol";
import { TileUtils } from "@utils/TileUtils.sol";
import { CharacterStateType, EntityType, SlotType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";
import { CharAchievementUtils } from "@utils/CharAchievementUtils.sol";

contract PvESystem is System, CharacterAccessControl {
  /// @dev character init a battle with a monster
  function battlePvE(
    uint256 characterId,
    uint256 monsterId,
    bool claimItem
  )
    public
    onlyAuthorizedWallet(characterId)
    mustInState(characterId, CharacterStateType.Standby)
    validateCurrentWeight(characterId)
  {
    // check whether character is ready to battle
    BattlePvEUtils.checkIsReadyToBattle(characterId);
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    MonsterLocationData memory monsterLocation =
      MonsterLocation.get(characterPosition.x, characterPosition.y, monsterId);
    if (monsterLocation.level == 0) {
      revert Errors.PvE_MonsterIsNotExist(characterPosition.x, characterPosition.y, monsterId);
    }
    // check if monster is boss and check respawn time
    BattlePvEUtils.checkIsBossReady(monsterId, characterPosition);
    // battle
    _battle(characterId, monsterId, characterPosition, monsterLocation, claimItem);
  }

  function _handleBattleResult(
    uint256 characterId,
    uint256 monsterId,
    uint32 characterHp,
    uint32 monsterHp,
    uint16 monsterLevel,
    CharPositionData memory characterPosition,
    bool claimItem
  )
    private
  {
    bool isBoss = Monster.getIsBoss(monsterId);
    if (characterHp == 0) {
      // character lost
      BattleUtils.applyLoss(characterId, characterPosition);
      CharacterPositionUtils.moveToCapital(characterId);
      characterHp = CharStats.getHp(characterId); // set character hp to max hp
      CharCurrentStats.setExp(characterId, CharCurrentStats.getExp(characterId) * 75 / 100); // penalty 25% current exp
      if (PvEExtraV2.getItemId(characterId) != 0) {
        PvEExtraV2.deleteRecord(characterId); // reset extra data
      }
    } else if (monsterHp == 0) {
      // character won
      (uint32 gainedExp, uint32 gainedPerkExp) =
        BattlePvEUtils.getExpAndPerkExpReward(monsterId, isBoss, monsterLevel, CharStats.getLevel(characterId));
      if (claimItem) {
        // claim reward
        BattlePvEUtils.claimReward(characterId, monsterId);
      }
      _updateCharacterExp(characterId, gainedExp, gainedPerkExp);
      // check and update daily quest
      DailyQuestUtils.updatePveCount(characterId);
      // increase slot farm
      TileUtils.increaseFarmSlot(characterPosition.x, characterPosition.y);
      if (isBoss) {
        CharAchievementUtils.addAchievement(characterId, 3); // defeated the first boss
        if (monsterId == 9) {
          CharAchievementUtils.addAchievement(characterId, 4); // defeated the Ignis
        } else if (monsterId == 42) {
          CharAchievementUtils.addAchievement(characterId, 11); // defeated Kalyndra the Great Serpent
        }
      }
      if (_tryToLevelUp(characterId)) return; // if level up success character hp will be recover to max hp
    }
    CharCurrentStats.setHp(characterId, characterHp);
  }

  function _updateCharacterExp(uint256 characterId, uint32 gainedExp, uint32 gainedPerkExp) private {
    ExpAmpConfigData memory expAmpConfig = ExpAmpConfig.get();
    if (block.timestamp <= expAmpConfig.expireTime) {
      gainedExp = (gainedExp * expAmpConfig.pveExpAmp) / 100;
      gainedPerkExp = (gainedPerkExp * expAmpConfig.pvePerkAmp) / 100;
    }
    // update character exp and perk exp
    CharCurrentStats.setExp(characterId, CharCurrentStats.getExp(characterId) + gainedExp);
    SlotType grindSlot = CharGrindSlot.get(characterId);
    uint256 grindEquipmentId = CharEquipment.getEquipmentId(characterId, grindSlot);
    if (grindEquipmentId != 0) {
      uint256 itemId = Equipment.getItemId(grindEquipmentId);
      CharacterPerkUtils.updateCharacterPerkExp(characterId, Item.getItemType(itemId), gainedPerkExp);
    }
  }

  // try to level up character to next level if exp is enough
  function _tryToLevelUp(uint256 characterId) private returns (bool) {
    address levelSystem = SystemUtils.getSystemAddress("LevelSystem");
    bytes memory callData = abi.encodeWithSignature("levelUp(uint256,uint16)", characterId, 1);
    (bool success,) = WorldContextProviderLib.delegatecallWithContext(_msgSender(), _msgValue(), levelSystem, callData);
    // (bool success,) = WorldContextProviderLib.callWithContext(_msgSender(), _msgValue(), levelSystem, callData);
    return success;
  }

  function _battle(
    uint256 characterId,
    uint256 monsterId,
    CharPositionData memory characterPosition,
    MonsterLocationData memory monsterLocation,
    bool claimItem
  )
    private
  {
    uint256[5] memory characterSkills = BattleUtils.getCharacterSkillIds(characterId);
    // perform the fight and get results
    uint32 characterOriginHp = CharCurrentStats.getHp(characterId);
    (EntityType firstAttacker, uint32[2] memory hps, uint32[11] memory damages) = BattlePvEUtils.performFight(
      characterId, monsterId, characterOriginHp, characterSkills, characterPosition, monsterLocation
    );

    // store PvEData
    BattlePvEUtils.storePvEData(
      characterId, monsterId, characterOriginHp, firstAttacker, characterPosition, characterSkills, damages
    );

    // handle battle result
    _handleBattleResult(characterId, monsterId, hps[0], hps[1], monsterLocation.level, characterPosition, claimItem);
    BattlePvEUtils.handleBossResult(characterId, monsterId, hps[1], characterPosition);
  }
}
