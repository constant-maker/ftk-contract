const CRAFT_TABLES: any = {
  ItemRecipeV2: {
    schema: {
      itemId: "uint256",
      goldCost: "uint32",
      perkTypes: "uint8[]", // require perk
      requiredPerkLevels: "uint8[]",
      itemIds: "uint256[]",
      amounts: "uint32[]",
    },
    key: ['itemId'],
  },
};

export default CRAFT_TABLES;
