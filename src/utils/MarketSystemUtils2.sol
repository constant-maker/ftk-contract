pragma solidity >=0.8.24;

import { InventoryEquipmentUtils } from "./InventoryEquipmentUtils.sol";
import { CharacterFundUtils } from "./CharacterFundUtils.sol";
import { KingdomUtils } from "./KingdomUtils.sol";
import { CityVaultUtils } from "./CityVaultUtils.sol";
import { PlatformUtils } from "./PlatformUtils.sol";
import {
  Order2,
  OrderData,
  CharMarketWeight,
  CharOtherItem,
  CharFund,
  Item,
  CharInfo,
  City,
  MarketFee,
  CrystalFee,
  MarketCrystal
} from "@codegen/index.sol";
import { ItemCategoryType, CurrencyType } from "@codegen/common.sol";
import { Errors, Config } from "@common/index.sol";

library MarketSystemUtils2 {
  function validateMarketCrystalRule(uint256 itemId, uint32 unitPrice, CurrencyType currency) public view {
    uint32 minCrystalPrice = MarketCrystal.getMinUnitPrice(itemId);
    if (minCrystalPrice == 0) {
      return;
    }
    if (currency != CurrencyType.Crystal) {
      revert Errors.MarketSystem_ItemMustBeTradedWithCrystal(itemId);
    }
    if (unitPrice < minCrystalPrice) {
      revert Errors.MarketSystem_CrystalPriceTooLow(itemId, unitPrice, minCrystalPrice);
    }
  }

  function validateSellOrder(
    uint256 characterId,
    uint256 cityId,
    uint256 equipmentId,
    uint256 itemId,
    uint32 amount
  )
    public
    view
  {
    validateMarketWeight(characterId, cityId, itemId, amount);
    if (equipmentId != 0) {
      if (!InventoryEquipmentUtils.hasEquipment(characterId, equipmentId)) {
        revert Errors.Equipment_NotOwned(characterId, equipmentId);
      }
      return;
    }
    if (CharOtherItem.getAmount(characterId, itemId) < amount) {
      revert Errors.MarketSystem_InsufficientItem(characterId, itemId, amount);
    }
  }

  function updateBuyOrder(uint256 characterId, uint256 orderId, OrderData memory existingOrder, uint32 newUnitPrice) public {
    if (Order2.getCurrency(orderId) == CurrencyType.Gold) {
      _updateBuyOrderGold(characterId, existingOrder, newUnitPrice);
    } else {
      _updateBuyOrderCrystal(characterId, existingOrder, newUnitPrice);
    }
  }

  function validateBuyOrder(uint256 characterId, CurrencyType currency, uint32 unitPrice, uint32 amount) public view {
    if (currency == CurrencyType.Gold) {
      uint32 charGold = CharFund.getGold(characterId);
      uint32 totalGold = unitPrice * amount;
      if (charGold < totalGold) {
        revert Errors.InsufficientGold(charGold, totalGold);
      }
      return;
    }

    uint256 charCrystal = CharFund.getCrystal(characterId);
    uint256 totalCrystal = unitPrice * amount;
    if (charCrystal < totalCrystal) {
      revert Errors.InsufficientCrystal(charCrystal, totalCrystal);
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

  function validateMarketWeight(uint256 characterId, uint256 cityId, uint256 itemId, uint32 amount) public view {
    uint32 currentWeight = CharMarketWeight.getWeight(characterId, cityId);
    uint32 maxWeight = CharMarketWeight.getMaxWeight(characterId, cityId);
    uint32 itemWeight = Item.getWeight(itemId);
    uint32 totalWeight = currentWeight + (itemWeight * amount);
    if (totalWeight > maxWeight) {
      revert Errors.MarketSystem_ExceedMaxWeight(characterId, cityId, totalWeight, maxWeight);
    }
  }

  function handleSellOrderTakerBalance(uint256 takerId, OrderData memory order, uint256 orderId, uint32 amount) public {
    uint32 orderValue = order.unitPrice * amount;
    if (Order2.getCurrency(orderId) == CurrencyType.Gold) {
      CharacterFundUtils.decreaseGold(takerId, orderValue);
      _handleSellOrderTakerWithGold(order, orderValue);
    } else {
      CharacterFundUtils.decreaseCrystal(takerId, orderValue);
      _handleSellOrderTakerWithCrystal(order, orderValue);
    }
  }

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
      feePercentage = CrystalFee.getFee(characterKingdomId);
    } else {
      feePercentage = MarketFee.getFee(marketKingdomId, characterKingdomId);
    }
    if (feePercentage == 0) {
      return 0;
    }
    return value * uint32(feePercentage) / 100;
  }

  function handleBuyOrderTakerBalance(uint256 takerId, OrderData memory order, uint256 orderId, uint32 amount) public {
    uint32 orderValue = order.unitPrice * amount;
    if (Order2.getCurrency(orderId) == CurrencyType.Gold) {
      _handleBuyOrderTakerWithGold(takerId, order, orderValue);
    } else {
      _handleBuyOrderTakerWithCrystal(takerId, order, orderValue);
    }
  }

  function _updateBuyOrderGold(uint256 characterId, OrderData memory existingOrder, uint32 newUnitPrice) private {
    uint32 charGold = CharFund.getGold(characterId);
    if (existingOrder.unitPrice < newUnitPrice) {
      uint32 goldChange = (newUnitPrice - existingOrder.unitPrice) * existingOrder.amount;
      if (goldChange > charGold) {
        revert Errors.InsufficientGold(charGold, goldChange);
      }
      CharacterFundUtils.decreaseGold(characterId, goldChange);
    } else {
      uint32 goldChange = (existingOrder.unitPrice - newUnitPrice) * existingOrder.amount;
      CharacterFundUtils.increaseGold(characterId, goldChange);
    }
  }

  function _updateBuyOrderCrystal(uint256 characterId, OrderData memory existingOrder, uint32 newUnitPrice) private {
    uint256 charCrystal = CharFund.getCrystal(characterId);
    if (existingOrder.unitPrice < newUnitPrice) {
      uint256 crystalChange = (newUnitPrice - existingOrder.unitPrice) * existingOrder.amount;
      if (crystalChange > charCrystal) {
        revert Errors.InsufficientCrystal(charCrystal, crystalChange);
      }
      CharacterFundUtils.decreaseCrystal(characterId, crystalChange);
    } else {
      uint256 crystalChange = (existingOrder.unitPrice - newUnitPrice) * existingOrder.amount;
      CharacterFundUtils.increaseCrystal(characterId, crystalChange);
    }
  }

  function _validateCrystalPrice(uint32 orderPrice) private pure {
    if (orderPrice < Config.MIN_CRYSTALS_PER_PURCHASE || orderPrice % Config.MIN_CRYSTALS_PER_PURCHASE != 0) {
      revert Errors.InvalidCrystalAmount(uint256(orderPrice), Config.MIN_CRYSTALS_PER_PURCHASE);
    }
  }

  function _handleSellOrderTakerWithGold(OrderData memory order, uint32 orderValue) private {
    uint32 orderFee = calculateOrderFee(order.characterId, order.cityId, orderValue, CurrencyType.Gold);
    CharacterFundUtils.increaseGold(order.characterId, orderValue - orderFee);
    CityVaultUtils.updateVaultGold(order.cityId, orderFee, true);
  }

  function _handleSellOrderTakerWithCrystal(OrderData memory order, uint32 orderValue) private {
    uint32 platformFee = uint32(PlatformUtils.getPlatformFee(orderValue));
    uint32 finalOrderValue = orderValue - platformFee;
    if (platformFee > 0) {
      PlatformUtils.updateAppTeamCrystal(platformFee, true);
    }
    uint32 orderFee = calculateOrderFee(order.characterId, order.cityId, finalOrderValue, CurrencyType.Crystal);
    uint256 capitalId = KingdomUtils.getCapitalIdByCharacterId(order.characterId);
    CityVaultUtils.updateVaultCrystal(capitalId, orderFee, true);
    if (orderFee > 0) {
      PlatformUtils.updateAppVaultCrystal(orderFee, true);
    }
    CharacterFundUtils.increaseCrystal(order.characterId, finalOrderValue - orderFee);
  }

  function _handleBuyOrderTakerWithGold(uint256 takerId, OrderData memory order, uint32 orderValue) private {
    uint32 orderFee = calculateOrderFee(takerId, order.cityId, orderValue, CurrencyType.Gold);
    CityVaultUtils.updateVaultGold(order.cityId, orderFee, true);
    CharacterFundUtils.increaseGold(takerId, orderValue - orderFee);
  }

  function _handleBuyOrderTakerWithCrystal(uint256 takerId, OrderData memory order, uint32 orderValue) private {
    uint32 platformFee = uint32(PlatformUtils.getPlatformFee(orderValue));
    uint32 finalOrderValue = orderValue - platformFee;
    if (platformFee > 0) {
      PlatformUtils.updateAppTeamCrystal(platformFee, true);
    }
    uint32 orderFee = calculateOrderFee(takerId, order.cityId, finalOrderValue, CurrencyType.Crystal);
    uint256 takerCapitalId = KingdomUtils.getCapitalIdByCharacterId(takerId);
    CityVaultUtils.updateVaultCrystal(takerCapitalId, orderFee, true);
    if (orderFee > 0) {
      PlatformUtils.updateAppVaultCrystal(orderFee, true);
    }
    CharacterFundUtils.increaseCrystal(takerId, finalOrderValue - orderFee);
  }
}