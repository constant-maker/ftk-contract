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
}

export default STATUS_TABLES;