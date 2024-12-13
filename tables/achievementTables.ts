const ACHIEVEMENT_TABLES: any = {
  Achievement: {
    schema: {
      id: "uint256",
      atk: "uint16",
      def: "uint16",
      agi: "uint16",
      name: "string",
    },
    key: ['id'],
  },
  CharAchievement: {
    schema: {
      charId: "uint256",
      achievementIds: "uint256[]"
    },
    key: ['charId'],
  },
  CharAchievementIndex: {
    schema: {
      charId: "uint256",
      achievementId: "uint256",
      index: "uint256",
    },
    key: ['charId', 'achievementId'],
  },
}

export default ACHIEVEMENT_TABLES;