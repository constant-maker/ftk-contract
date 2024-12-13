pragma solidity >=0.8.24;

import { CharInventory, InventoryToolIndex } from "@codegen/index.sol";
import { CharacterWeightUtils } from "@utils/CharacterWeightUtils.sol";
import { Errors } from "@common/Errors.sol";

library InventoryToolUtils {
  /// @dev Add tools to inventory for character
  function addTools(uint256 characterId, uint256[] memory toolIds) public {
    for (uint256 i = 0; i < toolIds.length; i++) {
      _addTool(characterId, toolIds[i]);
    }
    CharacterWeightUtils.addTools(characterId, toolIds);
  }

  /// @dev Add tool to inventory for character
  function addTool(uint256 characterId, uint256 toolId) public {
    _addTool(characterId, toolId);
    CharacterWeightUtils.addTool(characterId, toolId);
  }

  function _addTool(uint256 characterId, uint256 toolId) private {
    if (hasTool(characterId, toolId)) {
      revert Errors.Tool_AlreadyHad(characterId, toolId);
    }
    CharInventory.pushToolIds(characterId, toolId);
    // The value is stored at length-1, but we add 1 to all indexes
    // and use 0 as a sentinel value
    uint256 index = CharInventory.lengthToolIds(characterId);
    InventoryToolIndex.set(characterId, toolId, index);
  }

  /// @dev Remove tool from inventory for character
  function removeTools(uint256 characterId, uint256[] memory toolIds) public {
    for (uint256 i = 0; i < toolIds.length; i++) {
      _removeTool(characterId, toolIds[i]);
    }
    CharacterWeightUtils.removeTools(characterId, toolIds);
  }

  /// @dev Remove tool from inventory for character
  function removeTool(uint256 characterId, uint256 toolId) public {
    _removeTool(characterId, toolId);
    CharacterWeightUtils.removeTool(characterId, toolId);
  }

  function _removeTool(uint256 characterId, uint256 toolId) private {
    uint256 index = InventoryToolIndex.get(characterId, toolId);
    if (index == 0) revert Errors.Tool_NotOwned(characterId, toolId);
    // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
    // the array, and then remove the last element (sometimes called as 'swap and pop').
    // This modifies the order of the array, as noted in {at}.
    uint256 valueIndex = index - 1;
    uint256 lastIndex = CharInventory.lengthToolIds(characterId) - 1;
    if (valueIndex != lastIndex) {
      uint256 lastValue = CharInventory.getItemToolIds(characterId, lastIndex);
      CharInventory.updateToolIds(characterId, valueIndex, lastValue);
      InventoryToolIndex.set(characterId, lastValue, index);
    }
    CharInventory.popToolIds(characterId);
    InventoryToolIndex.deleteRecord(characterId, toolId);
  }

  /// @dev Return whether the character has the tool in inventory
  function hasTool(uint256 characterId, uint256 toolId) public view returns (bool) {
    uint256 index = InventoryToolIndex.get(characterId, toolId);
    return index != 0;
  }
}
