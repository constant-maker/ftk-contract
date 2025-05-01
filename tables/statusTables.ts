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
  Debuff: {
    schema: {
      id: "uint256",
      hp: "uint8", // percent, deduce the hp
      atk: "uint8", // percent, deduce the attack
      def: "uint8", // percent, deduce the defense
      agi: "uint8", // percent, deduce the agility
      movement: "uint16", // additional time to move (seconds)
      duration: "uint32", // duration in seconds
    },
    key: ['id'],
  },
}

export default STATUS_TABLES;