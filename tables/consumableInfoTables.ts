const CONSUMABLE_INFO_TABLES: any = {
  HealingItemInfo: {
    schema: {
      itemId: "uint256",
      hpRestore: "uint32",
    },
    key: ['itemId'],
  },
  StatModifierItemInfo: {
    schema: {
      itemId: "uint256",
      duration: "uint16",
      atkPercent: "int16",
      defPercent: "int16",
      agiPercent: "int16",
      ms: "int16",
    },
    key: ['itemId'],
  },
};

export default CONSUMABLE_INFO_TABLES;
