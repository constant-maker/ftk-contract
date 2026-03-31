const MAP_TABLES: any = {
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
  Tile: {
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
      amount: "uint32",
    },
    key: ['cityId', 'itemId'],
  },
  NonOccupyTile: {
    schema: {
      x: "int32",
      y: "int32",
      value: "bool",
    },
    key: ['x', 'y'],
  },
  TileOccupation: { // Count the tile occupied by each kingdom
    schema: {
      kingdomId: "uint8",
      counter: "uint32",
    },
    key: ['kingdomId'],
  }
};

export default MAP_TABLES;
