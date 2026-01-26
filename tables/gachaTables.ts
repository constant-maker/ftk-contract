import { timeStamp } from "console";

const GACHA_TABLES: any = {
  CharGachaV2: {
    schema: {
      characterId: "uint256",
      requestId: "uint256",
      randomNumber: "uint256", // The random number received from VRF
      gachaId: "uint256",
      isLimitedGacha: "bool",
      gachaItemId: "uint256", // The itemId received from gacha
      isPending: "bool",
      timestamp: "uint256",
    },
    key: ['characterId', 'requestId'],
  },
  CharGachaReq: {
    schema: {
      characterId: "uint256",
      requestId: "uint256",
    },
    key: ['characterId'],
  },
  GachaReqChar: {
    schema: {
      requestId: "uint256",
      characterId: "uint256"
    },
    key: ['requestId'],
  },
  GachaV5: {
    schema: {
      id : "uint256",
      startTime: "uint256",
      ticketValue: "uint256", // Use ETH for gacha
      ticketItemId: "uint256", // Use item as ticket for gacha
      itemIds: "uint256[]",
      amounts: "uint32[]",
      percents: "uint16[]", // The percent chance of getting each item, total is 10000 - min is 1 (0.01%)
    },
    key: ['id'],
  },
  GachaPet: {
    schema: {
      id : "uint256",
      startTime: "uint256",
      endTime: "uint256",
      ticketValue: "uint256", // Either use ETH or item as ticket for gacha
      ticketItemId: "uint256",
      petIds: "uint256[]",
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
