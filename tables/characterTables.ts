import { X } from "@latticexyz/store/dist/store-CDoWdOke";

const CHARACTER_TABLES: any = {
  ActiveChar: {
    schema: {
      characterId: "uint256",
      wallet: "address",
      sessionWallet: "address",
      createdTime: "uint256",
    },
    key: ['characterId'],
  },
  CharSupply: {
    schema: {
      totalSupply: "uint256",
    },
    key: [],
  },
  CharName: {
    schema: {
      nameHash: "bytes32",
      owner: "uint256",
    },
    key: ['nameHash'],
  },
  CharInfo: {
    schema: {
      characterId: "uint256",
      kingdomId: "uint8",
      characterType: "CharacterType",
      traits: "uint16[3]",
      name: "string",
    },
    key: ['characterId'],
  },
  CharStats: {
    schema: {
      characterId: "uint256",
      weight: "uint32", // max weight
      hp: "uint32", // max hp
      level: "uint16",
      statPoint: "uint16",
      sp: "uint8",
    },
    key: ['characterId'],
  },
  CharStats2: {
    schema: {
      characterId: "uint256",
      fame: "uint32",
    },
    key: ['characterId'],
  },
  CharCurrentStats: {
    schema: {
      characterId: "uint256",
      exp: "uint32",
      weight: "uint32",
      hp: "uint32",
      atk: "uint16",
      def: "uint16",
      agi: "uint16",
      ms: "uint16",
    },
    key: ['characterId'],
  },
  CharCStats2: { // Character Current Stats 2
    schema: {
      characterId: "uint256",
      barrier: "uint32", // shield barrier
    },
    key: ['characterId'],
  },
  CharBaseStats: {
    schema: {
      characterId: "uint256",
      atk: "uint16",
      def: "uint16",
      agi: "uint16",
    },
    key: ['characterId'],
  },
  CharPerk: {
    schema: {
      characterId: "uint256",
      itemType: "ItemType",
      exp: "uint32",
      level: "uint8",
    },
    key: ['characterId', 'itemType'],
  },
  CharEquipment: {
    schema: {
      characterId: "uint256",
      slotType: "SlotType",
      equipmentId: "uint256",
    },
    key: ['characterId', 'slotType'],
  },
  CharGrindSlot: { // for equipment only, default is weapon
    schema: {
      characterId: "uint256",
      slotType: "SlotType",
    },
    key: ['characterId'],
  },
  CharInventory: {
    schema: {
      characterId: "uint256",
      toolIds: "uint256[]",
      equipmentIds: "uint256[]",
    },
    key: ['characterId'],
  },
  CharOtherItem: { // This stores the inventory for standard items that don't have unique properties.
    schema: {
      characterId: "uint256",
      itemId: "uint256",
      charId: "uint256", // help to query data
      amount: "uint32",
    },
    key: ['characterId', 'itemId'],
  },
  CharState: {
    schema: {
      characterId: "uint256",
      state: "CharacterStateType",
      lastUpdated: "uint256",
    },
    key: ['characterId'],
  },
  CharPosition: {
    schema: {
      characterId: "uint256",
      x: "int32",
      y: "int32",
    },
    key: ['characterId'],
  },
  CharNextPosition: {
    schema: {
      characterId: "uint256",
      x: "int32",
      y: "int32",
      arriveTimestamp: "uint256",
    },
    key: ['characterId'],
  },
  CharFarmingState: {
    schema: {
      characterId: "uint256",
      itemId: "uint256", // item with type resource
      toolId: "uint256",
      itemType: "ItemType",
    },
    key: ['characterId'],
  },
  CharSkill: {
    schema: {
      characterId: "uint256",
      skillIds: "uint256[5]",
    },
    key: ['characterId'],
  },
  CharFund: {
    schema: {
      characterId: "uint256",
      gold: "uint32",
      crystal: "uint32",
    },
    key: ['characterId'],
  },
  CharStorage: {
    schema: {
      characterId: "uint256",
      cityId: "uint256",
      maxWeight: "uint32",
      weight: "uint32",
      toolIds: "uint256[]",
      equipmentIds: "uint256[]",
    },
    key: ['characterId', 'cityId'],
  },
  CharOtherItemStorage: { // This stores the storage for standard items that don't have unique properties.
    schema: {
      characterId: "uint256",
      cityId: "uint256",
      itemId: "uint256",
      charId: "uint256", // help to query data
      amount: "uint32",
    },
    key: ['characterId', 'cityId', 'itemId'],
  },
  CharEquipStats: { // Cached data for equipment stats
    schema: {
      characterId: "uint256",
      slotType: "SlotType",
      hp: "uint32",
      atk: "uint16",
      def: "uint16",
      agi: "uint16",
      ms: "uint16",
    },
    key: ['characterId', 'slotType'],
  },
  CharEquipStats2: { // Cached data for equipment stats 2
    schema: {
      characterId: "uint256",
      slotType: "SlotType",
      barrier: "uint32",
      weight: "uint32", // bonus weight
    },
    key: ['characterId', 'slotType'],
  },
  CharReborn: {
    schema: {
      characterId: "uint256",
      num: "uint16",
    },
    key: ['characterId'],
  },
  CharMigration: {
    schema: {
      characterId: "uint256",
      equipmentId: "uint256",
      isMigrate: "bool",
    },
    key: ['characterId', 'equipmentId'],
  },
  CharStorageMigration: {
    schema: {
      characterId: "uint256",
      equipmentId: "uint256",
      isMigrate: "bool",
    },
    key: ['characterId', 'equipmentId'],
  },
  CharSavePoint: {
    schema: {
      characterId: "uint256",
      cityId: "uint256",
      x: "int32",
      y: "int32",
    },
    key: ['characterId'],
  },
};

export default CHARACTER_TABLES;
