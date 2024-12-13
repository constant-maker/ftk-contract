const SOCIAL_TABLES: any = {
  GlobalChat: {
    schema: {
      id: "uint256",
      charId: "uint256",
      timestamp: "uint256",
      rawId: "uint256",
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