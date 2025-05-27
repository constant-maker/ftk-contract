pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  InventoryEquipmentUtils,
  InventoryItemUtils,
  CharacterFundUtils,
  CharacterPositionUtils,
  MarketWeightUtils
} from "@utils/index.sol";
import { OrderCounter, Order, OrderData, Equipment, CharMarketWeight, CharOtherItem, Order2 } from "@codegen/index.sol";
import { OrderParams, TakeOrderParams, MarketSystemUtils } from "@utils/MarketSystemUtils.sol";
import { ItemCategoryType } from "@codegen/common.sol";
import { Errors, Config } from "@common/index.sol";

contract MarketSystem is System, CharacterAccessControl {
  function placeOrder(uint256 characterId, OrderParams memory order) public onlyAuthorizedWallet(characterId) {
    MarketWeightUtils.checkAndSetMaxWeight(characterId, order.cityId); // set default max weight if not set
    CharacterPositionUtils.MustInCity(characterId, order.cityId);
    _updateOrderParams(order);
    if (order.orderId != 0) {
      _updateOrder(characterId, order);
      return;
    }
    MarketSystemUtils.validateOrder(characterId, order);
    MarketSystemUtils.validateCharacter(characterId, order);
    _lockAsset(characterId, order);
    uint256 orderId = _getNewOrderId();
    Order.set(
      orderId,
      order.cityId,
      characterId,
      order.equipmentId,
      order.itemId,
      order.amount,
      order.unitPrice,
      order.isBuy,
      false
    );
    Order2.set(orderId, block.timestamp, block.timestamp);
  }

  function cancelOrder(uint256 characterId, uint256 orderId) public onlyAuthorizedWallet(characterId) {
    _checkOrderOwnership(characterId, orderId);
    OrderData memory order = Order.get(orderId);
    CharacterPositionUtils.MustInCity(characterId, order.cityId);
    if (order.isDone) {
      revert Errors.MarketSystem_OrderAlreadyDone(orderId);
    }
    _unlockAsset(characterId, order);
    Order.deleteRecord(orderId);
  }

  function takeOrder(
    uint256 characterId,
    TakeOrderParams[] calldata takeParams
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    for (uint256 i = 0; i < takeParams.length; i++) {
      TakeOrderParams memory top = takeParams[i];
      OrderData memory order = Order.get(top.orderId);
      if (order.isDone) {
        revert Errors.MarketSystem_OrderAlreadyDone(top.orderId);
      }
      if (order.characterId == 0) {
        revert Errors.MarketSystem_OrderIsNotExist(top.orderId);
      }
      if (top.amount == 0) {
        revert Errors.MarketSystem_TakerOrderZeroAmount();
      }
      if (order.isBuy) {
        MarketSystemUtils.takeBuyOrder(characterId, order, top);
      } else {
        MarketSystemUtils.takeSellOrder(characterId, order, top);
      }
      Order2.setUpdateTime(top.orderId, block.timestamp);
      // store fill order
      MarketSystemUtils.storeFillOrder(order, characterId, top.amount);
    }
  }

  function upgradeMarketWeight(uint256 characterId, uint256 cityId) public onlyAuthorizedWallet(characterId) {
    uint32 maxWeight = CharMarketWeight.getMaxWeight(characterId, cityId);
    if (maxWeight == 0) maxWeight = Config.INIT_STORAGE_MAX_WEIGHT;
    uint32 multiplier = (maxWeight - Config.INIT_STORAGE_MAX_WEIGHT) / Config.STORAGE_MAX_WEIGHT_INCREMENT;

    CharacterFundUtils.decreaseGold(characterId, Config.UPGRADE_STORAGE_COST * (multiplier + 1));
    CharMarketWeight.setMaxWeight(characterId, cityId, maxWeight + Config.STORAGE_MAX_WEIGHT_INCREMENT);
  }

  /// @dev Lock asset for order, also update market weight if it's a sell order
  function _lockAsset(uint256 characterId, OrderParams memory order) private {
    if (order.isBuy) {
      // buy - lock gold
      uint32 totalGold = order.unitPrice * order.amount;
      CharacterFundUtils.decreaseGold(characterId, totalGold);
      return;
    }
    // sell - lock item and update market weight
    if (order.equipmentId != 0) {
      // lock equipment
      InventoryEquipmentUtils.removeEquipment(characterId, order.equipmentId, true);
    } else {
      // lock other item
      InventoryItemUtils.removeItem(characterId, order.itemId, order.amount);
    }
    // update market weight
    MarketWeightUtils.updateWeight(characterId, order.cityId, order.itemId, order.amount, false);
  }

  /// @dev Unlock asset for order
  function _unlockAsset(uint256 characterId, OrderData memory order) private {
    if (order.isBuy) {
      // buy - unlock gold
      uint32 totalGold = order.unitPrice * order.amount;
      CharacterFundUtils.increaseGold(characterId, totalGold);
      return;
    }
    // sell - unlock item and update market weight
    if (order.equipmentId != 0) {
      // unlock equipment
      InventoryEquipmentUtils.addEquipment(characterId, order.equipmentId, true);
    } else {
      // unlock other item
      InventoryItemUtils.addItem(characterId, order.itemId, order.amount);
    }
    // update market weight
    MarketWeightUtils.updateWeight(characterId, order.cityId, order.itemId, order.amount, true);
  }

  /// @dev Update existing order - user only can update unit price
  function _updateOrder(uint256 characterId, OrderParams memory order) private {
    MarketSystemUtils.validateOrderPrice(order.unitPrice);
    OrderData memory existingOrder = Order.get(order.orderId);
    if (existingOrder.isDone) {
      revert Errors.MarketSystem_OrderAlreadyDone(order.orderId);
    }
    if (existingOrder.characterId != characterId) {
      revert Errors.MarketSystem_CharacterNotOwner(characterId, order.orderId);
    }
    if (existingOrder.cityId != order.cityId) {
      revert Errors.MarketSystem_CityNotMatch(existingOrder.cityId, order.orderId);
    }
    if (existingOrder.unitPrice == order.unitPrice) {
      // nothing to update
      return;
    }

    if (existingOrder.isBuy) {
      // buy order - we need to update gold
      MarketSystemUtils.updateBuyOrderGold(characterId, existingOrder, order.unitPrice);
    }
    Order.setUnitPrice(order.orderId, order.unitPrice);
  }

  function _checkOrderOwnership(uint256 characterId, uint256 orderId) private view {
    if (characterId != Order.getCharacterId(orderId)) {
      revert Errors.MarketSystem_CharacterNotOwner(characterId, orderId);
    }
  }

  /// @dev Update order params
  /// @dev if equipmentId is set, we need to update itemId and amount
  function _updateOrderParams(OrderParams memory order) private view {
    if (order.equipmentId != 0) {
      order.itemId = Equipment.getItemId(order.equipmentId);
      order.amount = 1;
    }
  }

  function _getNewOrderId() private returns (uint256) {
    uint256 orderId = OrderCounter.get() + 1;
    OrderCounter.set(orderId);
    return orderId;
  }
}
