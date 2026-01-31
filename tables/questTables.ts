const QUEST_TABLES: any = {
  CharQuestStatus: {
    schema: {
      characterId: "uint256",
      questId: "uint256",
      questStatus: "QuestStatusType",
    },
    key: ['characterId', 'questId'],
  },
  CharDailyQuest: {
    schema: {
      characterId: "uint256",
      moveCount: "uint8",
      farmCount: "uint8",
      pvpCount: "uint8",
      pveCount: "uint8",
      streak: "uint8",
      startTime: "uint256",
    },
    key: ['characterId'],
  },
  CharSocialQuest: {
    schema: {
      characterId: "uint256",
      twitter: "bool",
      telegram: "bool",
      discord: "bool",
    },
    key: ['characterId'],
  },
  DailyQuestConfig: {
    schema: {
      moveNum: "uint8",
      farmNum: "uint8",
      pvpNum: "uint8",
      pveNum: "uint8",
      rewardExp: "uint32",
      rewardGold: "uint32",
    },
    key: [],
  },
  QuestV4: {
    schema: {
      id: "uint256",
      exp: "uint32",
      gold: "uint32",
      questType: "QuestType",
      fromNpcId: "uint256",
      toNpcId: "uint256",
      achievementId: "uint256",
      requiredAchievementIds: "uint256[]",
      requiredDoneQuestIds: "uint256[]",
      rewardItemIds: "uint256[]",
      rewardItemAmounts: "uint32[]",
    },
    key: ['id'],
  },
  QuestContribute: {
    schema: {
      questId: "uint256",
      itemIds: "uint256[]",
      amounts: "uint32[]",
    },
    key: ['questId'],
  },
  QuestLocate: {
    schema: {
      questId: "uint256",
      xs: "int32[]",
      ys: "int32[]",
    },
    key: ['questId'],
  },
  QuestLocateTracking2: {
    schema: {
      characterId: "uint256",
      questId: "uint256",
      trackIndex: "uint8"
    },
    key: ['characterId', 'questId'],
  },
};

export default QUEST_TABLES;
