const MAP_TABLES: any = {
  City: {
    schema: {
      id: "uint256",
      x: "int32",
      y: "int32",
      isCapital: "bool",
      kingdomId: "uint8",
      level: "uint8",
      name: "string",
    },
    key: ['id'],
  },
  CityVault: {
    schema: {
      cityId: "uint256",
      itemId: "uint256",
      amount: "uint32",
    },
    key: ['cityId', 'itemId'],
  },
  Kingdom: {
    schema: {
      id: "uint8",
      capitalId: "uint256",
      name: "string",
    },
    key: ['id'],
  },
  Npc: {
    schema: {
      id: "uint256",
      cityId: "uint256",
      x: "int32",
      y: "int32",
      name: "string",
    },
    key: ['id'],
  },
  // TileInfo: {
  //   schema: {
  //     kingdomId: "uint8",
  //     x: "int32",
  //     y: "int32",
  //     farmSlot: "uint8",
  //     zoneType: "ZoneType",
  //     terrainType: "TerrainType",
  //     itemIds: "uint256[]",
  //     monsterIds: "uint256[]",
  //   },
  //   key: ['x', 'y'],
  // },
  // TileInfo2: {
  //   schema: {
  //     x: "int32",
  //     y: "int32",
  //     kingdomId: "uint8",
  //     farmSlot: "uint8",
  //     zoneType: "ZoneType",
  //     terrainType: "TerrainType",
  //     replenishTime: "uint256",
  //     itemIds: "uint256[]",
  //     farmingQuotas: "uint16[]",
  //     monsterIds: "uint256[]",
  //   },
  //   key: ['x', 'y'],
  // },
  TileInfo3: {
    schema: {
      x: "int32",
      y: "int32",
      kingdomId: "uint8",
      farmSlot: "uint8",
      zoneType: "ZoneType",
      occupiedTime: "uint256",
      replenishTime: "uint256",
      itemIds: "uint256[]",
      farmingQuotas: "uint16[]",
      monsterIds: "uint256[]",
    },
    key: ['x', 'y'],
  },
  NpcShop: {
    schema: {
      cityId: "uint256",
      gold: "uint32",
    },
    key: ['cityId'],
  },
  NpcShopInventory: {
    schema: {
      cityId: "uint256",
      itemId: "uint256",
      cId: "uint256", // cityId, this value is used to get data
      amount: "uint32",
    },
    key: ['cityId', 'itemId'],
  },
  Alliance: {
    schema: {
      kingdomA: "uint8",
      kingdomB: "uint8",
      isAlliance: "bool",
    },
    key: ['kingdomA', 'kingdomB'],
  },
};

export default MAP_TABLES;
