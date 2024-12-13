pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharPosition, CharPositionData, CharNextPosition, CharNextPositionData } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharacterItemUtils } from "@utils/CharacterItemUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { Item, ItemData } from "@codegen/tables/Item.sol";
import { NpcShop } from "@codegen/tables/NpcShop.sol";
import { NpcShopInventory } from "@codegen/tables/NpcShopInventory.sol";
import { ItemCategoryType, ItemType } from "@codegen/common.sol";
import { TradeData } from "./NpcShopSystem.sol";

struct TradeData {
  uint256 itemId;
  uint32 amount;
}

contract NpcShopSystem is CharacterAccessControl, System {
  uint32 constant INIT_SHOP_BALANCE = 20_000; // 20000 golds
  uint32 constant TOOL_PRICE = 25; // 25 golds
  uint32 constant BUY_BACK_MULTIPLY = 3;

  function tradeWithNpc(
    uint256 characterId,
    uint256 cityId,
    TradeData[] calldata buyData,
    TradeData[] calldata sellData
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    CharacterPositionUtils.MustInCity(characterId, cityId);
    uint32 goldCost = _buyFromNpc(characterId, cityId, buyData);
    uint32 goldEarn = _sellToNpc(characterId, cityId, sellData);
    if (goldCost > goldEarn) {
      CharacterFundUtils.decreaseGold(characterId, goldCost - goldEarn);
    } else {
      CharacterFundUtils.increaseGold(characterId, goldEarn - goldCost);
    }
  }

  function _buyFromNpc(
    uint256 characterId,
    uint256 cityId,
    TradeData[] calldata data
  )
    private
    returns (uint32 goldCost)
  {
    if (data.length == 0) return 0;
    for (uint256 i; i < data.length; i++) {
      uint256 itemId = data[i].itemId;
      uint32 amount = data[i].amount;
      ItemData memory itemData = Item.get(itemId);
      if (itemData.category == ItemCategoryType.Tool) {
        if (itemData.tier != 1) revert Errors.NpcShopSystem_OnlySellTierOneTool(itemId);
        goldCost += TOOL_PRICE * amount;
        _addTools(characterId, itemId, amount);
      } else if (itemData.category == ItemCategoryType.Other) {
        goldCost += itemData.tier * BUY_BACK_MULTIPLY * amount;
        InventoryItemUtils.addItem(characterId, itemId, amount);
        _updateNpcInventory(cityId, itemId, amount, false);
      }
    }
    _increaseNpcGold(cityId, goldCost);
    return goldCost;
  }

  function _sellToNpc(uint256 characterId, uint256 cityId, TradeData[] calldata data) private returns (uint32 goldEarn) {
    if (data.length == 0) return 0;
    uint32 npcBalance = NpcShop.getGold(cityId);
    uint32 minTierToBuy;
    for (uint256 i; i < data.length; i++) {
      uint256 itemId = data[i].itemId;
      uint32 amount = data[i].amount;
      if (Item.getCategory(itemId) != ItemCategoryType.Other) {
        revert Errors.NpcShopSystem_OnlyAcceptOtherItem(itemId);
      }
      InventoryItemUtils.removeItem(characterId, itemId, amount); // this func already check character item balance
      uint8 itemTier = Item.getTier(itemId);
      uint32 earn = itemTier * amount;
      if (earn > npcBalance) {
        revert Errors.NpcShopSystem_NotEnoughGold(cityId, npcBalance, earn);
      }
      npcBalance -= earn;
      goldEarn += earn;
      minTierToBuy = npcBalance >= INIT_SHOP_BALANCE ? 1 : (10 - npcBalance * 10 / INIT_SHOP_BALANCE);
      if (itemTier < minTierToBuy) {
        revert Errors.NpcShopSystem_ItemTierTooLow(cityId, itemId, npcBalance);
      }
      _updateNpcInventory(cityId, itemId, amount, true);
    }
    NpcShop.setGold(cityId, npcBalance);
    return goldEarn;
  }

  function _addTools(uint256 characterId, uint256 itemId, uint32 amount) private {
    for (uint256 i = 0; i < amount; i++) {
      CharacterItemUtils.addNewItem(characterId, itemId);
    }
  }

  function _increaseNpcGold(uint256 cityId, uint32 amount) private {
    uint32 npcBalance = NpcShop.getGold(cityId);
    NpcShop.setGold(cityId, npcBalance + amount);
  }

  function _updateNpcInventory(uint256 cityId, uint256 itemId, uint32 amount, bool isGained) private {
    uint32 currentAmount = NpcShopInventory.getAmount(cityId, itemId);
    if (!isGained && currentAmount < amount) {
      revert Errors.NpcShopSystem_NotEnoughItem(cityId, itemId, currentAmount);
    }
    if (currentAmount == 0) {
      NpcShopInventory.set(cityId, itemId, cityId, amount);
    } else {
      uint32 newAmount = isGained ? currentAmount + amount : currentAmount - amount;
      NpcShopInventory.setAmount(cityId, itemId, newAmount);
    }
  }
}
