import { i } from "@latticexyz/store/dist/store-CDoWdOke";
import exp from "constants";

const MARKET_TABLES: any = {
  CharMarketWeight: {
    schema: {
      characterId: "uint256",
      cityId: "uint256",
      weight: "uint32",
      maxWeight: "uint32",
    },
    key: ['characterId', 'cityId'],
  },
  Order: {
    schema: {
      id: "uint256",
      cityId: "uint256",
      characterId: "uint256",
      equipmentId: "uint256",
      itemId: "uint256",
      amount: "uint32",
      unitPrice: "uint32",
      isBuy: "bool",
      isDone: "bool"
    },
    key: ['id'],
  },
  Order2: {
    schema: {
      id: "uint256",
      createdTime: "uint256",
      updateTime: "uint256",
    },
    key: ['id'],
  },
  FillOrder: {
    schema: {
      id: "uint256",
      cityId: "uint256",
      characterId: "uint256",
      equipmentId: "uint256",
      itemId: "uint256",
      amount: "uint32",
      unitPrice: "uint32",
      isBuy: "bool",
      filledAt: "uint256",
    },
    key: ['id'],
  },
  KingdomFee: {
    schema: {
      kingdomAId: "uint8",
      kingdomBId: "uint8",
      fee: "uint8",
    },
    key: ['kingdomAId', 'kingdomBId'],
  },
  OrderCounter: {
    schema: {
      counter: "uint256",
    },
    key: [],
  },
  FillCounter: {
    schema: {
      counter: "uint256",
    },
    key: [],
  },
}

export default MARKET_TABLES;