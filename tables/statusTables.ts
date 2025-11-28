import { count } from "console";

const STATUS_TABLES: any = {
  CharDebuff: {
    schema: {
      characterId: "uint256",
      debuffIds: "uint256[2]", // debuff item ids
      expireTimes: "uint256[2]",
    },
    key: ['characterId'],
  },
  CharDebuff2: {
    schema: {
      characterId: "uint256",
      lastCastTime: "uint256",
    },
    key: ['characterId'],
  },
  CharBuff: {
    schema: {
      characterId: "uint256",
      buffIds: "uint256[2]", // buff item ids
      expireTimes: "uint256[2]",
    },
    key: ['characterId'],
  },
  CharBuffCounter: { // count the number of buff item in inventory
    schema: {
      characterId: "uint256",
      buffType: "BuffType",
      count: "uint32",
    },
    key: ['characterId', 'buffType'],
  },
}

export default STATUS_TABLES;