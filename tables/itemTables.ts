const ITEM_TABLES: any = {
  ItemV2: {
    schema: {
      id: "uint256",
      category: "ItemCategoryType",
      itemType: "ItemType",
      weight: "uint32",
      tier: "uint8",
      isUntradeable: "bool",
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
  EquipmentInfo2V2: {
    schema: {
      itemId: "uint256",
      maxLevel: "uint8",
      counter: "uint8",
      dmgPercent: "uint16",
      bonusWeight: "uint32",
      shieldBarrier: "uint32",
    },
    key: ['itemId'],
  },
  CardInfo: {
    schema: {
      itemId: "uint256",
      top: "uint16",
      left: "uint16",
      right: "uint16",
      bottom: "uint16",
    },
    key: ['itemId'],
  },
  BuffItemInfoV3: {
    schema: {
      itemId: "uint256",
      range: "uint16", // range to cast in tile units
      duration: "uint32", // in seconds
      numTarget: "uint8",
      selfCastOnly: "bool",
      buffType: "BuffType",
      isBuff: "bool",
    },
    key: ['itemId'],
  },
  BuffStatV3: {
    schema: {
      itemId: "uint256",
      atkPercent: "int16", 
      defPercent: "int16", 
      agiPercent: "int16",
      sp: "int8", // flat, modify the max sp
      ms: "int8", // flat, modify the movement speed
      dmg: "uint32",
      isAbsDmg: "bool",
    },
    key: ['itemId'],
  },
  BuffExp: {
    schema: {
      itemId: "uint256",
      farmingPerkAmp: "uint16", // these values are percentages, e.g., 200 means 2x
      pveExpAmp: "uint16",
      pvePerkAmp: "uint16",
    },
    key: ['itemId'],
  },
  BuffDmg: {
    schema: {
      itemId: "uint256",
      dmg: "uint32",
      isAbsDmg: "bool",
    },
    key: ['itemId'],
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
  Equipment2: {
    schema: {
      id: "uint256",
      authorId: "uint256", // the original creator of the equipment
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
  CollectionExcV2: {
    schema: {
      itemId: "uint256",
      inputItemIds: "uint256[]",
      inputItemAmounts: "uint32[]",
    },
    key: ['itemId',],
  },
  EquipmentPet: { // Mapping from equipmentId to petId
    schema: {
      equipmentId: "uint256",
      petId: "uint256",
    },
    key: ['equipmentId'],
  },
};

export default ITEM_TABLES;
