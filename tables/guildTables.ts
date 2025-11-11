const GUILD_TABLES: any = {
  Guild: {
    schema: {
      id: "uint256",
      leaderId: "uint256",
      level: "uint32",
      createdAt: "uint256",
      point: "uint32",
      name: "string",
      memberIds: "uint256[]",
    },
    key: ['id'],
  },
  GuildCounter: {
    schema: {
      count: "uint256",
    },
    key: [],
  },
  GuildPoint: {
    schema: {
      memberId: "uint256",
      point: "uint32",
      resetTime: "uint256",
    },
    key: ['memberId'],
  },
  GuildOwnerMapping: {
    schema: {
      guildId: "uint256",
      ownerId: "uint256",
    },
    key: ['guildId'],
  },
  GuildMemberMapping: { // to find guild by member, one member only in one guild
    schema: {
      memberId: "uint256",
      guildId: "uint256",
    },
    key: ['memberId'],
  },
  GuildNameMapping: { // to ensure unique guild name
    schema: {
      nameHash: "bytes32",
      guildId: "uint256",
    },
    key: ['nameHash'],
  },
};

export default GUILD_TABLES;
