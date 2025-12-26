import { timeStamp } from "console";

const GACHA_TABLES: any = {
  CharGacha: {
    schema: {
      characterId: "uint256",
      requestId: "uint256",
      randomNumber: "uint256", // The random number received from VRF
      gachaId: "uint256",
      gachaItemId: "uint256", // The itemId received from gacha
      isPending: "bool",
      timestamp: "uint256",
    },
    key: ['characterId', 'requestId'],
  },
  GachaReqChar: {
    schema: {
      requestId: "uint256",
      characterId: "uint256"
    },
    key: ['requestId'],
  },
  Gacha: {
    schema: {
      id : "uint256",
      gachaType: "GachaType",
      startTime: "uint256",
      endTime: "uint256",
      itemIds: "uint256[]",
    },
    key: ['id'],
  },
  GachaCounter: {
    schema: {
      count: "uint256",
    },
    key: [],
  },
  GachaItemIndex: {
    schema: {
      gachaId: "uint256",
      itemId: "uint256",
      index: "uint256",
    },
    key: ['gachaId', 'itemId'],
  },
};

export default GACHA_TABLES;
