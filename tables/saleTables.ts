const SALE_TABLES: any = {
  SalePackage: {
    schema: {
      id: "uint256",
      crystalPrice: "uint32", // price in crystals
      gold: "uint32",
      achievementIds: "uint256[]",
      itemIds: "uint256[]", // bonus items included in the package
      itemAmounts: "uint32[]",
    },
    key: ['id'],
  },
}

export default SALE_TABLES;