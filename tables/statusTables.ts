import exp from "constants";

const STATUS_TABLES: any = {
  CharDebuff: {
    schema: {
      characterId: "uint256",
      debuffIds: "uint256[2]",
      expiredTimes: "uint256[2]",
    },
    key: ['characterId'],
  },
  Buff: {
    schema: {
      id: "uint256",
      buffType: "BuffType",
    },
    key: ['id'],
  },
  StatBuff: {
    schema: {
      id: "uint256",
      atk: "uint8", // percent, reduce the attack
      def: "uint8", // percent, reduce the defense
      agi: "uint8", // percent, reduce the agility
      movement: "uint16", // additional time to move (seconds)
      isGained: "bool",
      duration: "uint32", // duration in seconds
    },
    key: ['id'],
  },
  ExpBuff: {
    schema: {
      id: "uint256",
      farmingPerkAmp: "uint16",
      pveExpAmp: "uint16", // these values are percentages, e.g., 200 means 2x
      pvePerkAmp: "uint16",
      duration: "uint32", // duration in seconds
    },
    key: ['id'],
  },
}

export default STATUS_TABLES;