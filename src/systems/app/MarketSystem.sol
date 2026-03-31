pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  InventoryEquipmentUtils,
  InventoryItemUtils,
  CharacterFundUtils,
  CharacterPositionUtils,
  MarketWeightUtils,
  MapUtils
} from "@utils/index.sol";
import { OrderCounter, Order, OrderData, Equipment, CharMarketWeight, Order2 } from "@codegen/index.sol";
import { OrderParams, TakeOrderParams, MarketSystemUtils } from "@utils/MarketSystemUtils.sol";
import { CurrencyType } from "@codegen/common.sol";
import { Errors, Config } from "@common/index.sol";

contract MarketSystem is System, CharacterAccessControl {
  /// @dev Place a buy or sell order, if orderId is provided,
  /// it will update the existing order, otherwise it will create a new order
  function placeOrder(uint256 characterId, OrderParams memory orderParams) public onlyAuthorizedWallet(characterId) {
    // check and init market storage weight
    MarketWeightUtils.checkAndSetMaxWeight(characterId, orderParams.cityId);
    CharacterPositionUtils.mustInExactCapital(characterId, orderParams.cityId);
    if (!orderParams.isBuy && orderParams.equipmentId != 0) {
      // validate and adjust sell equipment order params
      _validateAndAdjustSellEquipmentOrderParams(orderParams);
    }
    if (orderParams.orderId != 0) {
      _updateOrder(characterId, orderParams);
      return;
    }
    MarketSystemUtils.validateOrder(orderParams);
    MarketSystemUtils.validateCharacter(characterId, orderParams);
    _lockAsset(characterId, orderParams);
    uint256 orderId = _getNewOrderId();
    Order.set(
      orderId,
      orderParams.cityId,
      characterId,
      orderParams.equipmentId,
      orderParams.itemId,
      orderParams.amount,
      orderParams.unitPrice,
      orderParams.isBuy,
      false
    );
    Order2.set(orderId, orderParams.currency, block.timestamp, block.timestamp);
  }

  /// @dev Cancel an existing order, only the owner can cancel and must be in the same city for gold order
  function cancelOrder(uint256 characterId, uint256 orderId) public onlyAuthorizedWallet(characterId) {
    _checkOrderOwnership(characterId, orderId);
    OrderData memory order = Order.get(orderId);
    if (Order2.getCurrency(orderId) == CurrencyType.Crystal) {
      // crystal order can cancel in any capital
      CharacterPositionUtils.mustInCapital(characterId);
    } else {
      CharacterPositionUtils.mustInCity(characterId, order.cityId);
    }
    if (order.isDone) {
      revert Errors.MarketSystem_OrderAlreadyDone(orderId);
    }
    _unlockAsset(characterId, order, orderId);
    Order.deleteRecord(orderId);
    Order2.deleteRecord(orderId);
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
      if (top.amount == 0) {
        revert Errors.MarketSystem_TakerOrderZeroAmount();
      }
      OrderData memory order = Order.get(top.orderId);
      if (order.isDone) {
        revert Errors.MarketSystem_OrderAlreadyDone(top.orderId);
      }
      if (order.characterId == 0) {
        revert Errors.MarketSystem_OrderIsNotExist(top.orderId);
      }
      if (order.characterId == characterId) {
        revert Errors.MarketSystem_CannotTakeOwnOrder(top.orderId);
      }
      CurrencyType orderCurrency = Order2.getCurrency(top.orderId);
      if (orderCurrency == CurrencyType.Gold) {
        // must be in the same city for gold order
        CharacterPositionUtils.mustInCity(characterId, order.cityId);
      } else if (orderCurrency == CurrencyType.Crystal) {
        // can take from any capital
        CharacterPositionUtils.mustInCapital(characterId);
      }
      if (order.isBuy) {
        MarketSystemUtils.takeBuyOrder(characterId, order, top);
      } else {
        MarketSystemUtils.takeSellOrder(characterId, order, top);
      }
      Order2.setUpdateTime(top.orderId, block.timestamp);
      // store fill order
      MarketSystemUtils.storeFillOrder(order, orderCurrency, characterId, top);
    }
  }

  function upgradeMarketWeight(uint256 characterId, uint256 cityId) public onlyAuthorizedWallet(characterId) {
    MapUtils.mustBeCapital(cityId);
    uint32 maxWeight = CharMarketWeight.getMaxWeight(characterId, cityId);
    if (maxWeight == 0) maxWeight = Config.INIT_STORAGE_MAX_WEIGHT;
    uint32 multiplier = (maxWeight - Config.INIT_STORAGE_MAX_WEIGHT) / Config.STORAGE_MAX_WEIGHT_INCREMENT;

    CharacterFundUtils.decreaseGold(characterId, Config.UPGRADE_STORAGE_COST * (multiplier + 1));
    CharMarketWeight.setMaxWeight(characterId, cityId, maxWeight + Config.STORAGE_MAX_WEIGHT_INCREMENT);
  }

  /// @dev Lock asset for order, also update market weight if it's a sell order
  function _lockAsset(uint256 characterId, OrderParams memory orderParams) private {
    if (orderParams.isBuy) {
      // buy - lock gold or crystal
      uint32 totalValue = orderParams.unitPrice * orderParams.amount;
      if (orderParams.currency == CurrencyType.Crystal) {
        CharacterFundUtils.decreaseCrystal(characterId, totalValue);
        return;
      }
      CharacterFundUtils.decreaseGold(characterId, totalValue);
      return;
    }
    // sell - lock item and update market weight
    if (orderParams.equipmentId != 0) {
      // lock equipment
      InventoryEquipmentUtils.removeEquipment(characterId, orderParams.equipmentId, true);
    } else {
      // lock other item
      InventoryItemUtils.removeItem(characterId, orderParams.itemId, orderParams.amount);
    }
    // update market weight
    MarketWeightUtils.updateWeight(characterId, orderParams.cityId, orderParams.itemId, orderParams.amount, false);
  }

  /// @dev Unlock asset for order
  function _unlockAsset(uint256 characterId, OrderData memory order, uint256 orderId) private {
    if (order.isBuy) {
      // buy - unlock gold or crystal
      uint32 totalValue = order.unitPrice * order.amount;
      if (Order2.getCurrency(orderId) == CurrencyType.Crystal) {
        CharacterFundUtils.increaseCrystal(characterId, totalValue);
        return;
      }
      CharacterFundUtils.increaseGold(characterId, totalValue);
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
  function _updateOrder(uint256 characterId, OrderParams memory orderParams) private {
    OrderData memory existingOrder = Order.get(orderParams.orderId);
    if (existingOrder.isDone) {
      revert Errors.MarketSystem_OrderAlreadyDone(orderParams.orderId);
    }
    if (existingOrder.characterId != characterId) {
      revert Errors.MarketSystem_CharacterNotOwner(characterId, orderParams.orderId);
    }
    if (existingOrder.cityId != orderParams.cityId) {
      revert Errors.MarketSystem_CityNotMatch(existingOrder.cityId, orderParams.orderId);
    }
    if (existingOrder.unitPrice == orderParams.unitPrice) {
      // nothing to update
      return;
    }
    CurrencyType orderCurrency = Order2.getCurrency(orderParams.orderId);
    MarketSystemUtils.validateMarketCrystalRule(existingOrder.itemId, orderParams.unitPrice, orderCurrency);
    MarketSystemUtils.validateOrderPrice(orderParams.unitPrice, orderCurrency);
    if (existingOrder.isBuy) {
      // buy order - we need to update gold or crystal
      MarketSystemUtils.updateBuyOrder(characterId, existingOrder, orderParams);
    }
    Order.setUnitPrice(orderParams.orderId, orderParams.unitPrice);
  }

  function _checkOrderOwnership(uint256 characterId, uint256 orderId) private view {
    if (characterId != Order.getCharacterId(orderId)) {
      revert Errors.MarketSystem_CharacterNotOwner(characterId, orderId);
    }
  }

  /// @dev Validate the sell order params for equipment, currently we only support selling 1 equipment per order
  function _validateAndAdjustSellEquipmentOrderParams(OrderParams memory orderParams) private view {
    if (orderParams.amount != 1) {
      revert Errors.MarketSystem_InvalidSellOrderEquipment(orderParams.amount);
    }
    orderParams.itemId = Equipment.getItemId(orderParams.equipmentId);
  }

  function _getNewOrderId() private returns (uint256) {
    uint256 orderId = OrderCounter.get() + 1;
    OrderCounter.set(orderId);
    return orderId;
  }
}
