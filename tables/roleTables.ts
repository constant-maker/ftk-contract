const ROLE_TABLES: any = {
  CharRole: {
    schema: {
      characterId: "uint256",
      roleType: "RoleType",
    },
    key: ['characterId'],
  },
  CharRoleCounter: {
    schema: {
      kingdomId: "uint256",
      roleType: "RoleType",
      count: "uint32",
    },
    key: ['kingdomId', 'roleType'],
  }
};

export default ROLE_TABLES;
