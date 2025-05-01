const ITEM_TABLES: any = {
  Item: {
    schema: {
      id: "uint256",
      category: "ItemCategoryType",
      itemType: "ItemType",
      weight: "uint32",
      tier: "uint8",
      name: "string",
    },
    key: ['id'],
  },
  ResourceInfo: {
    schema: {
      itemId: "uint256",
      resourceType: "ResourceType",
    },
    key: ['itemId'],
  },
  EquipmentInfo: {
    schema: {
      itemId: "uint256",
      slotType: "SlotType",
      advantageType: "AdvantageType",
      twoHanded: "bool",
      hp: "uint32",
      atk: "uint16",
      def: "uint16",
      agi: "uint16",
      ms: "uint16",
    },
    key: ['itemId'],
  },
  EquipmentInfoV2: {
    schema: {
      itemId: "uint256",
      slotType: "SlotType",
      advantageType: "AdvantageType",
      twoHanded: "bool",
      hp: "int32",
      atk: "int16",
      def: "int16",
      agi: "int16",
      ms: "int16",
    },
    key: ['itemId'],
  },
  EquipmentInfo2: { // Upgradable equipment
    schema: {
      itemId: "uint256",
      dmgPercent: "uint16",
      maxLevel: "uint8",
      counter: "uint8",
    },
    key: ['itemId'],
  },
  EquipmentInfo3: { // Mount
    schema: {
      itemId: "uint256",
      bonusWeight: "uint32"
    },
    key: ['itemId'],
  },
  Tool: {
    schema: {
      id: "uint256",
      itemId: "uint256",
      characterId: "uint256",
      durability: "uint8",
    },
    key: ['id'],
  },
  Tool2: {
    schema: {
      id: "uint256",
      itemId: "uint256",
      characterId: "uint256",
      durability: "uint16",
    },
    key: ['id'],
  },
  ToolSupply: {
    schema: {
      totalSupply: "uint256",
    },
    key: [],
  },
  Equipment: {
    schema: {
      id: "uint256",
      itemId: "uint256",
      characterId: "uint256",
      level: "uint8",
      counter: "uint8",
    },
    key: ['id'],
  },
  EquipmentSupply: {
    schema: {
      totalSupply: "uint256",
    },
    key: [],
  },
  ItemWeightCache: {
    schema: {
      itemId: "uint256",
      weight: "uint32", // Old weight
    },
    key: ['itemId'],
  },
};

export default ITEM_TABLES;
