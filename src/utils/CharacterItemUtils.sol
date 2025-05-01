pragma solidity >=0.8.24;

import {
  Item,
  ItemData,
  Tool2,
  Tool2Data,
  ToolSupply,
  Equipment,
  EquipmentData,
  EquipmentSupply,
  CharPerk,
  CharMigration,
  CharStorageMigration
} from "@codegen/index.sol";
import { ItemCategoryType, ItemType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { Config } from "@common/Config.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";

library CharacterItemUtils {
  uint16 public constant DEFAULT_TOOL_DURABILITY = 50;

  /// @dev Check whether character perk level is enough to equip item
  function checkCharacterPerkLevelByItemId(uint256 characterId, uint256 itemId) internal view {
    ItemData memory item = Item.get(itemId);
    checkCharacterPerkLevel(characterId, item);
  }

  /// @dev Check whether character perk level is enough to equip item
  function checkCharacterPerkLevel(uint256 characterId, ItemData memory item) internal view {
    uint8 perkLevel = CharPerk.getLevel(characterId, item.itemType);
    // plus 1 to perkLevel because it started from zero
    if (perkLevel + 1 < item.tier) {
      revert Errors.Character_PerkLevelTooLow(characterId, perkLevel, item.itemType, item.tier);
    }
  }

  /// @dev add new item to character inventory
  function addNewItem(uint256 characterId, uint256 itemId) internal {
    ItemData memory item = Item.get(itemId);
    if (item.category == ItemCategoryType.Tool) {
      // get current tool supply
      uint256 newToolId = ToolSupply.get() + 1;
      Tool2Data memory toolData =
        Tool2Data({ itemId: itemId, characterId: characterId, durability: uint16(item.tier) * DEFAULT_TOOL_DURABILITY });
      Tool2.set(newToolId, toolData);
      ToolSupply.set(newToolId);
    } else if (item.category == ItemCategoryType.Equipment) {
      uint256 newEquipmentId = EquipmentSupply.get() + 1;
      EquipmentData memory equipmentData =
        EquipmentData({ itemId: itemId, characterId: characterId, level: 1, counter: 0 });
      Equipment.set(newEquipmentId, equipmentData);
      EquipmentSupply.set(newEquipmentId);
      if (newEquipmentId < Config.MAX_EQUIPMENT_ID_TO_CHECK_CACHE_WEIGHT) {
        // This is only for the migration, we will remove this in the future
        CharMigration.set(characterId, newEquipmentId, true);
        CharStorageMigration.set(characterId, newEquipmentId, true);
      }
    } else if (item.category == ItemCategoryType.Other) {
      InventoryItemUtils.addItem(characterId, itemId, 1);
    }
  }
}
