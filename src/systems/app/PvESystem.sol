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
  PvEExtra
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
    uint256 monsterId
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
    // check respawn time if monster is boss
    bool isBoss = Monster.getIsBoss(monsterId);
    if (isBoss) {
      BattlePvEUtils.checkIsBossReady(monsterId, characterPosition);
    }
    // battle
    (uint32 characterHp, uint32 monsterHp) = _battle(characterId, monsterId, characterPosition, monsterLocation);
    // handle result
    _handleBattleResult(
      characterId,
      monsterId,
      isBoss,
      characterHp,
      monsterHp,
      monsterLocation.level,
      characterPosition.x,
      characterPosition.y
    );
    if (isBoss) {
      BattlePvEUtils.handleBossResult(characterId, monsterId, monsterHp, characterPosition.x, characterPosition.y);
    }
  }

  function _handleBattleResult(
    uint256 characterId,
    uint256 monsterId,
    bool isBoss,
    uint32 characterHp,
    uint32 monsterHp,
    uint16 monsterLevel,
    int32 x,
    int32 y
  )
    private
  {
    if (characterHp == 0) {
      // character lost
      CharacterPositionUtils.moveToCapital(characterId);
      characterHp = CharStats.getHp(characterId); // set character hp to max hp
      CharCurrentStats.setExp(characterId, CharCurrentStats.getExp(characterId) * 75 / 100); // penalty 25% current exp
      if (PvEExtra.getItemId(characterId) != 0) {
        PvEExtra.deleteRecord(characterId); // reset extra data
      }
    } else if (monsterHp == 0) {
      // character won
      (uint32 gainedExp, uint32 gainedPerkExp) =
        BattlePvEUtils.getExpAndPerkExpReward(monsterId, isBoss, monsterLevel, CharStats.getLevel(characterId));
      // claim reward item
      (uint256 itemId, uint32 amount) = BattleUtils.getRewardItem(characterId, monsterId);
      if (itemId != 0) {
        InventoryItemUtils.addItem(characterId, itemId, amount);
        BattlePvEUtils.storePvEExtraData(characterId, itemId, amount);
      }
      _updateCharacterExp(characterId, gainedExp, gainedPerkExp);
      // check and update daily quest
      DailyQuestUtils.updatePveCount(characterId);
      // increase slot farm
      TileUtils.increaseFarmSlot(x, y);
      if (isBoss) {
        CharAchievementUtils.addAchievement(characterId, 3); // defeated the boss
        CharAchievementUtils.addAchievement(characterId, 4); // defeated the Ignis
      }
      if (_tryToLevelUp(characterId)) return; // if level up success character hp will be recover to max hp
    }
    CharCurrentStats.setHp(characterId, characterHp);
  }

  function _updateCharacterExp(uint256 characterId, uint32 gainedExp, uint32 gainedPerkExp) private {
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
    MonsterLocationData memory monsterLocation
  )
    private
    returns (uint32 characterFinalHp, uint32 monsterFinalHp)
  {
    uint256[4] memory characterSkills = BattleUtils.getCharacterSkillIds(characterId);
    // perform the fight and get results
    uint32 characterOriginHp = CharCurrentStats.getHp(characterId);
    (EntityType firstAttacker, uint32[2] memory hps, uint32[9] memory damages) = BattlePvEUtils.performFight(
      characterId, monsterId, characterOriginHp, characterSkills, characterPosition, monsterLocation
    );

    // store PvEData
    BattlePvEUtils.storePvEData(
      characterId, monsterId, characterOriginHp, firstAttacker, characterPosition, characterSkills, damages
    );

    return (hps[0], hps[1]);
  }
}