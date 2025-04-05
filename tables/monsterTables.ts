const MONSTER_TABLES: any = {
  Monster: {
    schema: {
      id: "uint256",
      grow: "uint8",
      exp: "uint32",
      perkExp: "uint32",
      isBoss: "bool",
      name: "string",
      skillIds: "uint256[5]",
      itemIds: "uint256[]",
      itemAmounts: "uint32[]",
    },
    key: ['id'],
  },
  MonsterStats: {
    schema: {
      monsterId: "uint256",
      hp: "uint32",
      atk: "uint16",
      def: "uint16",
      agi: "uint16",
      sp: "uint8",
    },
    key: ['monsterId'],
  },
  BossInfo: {
    schema: {
      monsterId: "uint256",
      x: "int32",
      y: "int32",
      barrier: "uint32",
      hp: "uint32", // current boss hp
      crystal: "uint32", // reward crystal
      respawnDuration: "uint16", // unit days
      berserkHpThreshold: "uint8",
      boostPercent: "uint8", // percent
      lastDefeatedTime: "uint256"
    },
    key: ['monsterId', 'x', 'y'],
  },
  MonsterLocation: {
    schema: {
      x: "int32",
      y: "int32",
      monsterId: "uint256",
      level: "uint16",
      advantageType: "AdvantageType",
    },
    key: ['x', 'y', 'monsterId'],
  },
};

export default MONSTER_TABLES;
