pragma solidity >=0.8.24;

import {
  SkillV2,
  SkillV2Data,
  Monster,
  CharStats,
  CharCurrentStats,
  CharCurrentStatsData,
  CharCStats2,
  CharSkill,
  CharEquipment,
  SkillEffect,
  SkillEffectData
} from "@codegen/index.sol";
import { AdvantageType, SlotType, EffectType } from "@codegen/common.sol";
import { Config } from "@common/index.sol";
import { CharacterEquipmentUtils } from "./CharacterEquipmentUtils.sol";
import { CharacterBuffUtils } from "./CharacterBuffUtils.sol";

struct BattleInfo {
  uint256 id;
  uint32 barrier;
  uint32 hp;
  uint16 atk;
  uint16 def;
  uint16 agi;
  uint16 level;
  AdvantageType advantageType;
  uint256[5] skillIds;
}

library BattleUtils {
  /// @dev Return list of valid skills based on character SP.
  function getCharacterSkillIds(uint256 characterId) public view returns (uint256[5] memory skillIds) {
    uint8 characterSp = CharStats.getSp(characterId);
    int8 buffSp = CharacterBuffUtils.getBuffSp(characterId);
    if (buffSp < 0) {
      uint8 absBuff = uint8(-buffSp);
      characterSp = characterSp > absBuff ? characterSp - absBuff : 0;
    } else {
      characterSp += uint8(buffSp);
    }
    uint256[5] memory characterSkillIds = CharSkill.getSkillIds(characterId);

    return reBuildSkills(characterSkillIds, characterSp);
  }

  function reBuildSkills(
    uint256[5] memory originSkillIds,
    uint8 totalSp
  )
    public
    view
    returns (uint256[5] memory skillIds)
  {
    for (uint256 i = 0; i < originSkillIds.length; i++) {
      uint256 skillId = originSkillIds[i];
      uint8 skillSp = skillId == Config.NORMAL_ATTACK_SKILL_ID ? 0 : SkillV2.getSp(skillId);

      if (totalSp >= skillSp) {
        skillIds[i] = skillId;
        totalSp -= skillSp;
      } else {
        skillIds[i] = Config.NORMAL_ATTACK_SKILL_ID;
      }
    }

    return skillIds;
  }

  /// @dev build character BattleInfo
  function buildCharacterBattleInfo(
    uint256 characterId,
    uint256[5] memory characterSkills,
    uint32 characterHp
  )
    public
    view
    returns (BattleInfo memory characterBattleInfo)
  {
    (int16 buffAtk, int16 buffDef, int16 buffAgi) = CharacterBuffUtils.getBuffStats(characterId);
    CharCurrentStatsData memory characterCurrentStats = CharCurrentStats.get(characterId);
    // debuff always < 100%
    // so it will not decrease atk def agi below 0, so we can safely cast to uint16
    uint16 finalAtk = getFinalStat(characterCurrentStats.atk, buffAtk);
    uint16 finalDef = getFinalStat(characterCurrentStats.def, buffDef);
    uint16 finalAgi = getFinalStat(characterCurrentStats.agi, buffAgi);
    characterBattleInfo = BattleInfo({
      id: characterId,
      barrier: CharCStats2.getBarrier(characterId),
      hp: characterHp,
      atk: finalAtk,
      def: finalDef,
      agi: finalAgi,
      level: CharStats.getLevel(characterId),
      skillIds: characterSkills,
      advantageType: CharacterEquipmentUtils.getCharacterAdvantageType(characterId)
    });
  }

  /// @dev return dmg and hp result after a battle
  function fight(
    BattleInfo memory attacker,
    BattleInfo memory defender
  )
    public
    view
    returns (uint32[2] memory hps, uint32[11] memory dmgResult)
  {
    (uint16 attackerDmgMultiplier, uint16 defenderDmgMultiplier) =
      getDamageMultiplier(attacker.advantageType, defender.advantageType);
    // bonus attack based on agility
    if (attacker.agi >= defender.agi + Config.BONUS_ATTACK_AGI_DIFF) {
      handleFirstAttack(attacker, defender, dmgResult, attackerDmgMultiplier, attacker.agi - defender.agi);
      if (defender.hp == 0) {
        hps[0] = attacker.hp;
        hps[1] = 0;
        return (hps, dmgResult);
      }
    }
    // main battle loop
    SkillV2Data memory normalAtk = SkillV2.get(Config.NORMAL_ATTACK_SKILL_ID);
    uint8 index = 1;
    SkillEffectData memory attackerDebuff;
    SkillEffectData memory defenderDebuff;

    while (index < 11) {
      // first attacker's turn to attack
      if (attacker.hp == 0) break;
      doTurnFight(
        attacker, defender, normalAtk, dmgResult, attackerDmgMultiplier, index++, attackerDebuff, defenderDebuff
      );

      // second attacker's turn to attack
      if (defender.hp == 0) break;
      doTurnFight(
        defender, attacker, normalAtk, dmgResult, defenderDmgMultiplier, index++, defenderDebuff, attackerDebuff
      );
    }
    hps[0] = attacker.hp;
    hps[1] = defender.hp;
    return (hps, dmgResult);
  }

  function doTurnFight(
    BattleInfo memory attacker,
    BattleInfo memory defender,
    SkillV2Data memory normalAtk,
    uint32[11] memory dmgResult,
    uint16 attackerDmgMultiplier,
    uint256 dmgIndex,
    SkillEffectData memory attackerDebuff,
    SkillEffectData memory defenderDebuff
  )
    public
    view
  {
    if (attackerDebuff.turns > 0 && attackerDebuff.effect == EffectType.Stun && !Monster.getIsBoss(attacker.id)) {
      dmgResult[dmgIndex] = 0;
      attackerDebuff.turns--;
      return;
    }
    uint16 skillBonus;
    uint256 skillId = dmgIndex == 0 ? 0 : attacker.skillIds[(dmgIndex - 1) / 2];
    SkillV2Data memory skill = getSkillData(skillId, normalAtk);
    if (skill.hasEffect) {
      SkillEffectData memory skillEffect = SkillEffect.get(skillId);
      defenderDebuff.damage = skillEffect.damage;
      defenderDebuff.effect = skillEffect.effect;
      defenderDebuff.turns = skillEffect.turns;
    }
    if (defenderDebuff.turns > 0 && defenderDebuff.damage > 0) {
      skillBonus = defenderDebuff.damage;
      defenderDebuff.turns--;
    }
    uint32 damage =
      calculateDamage(attacker.level, attacker.atk, defender.def, skill.damage + skillBonus, attackerDmgMultiplier);
    applyDamageToDefender(defender, damage);
    dmgResult[dmgIndex] = damage;
  }

  function handleFirstAttack(
    BattleInfo memory attacker,
    BattleInfo memory defender,
    uint32[11] memory dmgResult,
    uint16 attackerDmgMultiplier,
    uint16 bonusDmg
  )
    public
    view
  {
    SkillEffectData memory debuff;
    SkillV2Data memory normalAtk = SkillV2.get(Config.NORMAL_ATTACK_SKILL_ID);
    normalAtk.damage += bonusDmg;
    doTurnFight(attacker, defender, normalAtk, dmgResult, attackerDmgMultiplier, 0, debuff, debuff);
  }

  /// @dev calculate damage multiplier (%) based on advantage type
  function getDamageMultiplier(AdvantageType entity1, AdvantageType entity2) public pure returns (uint16, uint16) {
    uint16 advantageMultiplier = 100 + Config.ADVANTAGE_TYPE_DAMAGE_MODIFIER;
    uint16 disadvantageMultiplier = 100 - Config.ADVANTAGE_TYPE_DAMAGE_MODIFIER;
    if (
      (entity1 == AdvantageType.Red && entity2 == AdvantageType.Green)
        || (entity1 == AdvantageType.Green && entity2 == AdvantageType.Blue)
        || (entity1 == AdvantageType.Blue && entity2 == AdvantageType.Red)
    ) {
      return (advantageMultiplier, disadvantageMultiplier);
    }
    if (
      (entity1 == AdvantageType.Green && entity2 == AdvantageType.Red)
        || (entity1 == AdvantageType.Blue && entity2 == AdvantageType.Green)
        || (entity1 == AdvantageType.Red && entity2 == AdvantageType.Blue)
    ) {
      return (disadvantageMultiplier, advantageMultiplier);
    }
    return (100, 100);
  }

  /// @dev calculate damage with skill multiplier, skillDmg is percent of atk dmg
  function calculateDamage(
    uint16 level,
    uint16 atk,
    uint16 def,
    uint16 skillDmg,
    uint16 dmgMultiplier
  )
    public
    pure
    returns (uint32 rawDmg)
  {
    rawDmg = Config.BASE_DMG;
    if (atk >= def) {
      rawDmg += (atk - def) + level;
    } else if (atk < def) {
      uint32 dmgReduce = uint32(def - atk) * 30 / 100; // 30%
      uint32 levelDmg = level > dmgReduce ? level - dmgReduce : 0;
      rawDmg += levelDmg;
    }
    // (rawDmg * skillDmg / 100) * dmgMultiplier / 100;
    return (rawDmg * uint32(skillDmg) * uint32(dmgMultiplier)) / 10_000;
  }

  /// @dev apply damage and update hp
  function applyDamageToDefender(BattleInfo memory defender, uint32 damage) public pure {
    if (defender.barrier >= damage) {
      defender.barrier -= damage;
    } else {
      damage -= defender.barrier; // subtract the barrier from damage
      defender.barrier = 0; // set barrier to 0
      defender.hp = defender.hp > damage ? defender.hp - damage : 0;
    }
  }

  /// @dev return skill data based on skillId
  function getSkillData(uint256 skillId, SkillV2Data memory normalAtk) public view returns (SkillV2Data memory skill) {
    skill = skillId == Config.NORMAL_ATTACK_SKILL_ID ? normalAtk : SkillV2.get(skillId);
    return skill;
  }

  function getCharacterEquipments(uint256 characterId) public view returns (uint256[6] memory equipmentIds) {
    for (uint8 i = 0; i <= uint8(SlotType.Mount); i++) {
      equipmentIds[i] = CharEquipment.getEquipmentId(characterId, SlotType(i));
    }
    return equipmentIds;
  }

  function getFinalStat(uint16 baseStat, int16 buffStat) public pure returns (uint16) {
    if (buffStat < 0) {
      uint16 absBuff = uint16(-buffStat);
      return baseStat > absBuff ? baseStat - absBuff : 0;
    } else {
      return baseStat + uint16(buffStat);
    }
  }
}
