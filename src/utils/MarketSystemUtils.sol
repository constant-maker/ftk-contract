pragma solidity >=0.8.24;

import { InventoryEquipmentUtils } from "./InventoryEquipmentUtils.sol";
import { InventoryItemUtils } from "./InventoryItemUtils.sol";
import { MarketWeightUtils } from "./MarketWeightUtils.sol";
import { StorageEquipmentUtils } from "./StorageEquipmentUtils.sol";
import { StorageItemUtils } from "./StorageItemUtils.sol";
import { MarketSystemUtils2 } from "./MarketSystemUtils2.sol";
import {
  Order,
  OrderData,
  Equipment,
  CharOtherItem,
  Item,
  FillOrder,
  FillOrder2,
  FillCounter
} from "@codegen/index.sol";
import { ItemCategoryType, CurrencyType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";

struct OrderParams {
  uint256 orderId; // if orderId != 0, then this is an order update
  uint256 cityId;
  uint256 equipmentId;
  uint256 itemId;
  uint32 amount;
  uint32 unitPrice;
  CurrencyType currency;
  bool isBuy;
}

struct TakeOrderParams {
  uint256 orderId;
  uint32 amount;
  uint256[] equipmentIds; // to take buy equipment order
}

library MarketSystemUtils {
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
        StorageEquipmentUtils.addEquipment(order.characterId, order.cityId, equipmentId, false);
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
      StorageItemUtils.addItem(order.characterId, order.cityId, order.itemId, top.amount, false);
    }
    // handle gold or crystal transfer from order owner to taker
    MarketSystemUtils2.handleBuyOrderTakerBalance(takerId, order, top.orderId, top.amount);
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
    MarketSystemUtils2.handleSellOrderTakerBalance(takerId, order, top.orderId, top.amount);
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

  function storeFillOrder(
    OrderData memory order,
    CurrencyType orderCurrency,
    uint256 takerId,
    TakeOrderParams memory top
  )
    public
  {
    uint256 newFillOrderId = FillCounter.get() + 1;
    FillCounter.set(newFillOrderId);
    bool isBuy = order.isBuy ? false : true; // reverse isBuy for fill order
    FillOrder.set(
      newFillOrderId,
      order.cityId,
      takerId,
      order.equipmentId,
      order.itemId,
      top.amount,
      order.unitPrice,
      isBuy,
      block.timestamp
    );
    FillOrder2.set(newFillOrderId, top.orderId, order.characterId, orderCurrency, top.equipmentIds);
  }

  /// @dev Validate order params
  function validateOrder(OrderParams memory order) public view {
    MarketSystemUtils2.validateMarketCrystalRule(order.itemId, order.unitPrice, order.currency);
    MarketSystemUtils2.validateOrderPrice(order.unitPrice, order.currency);
    if (order.amount == 0) {
      revert Errors.MarketSystem_ZeroAmount();
    }
    if (order.itemId == 0) {
      revert Errors.MarketSystem_ZeroItemId();
    }
    if (Item.getIsUntradeable(order.itemId)) {
      revert Errors.MarketSystem_UntradeableItem(order.itemId);
    }
    // sell order has zero equipmentId, it must be an other item
    if (!order.isBuy && order.equipmentId == 0 && Item.getCategory(order.itemId) != ItemCategoryType.Other) {
      revert Errors.MarketSystem_InvalidItemType(order.itemId);
    }
  }

  /// @dev Validate character (fame, gold, weight)
  function validateCharacter(uint256 characterId, OrderParams memory order) public view {
    if (order.isBuy) {
      MarketSystemUtils2.validateBuyOrder(characterId, order.currency, order.unitPrice, order.amount);
    } else {
      MarketSystemUtils2.validateSellOrder(characterId, order.cityId, order.equipmentId, order.itemId, order.amount);
    }
  }
}
