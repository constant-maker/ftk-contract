const KINGDOM_TABLES: any = {
  Population: {
    schema: {
      kingdomId: "uint8",
      population: "uint32",
    },
    key: ['kingdomId'],
  },
  Kingdom: {
    schema: {
      id: "uint8",
      capitalId: "uint256",
      name: "string",
    },
    key: ['id'],
  },
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
  CityVault2: {
    schema: {
      cityId: "uint256",
      gold: "uint256", // Normally it should be uint32, but we want to support more gold in vault, so use uint256 here
      crystal: "uint256",
    },
    key: ['cityId'],
  },
  CVaultHistory: {
    schema: {
      cityId: "uint256",
      id: "uint256",
      characterId: "uint256",
      gold: "uint32",
      crystal: "uint256",
      timestamp: "uint256",
      isContributed: "bool",
      itemIds: "uint256[]",
      amounts: "uint32[]",
    },
    key: ['cityId', 'id'],
  },
  CharVaultWithdraw: {
    schema: {
      characterId: "uint256",
      weightQuota: "uint32",
      markTimestamp: "uint256",
    },
    key: ['characterId'],
  },
  VaultRestriction: { // Restrict withdraw by kingdom
    schema: {
      kingdomId: "uint8",
      itemId: "uint256",
      isRestricted: "bool",
    },
    key: ['kingdomId', 'itemId'],
  },
  HistoryCounter: {
    schema: {
      cityId: "uint256",
      counter: "uint256",
    },
    key: ['cityId'],
  },
  RestrictLoc: {
    schema: {
      x: "int32",
      y: "int32",
      cityId: "uint256",
      isRestricted: "bool",
    },
    key: ['x', 'y'],
  },
  CityCounter: {
    schema: {
      counter: "uint256",
    },
    key: [],
  },
  KingdomCityCounter: {
    schema: {
      kingdomId: "uint8",
      counter: "uint256",
    },
    key: ['kingdomId'],
  },
  CResourceRequire: { // City Resource Requirement
    schema: {
      level: "uint8",
      resourceIds: "uint256[]",
      amounts: "uint32[]",
    },
    key: ['level'],
  },
  CityMoveHistory: {
    schema: {
      cityId: "uint256",
      oldPositionX: "int32",
      oldPositionY: "int32",
      moveTimestamp: "uint256",
    },
    key: ['cityId'],
  },
};

export default KINGDOM_TABLES;
