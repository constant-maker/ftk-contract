const WELCOME_PACKAGE_TABLES: any = {
  WelcomeConfig: {
    schema: {
      itemDetailIds: "uint256[]",
    },
    key: [],
  },
  WelcomePackages: {
    schema: {
      characterId: "uint256",
      claimed: "bool",
    },
    key: ['characterId'],
  },
};

export default WELCOME_PACKAGE_TABLES;
