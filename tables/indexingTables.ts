const INDEXING_TABLES: any = {
  IvToolIndex: { // Inventory Tool Index
    schema: {
      characterId: "uint256",
      toolId: "uint256",
      index: "uint256",
    },
    key: ['characterId', 'toolId'],
  },

  IvEquipmentIndex: { // Inventory Equipment Index
    schema: {
      characterId: "uint256",
      equipmentId: "uint256",
      index: "uint256",
    },
    key: ['characterId', 'equipmentId'],
  },

  StToolIndex: { // Storage Tool Index
    schema: {
      characterId: "uint256",
      cityId: "uint256",
      toolId: "uint256",
      index: "uint256",
    },
    key: ['characterId', 'cityId', 'toolId'],
  },

  StEquipmentIndex: { // Storage Equipment Index
    schema: {
      characterId: "uint256",
      cityId: "uint256",
      equipmentId: "uint256",
      index: "uint256",
    },
    key: ['characterId', 'cityId', 'equipmentId'],
  },

  MonsterLocIndex: { // Monster Location Index
    schema: {
      x: "int32",
      y: "int32",
      monsterId: "uint256",
      index: "uint256",
    },
    key: ['x', 'y', 'monsterId'],
  },

  TileOItemIndex: { // Tile Other Item Index
    schema: {
      x: "int32",
      y: "int32",
      itemId: "uint256",
      index: "uint256",
    },
    key: ['x', 'y', 'itemId'],
  },

  TileEqIndex: { // Tile Equipment Index
    schema: {
      x: "int32",
      y: "int32",
      equipmentId: "uint256",
      index: "uint256",
    },
    key: ['x', 'y', 'equipmentId'],
  },

  GuildMemberIndex: { // Guild Member Index
    schema: {
      guildId: "uint256",
      memberId: "uint256",
      index: "uint256",
    },
    key: ['guildId', 'memberId'],
  },
};

export default INDEXING_TABLES;
