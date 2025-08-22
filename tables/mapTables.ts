const MAP_TABLES: any = {
  Kingdom: {
    schema: {
      id: "uint8",
      capitalId: "uint256",
      name: "string",
    },
    key: ['id'],
  },
  // KingdomV2: {
  //   schema: {
  //     id: "uint8",
  //     capitalId: "uint256",
  //     level: "uint8",
  //     numCityToBuild: "uint8",
  //     name: "string",
  //   },
  //   key: ['id'],
  // },
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
  TileInventory: {
    schema: {
      x: "int32",
      y: "int32",
      lastDropTime: "uint256",
      equipmentIds: "uint256[]",
      toolIds: "uint256[]",
      otherItemIds: "uint256[]",
      otherItemAmounts: "uint32[]",
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
  AllianceV2: {
    schema: {
      kingdomA: "uint8",
      kingdomB: "uint8",
      isAlliance: "bool",
      isApproved: "bool",
    },
    key: ['kingdomA', 'kingdomB'],
  },
};

export default MAP_TABLES;
