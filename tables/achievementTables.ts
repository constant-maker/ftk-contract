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
      characterId: "uint256",
      achievementIds: "uint256[]"
    },
    key: ['characterId'],
  },
  CharAchievementIndex: {
    schema: {
      characterId: "uint256",
      achievementId: "uint256",
      index: "uint256",
    },
    key: ['characterId', 'achievementId'],
  },
}

export default ACHIEVEMENT_TABLES;