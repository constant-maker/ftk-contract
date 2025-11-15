pragma solidity >=0.8.24;

import {
  CharPositionData,
  CharBattle,
  MonsterLocation,
  MonsterLocationData,
  Monster,
  CharEquipment,
  CharGrindSlot,
  ExpAmpConfig,
  ExpAmpConfigData,
  CharExpAmp,
  CharExpAmpData,
  PvEAfk,
  PvEAfkData,
  PvEAfkLoc,
  CharState,
  CharBattle,
  ItemV2,
  Equipment,
  CharCurrentStats,
  CharStats
} from "@codegen/index.sol";
import { CharacterStateType, SlotType } from "@codegen/common.sol";
import { BattleUtils } from "./BattleUtils.sol";
import { BattlePvEUtils } from "./BattlePvEUtils.sol";
import { CharacterPerkUtils } from "./CharacterPerkUtils.sol";
import { CharacterStateUtils } from "./CharacterStateUtils.sol";
import { CharacterStatsUtils } from "./CharacterStatsUtils.sol";
import { Config, Errors } from "@common/index.sol";

library BattlePvEUtils2 {
  function startPvEAFK(
    uint256 characterId,
    uint256 monsterId,
    PvEAfkData memory afkData,
    CharPositionData memory characterPosition
  )
    public
  {
    if (PvEAfkLoc.getMonsterId(characterPosition.x, characterPosition.y) == monsterId) {
      revert Errors.PvE_SomeoneIsFightingThisMonster(characterPosition.x, characterPosition.y, monsterId);
    }
    MonsterLocationData memory monsterLocation =
      MonsterLocation.get(characterPosition.x, characterPosition.y, monsterId);
    if (monsterLocation.level == 0) {
      revert Errors.PvE_MonsterIsNotExist(characterPosition.x, characterPosition.y, monsterId);
    }
    if (!_isCapableToAFK(characterId, monsterId, characterPosition, monsterLocation)) {
      revert Errors.PvE_NotCapableToAFK(
        characterId, monsterId, characterPosition.x, characterPosition.y, monsterLocation.level
      );
    }
    uint16 charLevel = CharStats.getLevel(characterId);
    (uint32 gainedExp, uint32 gainedPerkExp) =
      BattlePvEUtils.getExpAndPerkExpReward(monsterId, false, monsterLocation.level, charLevel);
    uint32 maxExp = _calculateMaxAFKExp(monsterLocation.level, charLevel, characterId);
    uint32 maxTick = gainedExp == 0 ? 0 : maxExp / gainedExp;
    PvEAfk.set(characterId, monsterId, block.timestamp, gainedExp, gainedPerkExp, maxTick);
    PvEAfkLoc.set(characterPosition.x, characterPosition.y, monsterId);
    CharState.setState(characterId, CharacterStateType.Hunting);
  }

  function stopPvEAFK(uint256 characterId, PvEAfkData memory afkData, CharPositionData memory characterPosition) public {
    CharacterStateUtils.mustInState(characterId, CharacterStateType.Hunting);
    if (afkData.monsterId == 0) {
      revert Errors.PvE_AfkNotStarted(characterId);
    }
    uint32 tick = uint32((block.timestamp - afkData.startTime) / Config.PVE_ATTACK_COOLDOWN);
    if (tick != 0) {
      uint32 gainedExp = afkData.maxTick > tick ? tick * afkData.expPerTick : afkData.maxTick * afkData.expPerTick;
      uint32 gainedPerkExp = tick * afkData.perkExpPerTick;
      // update character exp and perk exp
      updateCharacterExp(characterId, gainedExp, gainedPerkExp);

      CharBattle.setPveLastAtkTime(characterId, block.timestamp);
    }

    // reset afk data
    PvEAfk.deleteRecord(characterId);
    PvEAfkLoc.deleteRecord(characterPosition.x, characterPosition.y);
    CharState.setState(characterId, CharacterStateType.Standby);
  }

  function updateCharacterExp(uint256 characterId, uint32 gainedExp, uint32 gainedPerkExp) public {
    ExpAmpConfigData memory expAmpConfig = ExpAmpConfig.get();
    uint32 baseExpPercent = 100;
    uint32 basePerkExpPercent = 100;
    // apply global exp amp
    if (block.timestamp <= expAmpConfig.expireTime) {
      baseExpPercent += expAmpConfig.pveExpAmp;
      basePerkExpPercent += expAmpConfig.pveExpAmp;
    }
    // apply character exp amp
    CharExpAmpData memory charExpAmp = CharExpAmp.get(characterId);
    if (block.timestamp <= charExpAmp.expireTime) {
      baseExpPercent += charExpAmp.pveExpAmp;
      basePerkExpPercent += charExpAmp.pveExpAmp;
    }
    // calculate final exp and perk exp after applying all amps
    gainedExp = (gainedExp * baseExpPercent) / 100;
    gainedPerkExp = (gainedPerkExp * basePerkExpPercent) / 100;
    // update character exp and perk exp
    CharCurrentStats.setExp(characterId, CharCurrentStats.getExp(characterId) + gainedExp);
    SlotType grindSlot = CharGrindSlot.get(characterId);
    uint256 grindEquipmentId = CharEquipment.getEquipmentId(characterId, grindSlot);
    if (grindEquipmentId != 0) {
      uint256 itemId = Equipment.getItemId(grindEquipmentId);
      CharacterPerkUtils.updateCharacterPerkExp(characterId, ItemV2.getItemType(itemId), gainedPerkExp);
    }
  }

  function _calculateMaxAFKExp(
    uint16 monsterLevel,
    uint16 characterLevel,
    uint256 characterId
  )
    private
    view
    returns (uint32 maxExp)
  {
    if (characterLevel >= monsterLevel + 20) {
      // if the character's level is 20 or more above the monster's level, exp reward is zero
      return 0;
    } else if (characterLevel >= monsterLevel + 10) {
      maxExp = CharacterStatsUtils.calculateRequiredExp(characterId, characterLevel, monsterLevel + 20);
    } else {
      maxExp = CharacterStatsUtils.calculateRequiredExp(characterId, characterLevel, monsterLevel + 10);
    }
    uint32 currentExp = CharCurrentStats.getExp(characterId);
    if (currentExp >= maxExp) {
      // if character's current exp is already greater than or equal to max exp, return zero
      return 0;
    }
    return maxExp - currentExp;
  }

  /// @dev check if character is capable to AFK with the monster - receive no damage from the monster
  function _isCapableToAFK(
    uint256 characterId,
    uint256 monsterId,
    CharPositionData memory characterPosition,
    MonsterLocationData memory monsterLocation
  )
    private
    view
    returns (bool isCapable)
  {
    uint256[5] memory characterSkills = BattleUtils.getCharacterSkillIds(characterId);
    uint32 currentCharacterHp = CharCurrentStats.getHp(characterId);
    // use a dummy hp to perform the fight, cuz we don't care about the actual fight result
    (, uint32[2] memory hps,) = BattlePvEUtils.performFight(
      characterId, monsterId, currentCharacterHp, characterSkills, characterPosition, monsterLocation
    );
    if (hps[0] == currentCharacterHp && hps[1] == 0) {
      // if character's hp is not changed and monster's hp is zero, it means the character can AFK with this monster
      return true;
    }
    return false;
  }
}
