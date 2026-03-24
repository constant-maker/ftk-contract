const SKILL_TABLES: any = {
  Skill: {
    schema: {
      id: "uint256",
      sp: "uint8",
      damage: "uint16",
      hasEffect: "bool",
      name: "string",
      perkItemTypes: "uint8[]",
      requiredPerkLevels: "uint8[]",
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
