import { count } from "console";

const STATUS_TABLES: any = {
  CharDebuff: { // deprecated, use CharBuff instead
    schema: {
      characterId: "uint256",
      debuffIds: "uint256[2]",
      expireTimes: "uint256[2]",
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