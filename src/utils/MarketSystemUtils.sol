pragma solidity >=0.8.24;

import { InventoryEquipmentUtils } from "./InventoryEquipmentUtils.sol";
import { InventoryItemUtils } from "./InventoryItemUtils.sol";
import { CharacterFundUtils } from "./CharacterFundUtils.sol";
import { CharacterPositionUtils } from "./CharacterPositionUtils.sol";
import { MarketWeightUtils } from "./MarketWeightUtils.sol";
import {
  CharStats2,
  OrderCounter,
  Order,
  OrderData,
  Equipment,
  CharMarketWeight,
  CharOtherItem,
  CharFund,
  Item,
  CharInfo,
  City,
  KingdomFee
} from "@codegen/index.sol";
import { ItemCategoryType } from "@codegen/common.sol";
import { Errors, Config } from "@common/index.sol";

struct OrderParams {
  uint256 orderId; // if orderId != 0, then this is an order update
  uint256 cityId;
  uint256 equipmentId;
  uint256 itemId;
  uint32 amount;
  uint32 unitPrice;
  bool isBuy;
}

struct TakeOrderParams {
  uint256 orderId;
  uint32 amount;
  uint256[] equipmentIds; // to take buy equipment order
}

library MarketSystemUtils {
  uint32 constant REQUIRED_FAME = 1050;

  /// @dev Take a buy order, no need to decrease gold from order owner because it's already locked when order is created
  function takeBuyOrder(uint256 takerId, OrderData memory order, TakeOrderParams memory top) public {
    if (order.amount < top.amount) {
      revert Errors.MarketSystem_InvalidTakerAmount(top.orderId, order.amount, top.amount);
    }
    if (Item.getCategory(order.itemId) == ItemCategoryType.Equipment) {
      // equipment order
      if (top.equipmentIds.length != top.amount) {
        revert Errors.MarketSystem_InvalidTakerOrderEquipmentData(top.orderId, top.amount, top.equipmentIds.length);
      }
      for (uint256 i = 0; i < top.equipmentIds.length; i++) {
        uint256 equipmentId = top.equipmentIds[i];
        if (Equipment.getItemId(equipmentId) != order.itemId) {
          revert Errors.MarketSystem_InvalidOfferEquipment(top.orderId, order.itemId, equipmentId);
        }
        // check if taker has the equipment
        if (!InventoryEquipmentUtils.hasEquipment(takerId, equipmentId)) {
          revert Errors.Equipment_NotOwned(takerId, equipmentId);
        }
        // remove equipment from taker
        InventoryEquipmentUtils.removeEquipment(takerId, equipmentId, true);
        // transfer equipment to order owner
        Equipment.setCharacterId(equipmentId, order.characterId);
        InventoryEquipmentUtils.addEquipment(order.characterId, equipmentId, true);
      }
    } else {
      // other item order
      // check if taker has enough item
      if (CharOtherItem.getAmount(takerId, order.itemId) < top.amount) {
        revert Errors.MarketSystem_InsufficientItem(takerId, order.itemId, top.amount);
      }
      // remove item from taker
      InventoryItemUtils.removeItem(takerId, order.itemId, top.amount);
      // transfer item to order owner
      InventoryItemUtils.addItem(order.characterId, order.itemId, top.amount);
    }
    // claim gold from order
    uint32 totalGold = order.unitPrice * top.amount;
    // fee is always smaller than totalGold
    uint32 orderFee = calculateOrderFee(takerId, order.cityId, totalGold);
    CharacterFundUtils.increaseGold(takerId, totalGold - orderFee);
    // update order
    uint32 newAmount = order.amount - top.amount;
    if (newAmount == 0) {
      // order is done
      Order.setIsDone(top.orderId, true);
    } else {
      // update order amount
      Order.setAmount(top.orderId, newAmount);
    }
  }

  /// @dev Take a sell order
  function takeSellOrder(uint256 takerId, OrderData memory order, TakeOrderParams memory top) public {
    if (order.amount < top.amount) {
      revert Errors.MarketSystem_InvalidTakerAmount(top.orderId, order.amount, top.amount);
    }
    // check if taker has enough gold
    uint32 charGold = CharFund.getGold(takerId);
    uint32 totalGold = order.unitPrice * top.amount;
    if (charGold < totalGold) {
      revert Errors.MarketSystem_InsufficientGold(takerId, charGold, totalGold);
    }
    // remove gold from taker
    CharacterFundUtils.decreaseGold(takerId, totalGold);
    // increase gold for order owner
    // fee is always smaller than totalGold
    uint32 orderFee = calculateOrderFee(order.characterId, order.cityId, totalGold);
    CharacterFundUtils.increaseGold(order.characterId, totalGold - orderFee);
    // transfer item to taker
    if (order.equipmentId != 0) {
      InventoryEquipmentUtils.addEquipment(takerId, order.equipmentId, true);
      Equipment.setCharacterId(order.equipmentId, takerId);
    } else {
      InventoryItemUtils.addItem(takerId, order.itemId, top.amount);
    }
    // decrease market weight
    MarketWeightUtils.updateWeight(order.characterId, order.cityId, order.itemId, top.amount, true);
    // update order
    uint32 newAmount = order.amount - top.amount;
    if (newAmount == 0) {
      // order is done
      Order.setIsDone(top.orderId, true);
    } else {
      // update order amount
      Order.setAmount(top.orderId, newAmount);
    }
  }

  /// @dev Calculate order fee in gold
  function calculateOrderFee(uint256 receiverId, uint256 cityId, uint32 value) public view returns (uint32) {
    uint8 receiverKingdomId = CharInfo.getKingdomId(receiverId);
    uint8 marketKingdomId = City.getKingdomId(cityId);
    if (receiverKingdomId == marketKingdomId) {
      return value * uint32(Config.DEFAULT_MARKET_FEE) / 100;
    }
    uint8 fee = KingdomFee.getFee(marketKingdomId, receiverKingdomId);
    if (fee == 0) {
      // default fee
      fee = Config.DEFAULT_MARKET_FEE;
    }
    return value * uint32(fee) / 100;
  }

  /// @dev validate order params
  function validateOrder(uint256 characterId, OrderParams memory order) public view {
    validateOrderPrice(order.unitPrice);
    if (order.amount == 0) {
      revert Errors.MarketSystem_ZeroAmount();
    }
    if (order.itemId == 0) {
      revert Errors.MarketSystem_ZeroItemId();
    }
    // sell order has zero equipmentId, it must be an other item
    if (!order.isBuy && order.equipmentId == 0 && Item.getCategory(order.itemId) != ItemCategoryType.Other) {
      revert Errors.MarketSystem_InvalidItemType(order.itemId);
    }
  }

  function validateSellOrder(uint256 characterId, OrderParams memory order) public view {
    _validateMarketWeight(characterId, order);
    if (order.equipmentId != 0) {
      if (!InventoryEquipmentUtils.hasEquipment(characterId, order.equipmentId)) {
        revert Errors.Equipment_NotOwned(characterId, order.equipmentId);
      }
    } else if (CharOtherItem.getAmount(characterId, order.itemId) < order.amount) {
      revert Errors.MarketSystem_InsufficientItem(characterId, order.itemId, order.amount);
    }
  }

  /// @dev update buy order gold - we need to charge more or repay gold
  function updateBuyOrderGold(uint256 characterId, OrderData memory existingOrder, uint32 newUnitPrice) public {
    uint32 charGold = CharFund.getGold(characterId);
    if (existingOrder.unitPrice < newUnitPrice) {
      // charge more gold
      uint32 goldChange = (newUnitPrice - existingOrder.unitPrice) * existingOrder.amount;
      if (goldChange > charGold) {
        revert Errors.MarketSystem_InsufficientGold(characterId, charGold, goldChange);
      }
      // decrease gold from character
      CharacterFundUtils.decreaseGold(characterId, goldChange);
    } else {
      // repay gold
      uint32 goldChange = (existingOrder.unitPrice - newUnitPrice) * existingOrder.amount;
      CharacterFundUtils.increaseGold(characterId, goldChange);
    }
  }

  function validateBuyOrder(uint256 characterId, OrderParams memory order) public view {
    uint32 charGold = CharFund.getGold(characterId);
    if (charGold < order.unitPrice * order.amount) {
      revert Errors.MarketSystem_InsufficientGold(characterId, charGold, order.unitPrice * order.amount);
    }
  }

  /// @dev validate character (fame, gold, weight)
  function validateCharacter(uint256 characterId, OrderParams memory order) public view {
    uint32 fame = CharStats2.getFame(characterId);
    if (fame < REQUIRED_FAME) {
      revert Errors.MarketSystem_FameTooLow(characterId, fame);
    }
    if (order.isBuy) {
      // buy - we need to check if the character has enough gold
      validateBuyOrder(characterId, order);
    } else {
      // sell - we need to check if the character has the item, character market weight
      validateSellOrder(characterId, order);
    }
  }

  function validateOrderPrice(uint32 orderPrice) public pure {
    if (orderPrice == 0) {
      revert Errors.MarketSystem_ZeroPrice();
    }
    if (orderPrice > 1_000_000) {
      revert Errors.MarketSystem_ExceedMaxPrice(orderPrice);
    }
  }

  /// @dev validate weight but also set max weight if not set
  function _validateMarketWeight(uint256 characterId, OrderParams memory order) private view {
    uint256 cityId = order.cityId;
    uint32 currentWeight = CharMarketWeight.getWeight(characterId, cityId);
    uint32 maxWeight = CharMarketWeight.getMaxWeight(characterId, cityId);
    uint32 itemWeight = Item.getWeight(order.itemId);
    uint32 totalWeight = currentWeight + (itemWeight * order.amount);
    if (totalWeight > maxWeight) {
      revert Errors.MarketSystem_ExceedMaxWeight(characterId, order.cityId, totalWeight, maxWeight);
    }
  }
}
