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
  CVaultHistoryV2: {
    schema: {
      cityId: "uint256",
      id: "uint256",
      characterId: "uint256",
      itemId: "uint256",
      amount: "uint32",
      gold: "uint32",
      timestamp: "uint256",
      isContributed: "bool",
    },
    key: ['cityId', 'id'],
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
  }
};

export default CITY_TABLES;
