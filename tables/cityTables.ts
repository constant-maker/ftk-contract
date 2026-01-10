const CITY_TABLES: any = {
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
      gold: "uint32",
    },
    key: ['cityId'],
  },
  // CVaultHistory: {
  //   schema: {
  //     cityId: "uint256",
  //     id: "uint256",
  //     characterId: "uint256",
  //     itemId: "uint256",
  //     amount: "uint32",
  //     timestamp: "uint256",
  //     isContributed: "bool",
  //   },
  //   key: ['cityId', 'id'],
  // },
  // CVaultHistoryV2: {
  //   schema: {
  //     cityId: "uint256",
  //     id: "uint256",
  //     characterId: "uint256",
  //     itemId: "uint256",
  //     amount: "uint32",
  //     gold: "uint32",
  //     timestamp: "uint256",
  //     isContributed: "bool",
  //   },
  //   key: ['cityId', 'id'],
  // },
  CVaultHistoryV3: {
    schema: {
      cityId: "uint256",
      id: "uint256",
      characterId: "uint256",
      gold: "uint32",
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
  WithdrawRestriction: {
    schema: {
      itemId: "uint256",
      isRestricted: "bool",
    },
    key: ['itemId'],
  },
  HistoryCounter: {
    schema: {
      cityId: "uint256",
      counter: "uint256",
    },
    key: ['cityId'],
  },
  RestrictLocation: {
    schema: {
      x: "int32",
      y: "int32",
      isRestricted: "bool",
    },
    key: ['x', 'y'],
  },
  RestrictLocV2: {
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
  CResourceRequire: {
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

export default CITY_TABLES;
