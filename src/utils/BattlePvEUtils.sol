pragma solidity >=0.8.24;

import {
  CharPositionData,
  CharBattle,
  MonsterLocationData,
  Monster,
  MonsterStats,
  PvE,
  PvEData,
  PvEExtra,
  PvEExtraData,
  BossInfo
} from "@codegen/index.sol";
import { BattleInfo, BattleUtils } from "@utils/BattleUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { EntityType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";

library BattlePvEUtils {
  /// @dev perform and return the result of the fight
  /// hps is final hp of character and monster
  function performFight(
    uint256 characterId,
    uint256 monsterId,
    uint32 characterOriginHp,
    uint256[4] memory characterSkills,
    CharPositionData memory characterPosition,
    MonsterLocationData memory monsterLocation
  )
    public
    view
    returns (EntityType firstAttackerType, uint32[2] memory hps, uint32[9] memory damages)
  {
    // Build battle information for character and monster
    BattleInfo memory characterBattleInfo =
      BattleUtils.buildCharacterBattleInfo(characterId, characterSkills, characterOriginHp);
    BattleInfo memory monsterBattleInfo =
      BattleUtils.buildMonsterBattleInfo(monsterId, characterPosition.x, characterPosition.y, monsterLocation);

    // Determine the first attacker based on agility
    if (characterBattleInfo.agi >= monsterBattleInfo.agi) {
      firstAttackerType = EntityType.Character;
      (hps, damages) = BattleUtils.fight(characterBattleInfo, monsterBattleInfo);
    } else {
      firstAttackerType = EntityType.Monster;
      (hps, damages) = BattleUtils.fight(monsterBattleInfo, characterBattleInfo);
      // hps now is [monsterHP, characterHP], we need to swap it to [characterHP, monsterHP]
      (hps[0], hps[1]) = (hps[1], hps[0]);
    }

    return (firstAttackerType, hps, damages);
  }

  /// @dev store the result of battle
  function storePvEData(
    uint256 characterId,
    uint256 monsterId,
    uint32 characterOriginHp,
    EntityType firstAttacker,
    CharPositionData memory characterPosition,
    uint256[4] memory characterSkills,
    uint32[9] memory damages
  )
    public
  {
    // get origin hp if monster is boss, monsterHp will be zero with normal monster
    uint32 monsterHp = BossInfo.getHp(monsterId, characterPosition.x, characterPosition.y);
    uint256 currentCounter = PvE.getCounter(characterId);
    PvEData memory pve = PvEData({
      monsterId: monsterId,
      x: characterPosition.x,
      y: characterPosition.y,
      firstAttacker: firstAttacker,
      counter: currentCounter + 1,
      timestamp: block.timestamp,
      characterSkillIds: characterSkills,
      damages: damages,
      hps: [characterOriginHp, monsterHp]
    });
    PvE.set(characterId, pve);
    CharBattle.setPveLastAtkTime(characterId, block.timestamp);
  }

  function storePvEExtraData(uint256 characterId, uint256 rewardItemId, uint32 rewardItemAmount) public {
    PvEExtraData memory pveExtra = PvEExtraData({ itemId: rewardItemId, itemAmount: rewardItemAmount });
    PvEExtra.set(characterId, pveExtra);
  }

  function getExpAndPerkExpReward(
    uint256 monsterId,
    bool isBoss,
    uint16 monsterLevel,
    uint16 characterLevel
  )
    public
    view
    returns (uint32 exp, uint32 perkExp)
  {
    exp = Monster.getExp(monsterId);
    perkExp = Monster.getPerkExp(monsterId);
    if (isBoss) return (exp, perkExp);
    uint8 grow = Monster.getGrow(monsterId) / 3;
    uint16 multiplier = 100 + (monsterLevel - 1) * grow;
    exp = exp * multiplier / 100;
    perkExp = perkExp * multiplier / 100;
    if (characterLevel >= monsterLevel + 20) {
      // if the character's level is 20 or more above the monster's level, exp reward is zero
      exp = 0;
    } else if (characterLevel >= monsterLevel + 10) {
      // if the character's level is 10 or more above the monster's level, halve the exp
      exp /= 2;
    }
    return (exp, perkExp);
  }

  function handleBossResult(uint256 characterId, uint256 monsterId, uint32 monsterHp, int32 x, int32 y) public {
    if (monsterHp == 0) {
      BossInfo.setHp(monsterId, x, y, MonsterStats.getHp(monsterId));
      BossInfo.setLastDefeatedTime(monsterId, x, y, block.timestamp);
      CharacterFundUtils.increaseCrystal(characterId, BossInfo.getCrystal(monsterId, x, y));
    } else {
      BossInfo.setHp(monsterId, x, y, monsterHp);
    }
  }

  function checkIsReadyToBattle(uint256 characterId) public view {
    uint256 lastPvETimestamp = CharBattle.getPveLastAtkTime(characterId);
    uint256 nextBattleTimestamp = lastPvETimestamp + Config.ATTACK_COOLDOWN;
    if (block.timestamp < nextBattleTimestamp) {
      revert Errors.PvE_NotReadyToBattle(nextBattleTimestamp);
    }
  }

  function checkIsBossReady(uint256 monsterId, CharPositionData memory characterPosition) public view {
    uint256 respawnTime = BossInfo.getLastDefeatedTime(monsterId, characterPosition.x, characterPosition.y)
      + uint32(BossInfo.getRespawnDuration(monsterId, characterPosition.x, characterPosition.y)) * 24 * 60 * 60;
    if (block.timestamp < respawnTime) {
      revert Errors.PvE_BossIsNotRespawnedYet(monsterId, respawnTime);
    }
  }
}
