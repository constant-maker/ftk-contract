const INDEXING_TABLES: any = {
  InventoryToolIndex: {
    schema: {
      characterId: "uint256",
      toolId: "uint256",
      index: "uint256",
    },
    key: ['characterId', 'toolId'],
  },

  InventoryEquipmentIndex: {
    schema: {
      characterId: "uint256",
      equipmentId: "uint256",
      index: "uint256",
    },
    key: ['characterId', 'equipmentId'],
  },

  StorageToolIndex: {
    schema: {
      characterId: "uint256",
      cityId: "uint256",
      toolId: "uint256",
      index: "uint256",
    },
    key: ['characterId', 'cityId', 'toolId'],
  },

  StorageEquipmentIndex: {
    schema: {
      characterId: "uint256",
      cityId: "uint256",
      equipmentId: "uint256",
      index: "uint256",
    },
    key: ['characterId', 'cityId', 'equipmentId'],
  },

  MonsterIndexLocation: {
    schema: {
      x: "int32",
      y: "int32",
      monsterId: "uint256",
      index: "uint256",
    },
    key: ['x', 'y', 'monsterId'],
  },

  TileOtherItemIndex: {
    schema: {
      x: "int32",
      y: "int32",
      itemId: "uint256",
      index: "uint256",
    },
    key: ['x', 'y', 'itemId'],
  },

  TileEquipmentIndex: {
    schema: {
      x: "int32",
      y: "int32",
      equipmentId: "uint256",
      index: "uint256",
    },
    key: ['x', 'y', 'equipmentId'],
  },
};

export default INDEXING_TABLES;
