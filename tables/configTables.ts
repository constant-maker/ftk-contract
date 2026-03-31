// import { any } from "@latticexyz/store/ts/config/storeConfig";

const CONFIG_TABLES: any = {
  MapConfig: {
    schema: {
      top: "int32",
      right: "int32",
      bottom: "int32",
      left: "int32",
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
  // This table is used to store global experience amplification settings
  // Usually for special occasions
  ExpAmpConfig: {
    schema: {
      farmingPerkAmp: "uint16", // These values are percentages, e.g., 20 means gain 20% more exp
      pveExpAmp: "uint16",
      expireTime: "uint256",
    },
    key: [],
  },
};

export default CONFIG_TABLES;
