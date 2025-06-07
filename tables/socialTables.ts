const SOCIAL_TABLES: any = {
  GlobalChatV2: {
    schema: {
      id: "uint256",
      charId: "uint256",
      timestamp: "uint256",
      rawId: "uint256",
      kingdomId: "uint256",
      name: "string",
      content: "string",
    },
    key: ['id'],
  },
  ChatCounter: {
    schema: {
      counter: "uint256",
    },
    key: [],
  },
}

export default SOCIAL_TABLES;