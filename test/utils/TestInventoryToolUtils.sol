pragma solidity >=0.8.24;

import { Item, Tool, ToolData, ToolSupply, CharInventory, InvToolIndex } from "@codegen/index.sol";
import { CharacterWeightUtils } from "@utils/CharacterWeightUtils.sol";
import { Errors } from "@common/Errors.sol";

library TestInventoryToolUtils {
  uint16 constant DEFAULT_TOOL_DURABILITY = 50;

  function addNewTool(uint256 characterId, uint256 itemId, uint32 amount) internal {
    uint16 durability = uint16(Item.getTier(itemId)) * DEFAULT_TOOL_DURABILITY;

    for (uint32 i = 0; i < amount; i++) {
      uint256 newToolId = ToolSupply.get() + 1;
      ToolData memory toolData = ToolData({ itemId: itemId, characterId: characterId, durability: durability });
      Tool.set(newToolId, toolData);
      _addTool(characterId, newToolId);
      CharacterWeightUtils.addTool(characterId, newToolId);
      ToolSupply.set(newToolId);
    }
  }

  function hasTool(uint256 characterId, uint256 toolId) internal view returns (bool) {
    return InvToolIndex.get(characterId, toolId) != 0;
  }

  function _addTool(uint256 characterId, uint256 toolId) private {
    if (InvToolIndex.get(characterId, toolId) != 0) {
      revert Errors.Tool_AlreadyHad(characterId, toolId);
    }

    CharInventory.pushToolIds(characterId, toolId);
    // The value is stored at length-1, but we add 1 to all indexes and use 0 as a sentinel value.
    uint256 index = CharInventory.lengthToolIds(characterId);
    InvToolIndex.set(characterId, toolId, index);
  }
}