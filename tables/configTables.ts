// import { any } from "@latticexyz/store/ts/config/storeConfig";

const CONFIG_TABLES: any = {
  MapConfig: {
    schema: {
      width: "uint32",
      height: "uint32",
    },
    key: [],
  },
  InventoryConfig: {
    schema: {
      baseWeight: "uint32",
      maxWeight: "uint32",
    },
    key: [],
  },
  MovementConfig: {
    schema: {
      baseMovementSpeed: "uint16",
      maxMovementSpeed: "uint16",
      duration: "uint16",
    },
    key: [],
  },
  Contracts: {
    schema: {
      erc721Token: "address",
      erc20Token: "address",
    },
    key: [],
  },
  // This table is used to store experience amplification settings
  // Usually for special occasions
  ExpAmpConfig: {
    schema: {
      farmingPerkAmp: "uint16", // these values are percentages, e.g., 20 means gain 20% more exp
      pveExpAmp: "uint16",
      pvePerkAmp: "uint16",
      expireTime: "uint256",
    },
    key: [],
  },
  TestTable: {
    schema: {
      column1: "uint256",
      column2: "uint256",
      column3: "uint256",
    },
    key: ['column1'],
  },
};

export default CONFIG_TABLES;
