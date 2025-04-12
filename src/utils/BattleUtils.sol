pragma solidity >=0.8.24;

import {
  SkillV2,
  SkillV2Data,
  Monster,
  MonsterStats,
  MonsterStatsData,
  MonsterLocationData,
  CharStats,
  CharCurrentStats,
  CharCurrentStatsData,
  CharSkill,
  CharEquipment,
  BossInfo,
  BossInfoData,
  SkillEffect,
  SkillEffectData
} from "@codegen/index.sol";
import { PvE } from "@codegen/tables/PvE.sol";
import { AdvantageType, SlotType, EffectType } from "@codegen/common.sol";
import { Config } from "@common/Config.sol";
import { Errors } from "@common/Errors.sol";
import { CharacterEquipmentUtils } from "./CharacterEquipmentUtils.sol";

struct BattleInfo {
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
  uint8 public constant BERSERK_SP_BONUS = 5;

  /// @dev Return list of valid skills based on character SP.
  function getCharacterSkillIds(uint256 characterId) public view returns (uint256[5] memory skillIds) {
    uint8 characterSp = CharStats.getSp(characterId);
    uint256[5] memory characterSkillIds = CharSkill.getSkillIds(characterId);

    return reBuildSkills(characterSkillIds, characterSp);
  }

  function getMonsterSkillIds(uint256 monsterId, uint8 monsterSp) public view returns (uint256[5] memory skillIds) {
    uint256[5] memory monsterSkillIds = Monster.getSkillIds(monsterId);

    return reBuildSkills(monsterSkillIds, monsterSp);
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

  /// @dev build monster BattleInfo
  function buildMonsterBattleInfo(
    uint256 monsterId,
    int32 x,
    int32 y,
    MonsterLocationData memory monsterLocation
  )
    public
    view
    returns (BattleInfo memory monsterBattleInfo)
  {
    MonsterStatsData memory monsterStats = MonsterStats.get(monsterId);
    uint8 monsterSp = monsterStats.sp;
    if (!Monster.getIsBoss(monsterId)) {
      grewMonsterStats(monsterId, monsterStats, monsterLocation.level);
    } else {
      BossInfoData memory bossInfo = BossInfo.get(monsterId, x, y);
      monsterBattleInfo.barrier = bossInfo.barrier; // set barrier
      if (bossInfo.hp <= monsterStats.hp * bossInfo.berserkHpThreshold / 100) {
        uint16 multiplier = 100 + bossInfo.boostPercent;
        monsterStats.atk = monsterStats.atk * multiplier / 100;
        monsterStats.def = monsterStats.def * multiplier / 100;
        monsterStats.agi = monsterStats.agi * multiplier / 100;
        monsterSp += BERSERK_SP_BONUS;
      }
      monsterStats.hp = bossInfo.hp; // use current boss hp
    }
    monsterBattleInfo.hp = monsterStats.hp;
    monsterBattleInfo.atk = monsterStats.atk;
    monsterBattleInfo.def = monsterStats.def;
    monsterBattleInfo.agi = monsterStats.agi;
    monsterBattleInfo.level = monsterLocation.level;
    monsterBattleInfo.advantageType = monsterLocation.advantageType;
    monsterBattleInfo.skillIds = getMonsterSkillIds(monsterId, monsterSp);

    return monsterBattleInfo;
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
    CharCurrentStatsData memory characterCurrentStats = CharCurrentStats.get(characterId);
    characterBattleInfo = BattleInfo({
      barrier: 0,
      hp: characterHp,
      agi: characterCurrentStats.agi,
      atk: characterCurrentStats.atk,
      def: characterCurrentStats.def,
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
    // normal attack
    SkillV2Data memory normalAtk = SkillV2.get(Config.NORMAL_ATTACK_SKILL_ID);
    // bonus attack based on agility
    if (attacker.agi >= defender.agi + Config.BONUS_ATTACK_AGI_DIFF) {
      handleFirstAttack(attacker, defender, normalAtk, dmgResult, attackerDmgMultiplier);
      if (defender.hp == 0) {
        hps[0] = attacker.hp;
        hps[1] = 0;
        return (hps, dmgResult);
      }
    }
    // main battle loop
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
    if (attackerDebuff.turns > 0 && attackerDebuff.effect == EffectType.Stun) {
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
    SkillV2Data memory normalAtk,
    uint32[11] memory dmgResult,
    uint16 attackerDmgMultiplier
  )
    public
    view
  {
    SkillEffectData memory debuff;
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
    rawDmg = Config.BASE_DMG + level;
    if (atk > def) {
      rawDmg += atk - def;
    }
    rawDmg = (rawDmg * skillDmg * dmgMultiplier) / 10_000; // (rawDmg * skillDmg / 100) * dmgMultiplier / 100;
    return rawDmg;
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

  function grewMonsterStats(uint256 monsterId, MonsterStatsData memory monsterStats, uint16 level) public view {
    uint8 grow = Monster.getGrow(monsterId);
    uint16 multiplier = (100 + (level - 1) * grow);
    monsterStats.hp = monsterStats.hp * multiplier / 100;
    monsterStats.atk = monsterStats.atk * multiplier / 100;
    monsterStats.def = monsterStats.def * multiplier / 100;
    monsterStats.agi = monsterStats.agi * multiplier / 100;
  }

  function getRewardItem(
    uint256 characterId,
    uint256 monsterId
  )
    public
    view
    returns (uint256 itemId, uint32 itemAmount)
  {
    uint256[] memory itemIds = Monster.getItemIds(monsterId);
    uint32[] memory itemAmounts = Monster.getItemAmounts(monsterId);
    if (itemIds.length == 0) {
      return (0, 0);
    }
    if (itemIds.length != itemAmounts.length) {
      revert Errors.Monster_InvalidResourceData(monsterId, itemIds.length, itemAmounts.length);
    }
    uint256 index;
    if (itemIds.length > 1) {
      index = PvE.getCounter(characterId) % itemIds.length;
    }
    return (itemIds[index], itemAmounts[index]);
  }

  function getCharacterEquipments(uint256 characterId) public view returns (uint256[6] memory equipmentIds) {
    equipmentIds[0] = CharEquipment.getEquipmentId(characterId, SlotType.Weapon);
    equipmentIds[1] = CharEquipment.getEquipmentId(characterId, SlotType.SubWeapon);
    equipmentIds[2] = CharEquipment.getEquipmentId(characterId, SlotType.Headgear);
    equipmentIds[3] = CharEquipment.getEquipmentId(characterId, SlotType.Armor);
    equipmentIds[4] = CharEquipment.getEquipmentId(characterId, SlotType.Footwear);
    equipmentIds[5] = CharEquipment.getEquipmentId(characterId, SlotType.Mount);
    return equipmentIds;
  }
}
