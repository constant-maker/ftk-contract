const CRAFT_TABLES: any = {
  ItemRecipe: {
    schema: {
      itemId: "uint256",
      goldCost: "uint32",
      itemIds: "uint256[]",
      amounts: "uint32[]",
    },
    key: ['itemId'],
  },
};

export default CRAFT_TABLES;
