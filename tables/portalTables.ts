const PORTAL_TABLES: any = {
  SellCrystalCounter: {
    schema: {
      count: "uint256",
    },
    key: [],
  },
  SellCrystalReq: {
    schema: {
      characterId: "uint256",
      id: "uint256",
      amount: "uint32",
      isDone: "bool",
      requestedAt: "uint256",
    },
    key: ['characterId', 'id'],
  },
}

export default PORTAL_TABLES;
