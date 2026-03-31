const PLATFORM_TABLES: any = {
  PlatformRevenue: {
    schema: {
      totalRevenue: "uint256", // total revenue in crystals, gather from all sources: gacha, market, etc. from the whole platform
      rootTeamCrystal: "uint256", // the remain crystals of team in the root ns
      rootBackerCrystal: "uint256", // the remain crystals of backer in the root ns
      rootVaultCrystal: "uint256", // the remain crystals of vault in the root ns
      appTeamCrystal: "uint256",
      appBackerCrystal: "uint256",
      appVaultCrystal: "uint256",
    },
    key: [],
  },
  WTreasury: { // World Treasury
    schema: {
      totalAmount: "uint256", // total amount in crystals
    },
    key: [],
  }
}

export default PLATFORM_TABLES;