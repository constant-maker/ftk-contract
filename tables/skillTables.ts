const SKILL_TABLES: any = {
  Skill: {
    schema: {
      id: "uint256",
      sp: "uint8",
      tier: "uint8",
      damage: "uint16",
      name: "string",
    },
    key: ['id'],
  },
};

export default SKILL_TABLES;
