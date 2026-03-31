import { timeStamp } from "console";

const GACHA_TABLES: any = {
  CharGacha: {
    schema: {
      characterId: "uint256",
      requestId: "uint256",
      gachaId: "uint256",
      isLimitedGacha: "bool",
      gachaItemId: "uint256", // The itemId received from gacha
      gachaEquipmentId: "uint256", // The equipmentId received from gacha, 0 if not equipment
      isPending: "bool",
      timestamp: "uint256",
      randomNumbers: "uint256[]", // The random numbers received from VRF
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
  GachaReqInfo: {
    schema: {
      requestId: "uint256",
      characterId: "uint256",
      gachaType: "GachaType",
      extraData: "bytes",
    },
    key: ['requestId'],
  },
  Gacha: {
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
  GachaCounter: {
    schema: {
      count: "uint256",
    },
    key: [],
  },
};

export default GACHA_TABLES;
