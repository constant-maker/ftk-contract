const SKILL_TABLES: any = {
  Skill: {
    schema: {
      id: "uint256",
      sp: "uint8",
      tier: "uint8",
      damage: "uint16",
      perkItemType: "ItemType",
      requiredPerkLevel: "uint8",
      hasEffect: "bool",
      name: "string",
    },
    key: ['id'],
  },
  SkillEffect: {
    schema: {
      id: "uint256",
      effect: "EffectType",
      damage: "uint16", // percent of current attack dmg
      turns: "uint8" // duration of effect
    },
    key: ['id'],
  },
};

export default SKILL_TABLES;
