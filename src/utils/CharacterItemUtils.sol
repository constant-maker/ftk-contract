pragma solidity >=0.8.24;

import {
  Item,
  ItemData,
  Tool,
  ToolData,
  ToolSupply,
  Equipment,
  EquipmentData,
  EquipmentSupply,
  CharPerk
} from "@codegen/index.sol";
import { ItemCategoryType, ItemType } from "@codegen/common.sol";
import { InventoryItemUtils } from "./InventoryItemUtils.sol";
import { InventoryToolUtils } from "./InventoryToolUtils.sol";
import { InventoryEquipmentUtils } from "./InventoryEquipmentUtils.sol";
import { CharacterPerkUtils } from "./CharacterPerkUtils.sol";
import { Errors } from "@common/index.sol";
import { Config } from "@common/Config.sol";

library CharacterItemUtils {
  uint16 public constant DEFAULT_TOOL_DURABILITY = 50;

  /// @dev add new item to character inventory, with tool and equipment, hook will add them to inventory
  function addNewItem(uint256 characterId, uint256 itemId, uint32 amount) internal {
    ItemData memory item = Item.get(itemId);
    if (item.tier == 0) {
      revert Errors.Item_NotExisted(itemId);
    }
    if (item.category == ItemCategoryType.Other) {
      InventoryItemUtils.addItem(characterId, itemId, amount);
      return;
    }
    // item is tool or equipment
    for (uint32 i = 0; i < amount; i++) {
      if (item.category == ItemCategoryType.Tool) {
        // get new tool id
        uint256 newToolId = ToolSupply.get() + 1;
        ToolData memory toolData = ToolData({
          itemId: itemId,
          characterId: characterId,
          durability: uint16(item.tier) * DEFAULT_TOOL_DURABILITY
        });
        Tool.set(newToolId, toolData);
        InventoryToolUtils.addTool(characterId, newToolId);
        ToolSupply.set(newToolId);
      } else {
        // get new equipment id
        uint256 newEquipmentId = EquipmentSupply.get() + 1;
        EquipmentData memory equipmentData =
          EquipmentData({ itemId: itemId, characterId: characterId, authorId: characterId, level: 1 });
        Equipment.set(newEquipmentId, equipmentData);
        InventoryEquipmentUtils.addEquipment(characterId, newEquipmentId, true);
        EquipmentSupply.set(newEquipmentId);
      }
    }
  }
}
