pragma solidity >=0.8.24;

import {
  Skill,
  SkillData,
  CharStats,
  CharCurrentStats,
  CharCurrentStatsData,
  CharSkill,
  CharEquipment,
  SkillEffect,
  SkillEffectData,
  Equipment,
  EquipmentInfo,
  EquipmentInfoData
} from "@codegen/index.sol";
import { AdvantageType, SlotType, EffectType } from "@codegen/common.sol";
import { Config } from "@common/index.sol";
import { CharacterEquipmentUtils } from "./CharacterEquipmentUtils.sol";
import { CharacterBuffUtils } from "./CharacterBuffUtils.sol";

struct WeaponInfo {
  AdvantageType advantageType;
  bool isTwoHanded;
}

struct BattleInfo {
  uint256 id;
  uint32 barrier;
  uint32 hp;
  uint16 atk;
  uint16 def;
  uint16 agi;
  uint16 level;
  uint256[5] skillIds;
  WeaponInfo weaponInfo;
}

struct TurnFightContext {
  SkillData normalAtk;
  uint32[11] dmgResult;
  uint16 dmgMultiplier;
  uint256 dmgIndex;
  SkillEffectData attackerDebuff;
  SkillEffectData defenderDebuff;
  bool attackerStunImmune;
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
      uint8 skillSp = skillId == Config.NORMAL_ATTACK_SKILL_ID ? 0 : Skill.getSp(skillId);

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
    uint16 finalAtk = _getFinalStat(characterCurrentStats.atk, buffAtk);
    uint16 finalDef = _getFinalStat(characterCurrentStats.def, buffDef);
    uint16 finalAgi = _getFinalStat(characterCurrentStats.agi, buffAgi);

    WeaponInfo memory weaponInfo = WeaponInfo({ advantageType: AdvantageType.Grey, isTwoHanded: false });

    uint256 weaponId = CharEquipment.getEquipmentId(characterId, SlotType.Weapon);
    if (weaponId != 0) {
      uint256 itemId = Equipment.getItemId(weaponId);
      EquipmentInfoData memory equipmentInfo = EquipmentInfo.get(itemId);
      weaponInfo.advantageType = equipmentInfo.advantageType;
      weaponInfo.isTwoHanded = equipmentInfo.twoHanded;
    }

