pragma solidity >=0.8.24;

import { InventoryEquipmentUtils } from "./InventoryEquipmentUtils.sol";
import { InventoryItemUtils } from "./InventoryItemUtils.sol";
import { CharacterFundUtils } from "./CharacterFundUtils.sol";
import { MarketWeightUtils } from "./MarketWeightUtils.sol";
import { StorageEquipmentUtils } from "./StorageEquipmentUtils.sol";
import { StorageItemUtils } from "./StorageItemUtils.sol";
import { KingdomUtils } from "./KingdomUtils.sol";
import { CityVaultUtils } from "./CityVaultUtils.sol";
import { PlatformUtils } from "./PlatformUtils.sol";
import {
  Order,
  OrderData,
  Order2,
  Equipment,
  CharMarketWeight,
  CharOtherItem,
  CharFund,
  Item,
  CharInfo,
  City,
  MarketFee,
  CrystalFee,
  FillOrder,
  FillOrder2,
  FillCounter,
  MarketCrystal
} from "@codegen/index.sol";
import { ItemCategoryType, CurrencyType } from "@codegen/common.sol";
import { Errors, Config } from "@common/index.sol";

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
    _handleBuyOrderTakerBalance(takerId, order, top);
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
    _handleSellOrderTakerBalance(takerId, order, top);
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
    validateMarketCrystalRule(order.itemId, order.unitPrice, order.currency);
    validateOrderPrice(order.unitPrice, order.currency);
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

  /// @dev Enforce market crystal settings for item/currency/price
  function validateMarketCrystalRule(uint256 itemId, uint32 unitPrice, CurrencyType currency) public view {
    uint32 minCrystalPrice = MarketCrystal.getMinUnitPrice(itemId);
    if (minCrystalPrice == 0) {
      return;
    }
    // if item has configured min crystal unit price, currency must be crystal
    if (currency != CurrencyType.Crystal) {
      revert Errors.MarketSystem_ItemMustBeTradedWithCrystal(itemId);
    }
    if (unitPrice < minCrystalPrice) {
      revert Errors.MarketSystem_CrystalPriceTooLow(itemId, unitPrice, minCrystalPrice);
    }
  }

  function validateSellOrder(uint256 characterId, OrderParams memory order) public view {
    validateMarketWeight(characterId, order);
    if (order.equipmentId != 0) {
      if (!InventoryEquipmentUtils.hasEquipment(characterId, order.equipmentId)) {
        revert Errors.Equipment_NotOwned(characterId, order.equipmentId);
      }
    } else if (CharOtherItem.getAmount(characterId, order.itemId) < order.amount) {
      revert Errors.MarketSystem_InsufficientItem(characterId, order.itemId, order.amount);
    }
  }

  /// @dev Update buy order - we need to charge more or repay gold or crystal
  function updateBuyOrder(uint256 characterId, OrderData memory existingOrder, OrderParams memory updateParams) public {
    if (Order2.getCurrency(updateParams.orderId) == CurrencyType.Gold) {
      _updateBuyOrderGold(characterId, existingOrder, updateParams.unitPrice);
    } else {
      _updateBuyOrderCrystal(characterId, existingOrder, updateParams.unitPrice);
    }
  }

  /// @dev Update buy order gold - we need to charge more or repay gold
  function _updateBuyOrderGold(uint256 characterId, OrderData memory existingOrder, uint32 newUnitPrice) private {
    uint32 charGold = CharFund.getGold(characterId);
    if (existingOrder.unitPrice < newUnitPrice) {
      // charge more gold
      uint32 goldChange = (newUnitPrice - existingOrder.unitPrice) * existingOrder.amount;
      if (goldChange > charGold) {
        revert Errors.InsufficientGold(charGold, goldChange);
      }
      // decrease gold from character
      CharacterFundUtils.decreaseGold(characterId, goldChange);
    } else {
      // repay gold
      uint32 goldChange = (existingOrder.unitPrice - newUnitPrice) * existingOrder.amount;
      CharacterFundUtils.increaseGold(characterId, goldChange);
    }
  }

  /// @dev Update buy order crystal - we need to charge more or repay crystal
  function _updateBuyOrderCrystal(uint256 characterId, OrderData memory existingOrder, uint32 newUnitPrice) private {
    uint256 charCrystal = CharFund.getCrystal(characterId);
    if (existingOrder.unitPrice < newUnitPrice) {
      // charge more crystal
      uint256 crystalChange = (newUnitPrice - existingOrder.unitPrice) * existingOrder.amount;
      if (crystalChange > charCrystal) {
        revert Errors.InsufficientCrystal(charCrystal, crystalChange);
      }
      // decrease crystal from character
      CharacterFundUtils.decreaseCrystal(characterId, crystalChange);
    } else {
      // repay crystal
      uint256 crystalChange = (existingOrder.unitPrice - newUnitPrice) * existingOrder.amount;
      CharacterFundUtils.increaseCrystal(characterId, crystalChange);
    }
  }

  function validateBuyOrder(uint256 characterId, OrderParams memory order) public view {
    CurrencyType currency = order.currency;
    if (currency == CurrencyType.Gold) {
      uint32 charGold = CharFund.getGold(characterId);
      if (charGold < order.unitPrice * order.amount) {
        revert Errors.InsufficientGold(charGold, order.unitPrice * order.amount);
      }
      return;
    }
    // check crystal
    uint256 charCrystal = CharFund.getCrystal(characterId);
    if (charCrystal < order.unitPrice * order.amount) {
      revert Errors.InsufficientCrystal(charCrystal, order.unitPrice * order.amount);
    }
  }

  /// @dev Validate character (fame, gold, weight)
  function validateCharacter(uint256 characterId, OrderParams memory order) public view {
    if (order.isBuy) {
      // buy - we need to check if the character has enough gold or crystal
      validateBuyOrder(characterId, order);
    } else {
      // sell - we need to check if the character has the item, character market weight
      validateSellOrder(characterId, order);
    }
  }

  function validateOrderPrice(uint32 orderPrice, CurrencyType currency) public view {
    if (currency == CurrencyType.Crystal) {
      _validateCrystalPrice(orderPrice);
      return;
    }
    if (orderPrice == 0) {
      revert Errors.MarketSystem_ZeroPrice();
    }
    if (orderPrice > 1_000_000) {
      revert Errors.MarketSystem_ExceedMaxPrice(orderPrice);
    }
  }

  function _validateCrystalPrice(uint32 orderPrice) private pure {
    if (orderPrice < Config.MIN_CRYSTALS_PER_PURCHASE || orderPrice % Config.MIN_CRYSTALS_PER_PURCHASE != 0) {
      revert Errors.InvalidCrystalAmount(uint256(orderPrice), Config.MIN_CRYSTALS_PER_PURCHASE);
    }
  }

  /// @dev Validate market weight, if it's a sell order,
  /// we need to check if the new weight after placing the order exceed the max weight
  function validateMarketWeight(uint256 characterId, OrderParams memory order) public view {
    uint256 cityId = order.cityId;
    uint32 currentWeight = CharMarketWeight.getWeight(characterId, cityId);
    uint32 maxWeight = CharMarketWeight.getMaxWeight(characterId, cityId);
    uint32 itemWeight = Item.getWeight(order.itemId);
    uint32 totalWeight = currentWeight + (itemWeight * order.amount);
    if (totalWeight > maxWeight) {
      revert Errors.MarketSystem_ExceedMaxWeight(characterId, order.cityId, totalWeight, maxWeight);
    }
  }

  /// @dev Calculate order fee based on currency type and kingdom relationship between character and city
  function calculateOrderFee(
    uint256 characterId,
    uint256 cityId,
    uint32 value,
    CurrencyType currency
  )
    public
    view
    returns (uint32)
  {
    uint8 marketKingdomId = City.getKingdomId(cityId);
    uint8 characterKingdomId = CharInfo.getKingdomId(characterId);
    uint8 feePercentage;
    if (currency == CurrencyType.Crystal) {
      // crystal fee is based on character kingdom only, no matter where the market is
      feePercentage = CrystalFee.getFee(characterKingdomId);
    } else {
      feePercentage = MarketFee.getFee(marketKingdomId, characterKingdomId);
    }
    if (feePercentage == 0) {
      return 0;
    }
    return value * uint32(feePercentage) / 100;
  }

  /// @dev Handle gold or crystal transfer from order owner to taker when take a sell order
  /// the seller will pay fee
  function _handleSellOrderTakerBalance(uint256 takerId, OrderData memory order, TakeOrderParams memory top) public {
    uint32 orderValue = order.unitPrice * top.amount;
    if (Order2.getCurrency(top.orderId) == CurrencyType.Gold) {
      CharacterFundUtils.decreaseGold(takerId, orderValue);
      _handleSellOrderTakerWithGold(order, orderValue);
    } else {
      CharacterFundUtils.decreaseCrystal(takerId, orderValue);
      _handleSellOrderTakerWithCrystal(order, orderValue);
    }
  }

  function _handleSellOrderTakerWithGold(OrderData memory order, uint32 orderValue) private {
    uint32 orderFee = calculateOrderFee(order.characterId, order.cityId, orderValue, CurrencyType.Gold);
    CharacterFundUtils.increaseGold(order.characterId, orderValue - orderFee);
    // fee is always smaller than orderValue (<= 100%)
    CityVaultUtils.updateVaultGold(order.cityId, orderFee, true);
  }

  function _handleSellOrderTakerWithCrystal(OrderData memory order, uint32 orderValue) private {
    uint32 platformFee = uint32(PlatformUtils.getPlatformFee(orderValue));
    uint32 finalOrderValue = orderValue - platformFee;
    if (platformFee > 0) {
      PlatformUtils.updateAppTeamCrystal(platformFee, true);
    }
    // charge fee seller
    uint32 orderFee = calculateOrderFee(order.characterId, order.cityId, finalOrderValue, CurrencyType.Crystal);
    uint256 capitalId = KingdomUtils.getCapitalIdByCharacterId(order.characterId);
    CityVaultUtils.updateVaultCrystal(capitalId, orderFee, true);
    if (orderFee > 0) {
      PlatformUtils.updateAppVaultCrystal(orderFee, true);
    }
    // fee is always smaller than finalOrderValue (<= 100%)
    CharacterFundUtils.increaseCrystal(order.characterId, finalOrderValue - orderFee);
  }

  /// @dev Handle gold or crystal transfer from order owner to taker when take a buy order
  /// taker will pay fee
  function _handleBuyOrderTakerBalance(uint256 takerId, OrderData memory order, TakeOrderParams memory top) public {
    // claim gold or crystal from order
    uint32 orderValue = order.unitPrice * top.amount;
    if (Order2.getCurrency(top.orderId) == CurrencyType.Gold) {
      _handleBuyOrderTakerWithGold(takerId, order, orderValue);
    } else {
      _handleBuyOrderTakerWithCrystal(takerId, order, orderValue);
    }
  }

  function _handleBuyOrderTakerWithGold(uint256 takerId, OrderData memory order, uint32 orderValue) private {
    uint32 orderFee = calculateOrderFee(takerId, order.cityId, orderValue, CurrencyType.Gold);
    CityVaultUtils.updateVaultGold(order.cityId, orderFee, true);
    // fee is always smaller than orderValue (<= 100%)
    CharacterFundUtils.increaseGold(takerId, orderValue - orderFee);
  }

  function _handleBuyOrderTakerWithCrystal(uint256 takerId, OrderData memory order, uint32 orderValue) private {
    uint32 platformFee = uint32(PlatformUtils.getPlatformFee(orderValue));
    uint32 finalOrderValue = orderValue - platformFee;
    if (platformFee > 0) {
      PlatformUtils.updateAppTeamCrystal(platformFee, true);
    }
    uint32 orderFee = calculateOrderFee(takerId, order.cityId, finalOrderValue, CurrencyType.Crystal);
    // fee will be sent to taker city vault, and kingdom fee is based on taker kingdom,
    // so we use takerId to calculate fee
    uint256 takerCapitalId = KingdomUtils.getCapitalIdByCharacterId(takerId);
    CityVaultUtils.updateVaultCrystal(takerCapitalId, orderFee, true);
    if (orderFee > 0) {
      PlatformUtils.updateAppVaultCrystal(orderFee, true);
    }
    // fee is always smaller than finalOrderValue (<= 100%)
    CharacterFundUtils.increaseCrystal(takerId, finalOrderValue - orderFee);
  }
}