    characterBattleInfo = BattleInfo({
      id: characterId,
      barrier: CharCurrentStats.getBarrier(characterId),
      hp: characterHp,
      atk: finalAtk,
      def: finalDef,
      agi: finalAgi,
      level: CharStats.getLevel(characterId),
      skillIds: characterSkills,
      weaponInfo: weaponInfo
    });
  }

  /// @dev return dmg and hp result after a battle
  function fight(
    BattleInfo memory attacker,
    BattleInfo memory defender,
    bool attackerStunImmune,
    bool defenderStunImmune
  )
    public
    view
    returns (uint32[2] memory hps, uint32[11] memory dmgResult)
  {
    (uint16 attackerDmgMultiplier, uint16 defenderDmgMultiplier) =
      _getDamageMultiplier(attacker.weaponInfo, defender.weaponInfo);
    // bonus attack based on agility
    if (attacker.agi >= defender.agi + Config.BONUS_ATTACK_AGI_DIFF) {
      _handleFirstAttack(attacker, defender, dmgResult, attackerDmgMultiplier);
      if (defender.hp == 0) {
        hps[0] = attacker.hp;
        hps[1] = 0;
        return (hps, dmgResult);
      }
    }
    // main battle loop
    SkillData memory normalAtk = Skill.get(Config.NORMAL_ATTACK_SKILL_ID);
    uint8 index = 1;
    SkillEffectData memory attackerDebuff;
    SkillEffectData memory defenderDebuff;
    TurnFightContext memory turnContext;

    while (index < 11) {
      // first attacker's turn to attack
      if (attacker.hp == 0) break;
      turnContext.normalAtk = normalAtk;
      turnContext.dmgResult = dmgResult;
      turnContext.dmgMultiplier = attackerDmgMultiplier;
      turnContext.dmgIndex = index++;
      turnContext.attackerDebuff = attackerDebuff;
      turnContext.defenderDebuff = defenderDebuff;
      turnContext.attackerStunImmune = attackerStunImmune;
      _doTurnFight(attacker, defender, turnContext);
      dmgResult = turnContext.dmgResult;
      attackerDebuff = turnContext.attackerDebuff;
      defenderDebuff = turnContext.defenderDebuff;

      // second attacker's turn to attack
      if (defender.hp == 0) break;
      turnContext.normalAtk = normalAtk;
      turnContext.dmgResult = dmgResult;
      turnContext.dmgMultiplier = defenderDmgMultiplier;
      turnContext.dmgIndex = index++;
      turnContext.attackerDebuff = defenderDebuff;
      turnContext.defenderDebuff = attackerDebuff;
      turnContext.attackerStunImmune = defenderStunImmune;
      _doTurnFight(defender, attacker, turnContext);
      dmgResult = turnContext.dmgResult;
      defenderDebuff = turnContext.attackerDebuff;
      attackerDebuff = turnContext.defenderDebuff;
    }
    hps[0] = attacker.hp;
    hps[1] = defender.hp;
    return (hps, dmgResult);
  }

  function _doTurnFight(
    BattleInfo memory attacker,
    BattleInfo memory defender,
    TurnFightContext memory turnContext
  )
    private
    view
  {
    if (
      turnContext.attackerDebuff.turns > 0 && turnContext.attackerDebuff.effect == EffectType.Stun
        && !turnContext.attackerStunImmune
    ) {
      turnContext.dmgResult[turnContext.dmgIndex] = 0;
      turnContext.attackerDebuff.turns--;
      return;
    }
    uint16 skillBonus;
    uint256 skillId = turnContext.dmgIndex == 0 ? 0 : attacker.skillIds[(turnContext.dmgIndex - 1) / 2];
    SkillData memory skill = _getSkillData(skillId, turnContext.normalAtk);
    if (skill.hasEffect) {
      SkillEffectData memory skillEffect = SkillEffect.get(skillId);
      turnContext.defenderDebuff.damage = skillEffect.damage;
      turnContext.defenderDebuff.effect = skillEffect.effect;
      turnContext.defenderDebuff.turns = skillEffect.turns;
    }
    if (turnContext.defenderDebuff.turns > 0 && turnContext.defenderDebuff.damage > 0) {
      skillBonus = turnContext.defenderDebuff.damage;
      turnContext.defenderDebuff.turns--;
    }
    uint32 damage = _calculateDamage(
      attacker.level, attacker.atk, defender.def, skill.damage + skillBonus, turnContext.dmgMultiplier
    );
    _applyDamageToDefender(defender, damage);
    turnContext.dmgResult[turnContext.dmgIndex] = damage;
  }

  function _handleFirstAttack(
    BattleInfo memory attacker,
    BattleInfo memory defender,
    uint32[11] memory dmgResult,
    uint16 attackerDmgMultiplier
  )
    private
    view
  {
    SkillData memory normalAtk = Skill.get(Config.NORMAL_ATTACK_SKILL_ID);
    uint16 agiDiff = attacker.agi - defender.agi;
    uint16 bonusDmg = uint16(uint32(agiDiff) * 115 / 100); // 1.15 agiDiff
    normalAtk.damage += bonusDmg;
    uint16 currentDef = defender.def;
    // agi difference will reduce defender's defense for this turn only
    uint16 reducedDef = uint16(uint32(agiDiff) * 25 / 100); // 25% of agiDiff
    defender.def = defender.def > reducedDef ? defender.def - reducedDef : 0;
    uint32 damage =
      _calculateDamage(attacker.level, attacker.atk, defender.def, normalAtk.damage, attackerDmgMultiplier);
    _applyDamageToDefender(defender, damage);
    dmgResult[0] = damage;
    defender.def = currentDef;
  }

  /// @dev calculate damage multiplier (%) based on advantage type
  function _getDamageMultiplier(
    WeaponInfo memory weaponInfo1,
    WeaponInfo memory weaponInfo2
  )
    private
    pure
    returns (uint16, uint16)
  {
    uint16 m1 = 100;
    uint16 m2 = 100;

    // grey cancels advantage
    if (weaponInfo1.advantageType == AdvantageType.Grey || weaponInfo2.advantageType == AdvantageType.Grey) {
      return (m1, m2);
    }

    AdvantageType t1 = weaponInfo1.advantageType;
    AdvantageType t2 = weaponInfo2.advantageType;

    bool w1Upper = (t1 == AdvantageType.Red && t2 == AdvantageType.Green)
      || (t1 == AdvantageType.Green && t2 == AdvantageType.Blue) || (t1 == AdvantageType.Blue && t2 == AdvantageType.Red);

    bool w2Upper = (t2 == AdvantageType.Red && t1 == AdvantageType.Green)
      || (t2 == AdvantageType.Green && t1 == AdvantageType.Blue) || (t2 == AdvantageType.Blue && t1 == AdvantageType.Red);

    if (!w1Upper && !w2Upper) {
      return (m1, m2);
    }

    bool isTwoHanded = w1Upper ? weaponInfo1.isTwoHanded : weaponInfo2.isTwoHanded;

    uint16 advantageValue =
      isTwoHanded ? Config.TWO_HAND_ADVANTAGE_TYPE_DAMAGE_MODIFIER : Config.ONE_HAND_ADVANTAGE_TYPE_DAMAGE_MODIFIER;

    if (w1Upper) {
      m1 += advantageValue;
      m2 -= advantageValue;
    } else {
      m1 -= advantageValue;
      m2 += advantageValue;
    }

    return (m1, m2);
  }

  /// @dev calculate damage with skill multiplier, skillDmg is percent of atk dmg
  function _calculateDamage(
    uint16 level,
    uint16 atk,
    uint16 def,
    uint16 skillDmg,
    uint16 dmgMultiplier
  )
    private
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
  function _applyDamageToDefender(BattleInfo memory defender, uint32 damage) private pure {
    if (defender.barrier >= damage) {
      defender.barrier -= damage;
    } else {
      damage -= defender.barrier; // subtract the barrier from damage
      defender.barrier = 0; // set barrier to 0
      defender.hp = defender.hp > damage ? defender.hp - damage : 0;
    }
  }

  /// @dev return skill data based on skillId
  function _getSkillData(uint256 skillId, SkillData memory normalAtk) private view returns (SkillData memory skill) {
    skill = skillId == Config.NORMAL_ATTACK_SKILL_ID ? normalAtk : Skill.get(skillId);
    return skill;
  }

  function _getFinalStat(uint16 baseStat, int16 buffStat) private pure returns (uint16) {
    if (buffStat < 0) {
      uint16 absBuff = uint16(-buffStat);
      return baseStat > absBuff ? baseStat - absBuff : 0;
    } else {
      return baseStat + uint16(buffStat);
    }
  }
}
