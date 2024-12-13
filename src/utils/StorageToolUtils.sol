pragma solidity >=0.8.24;

import { CharStorage, StorageToolIndex } from "@codegen/index.sol";
import { StorageWeightUtils } from "./StorageWeightUtils.sol";
import { Errors } from "@common/Errors.sol";

library StorageToolUtils {
  /// @dev Add tools to storage
  function addTools(uint256 characterId, uint256 cityId, uint256[] memory toolIds) public {
    for (uint256 i = 0; i < toolIds.length; i++) {
      _addTool(characterId, cityId, toolIds[i]);
    }
    StorageWeightUtils.addTools(characterId, cityId, toolIds);
  }

  /// @dev Add tool to storage
  function addTool(uint256 characterId, uint256 cityId, uint256 toolId) public {
    _addTool(characterId, cityId, toolId);
    StorageWeightUtils.addTool(characterId, cityId, toolId);
  }

  function _addTool(uint256 characterId, uint256 cityId, uint256 toolId) private {
    if (hasTool(characterId, cityId, toolId)) {
      revert Errors.Tool_AlreadyHad(characterId, toolId);
    }
    CharStorage.pushToolIds(characterId, cityId, toolId);
    // The value is stored at length-1, but we add 1 to all indexes
    // and use 0 as a sentinel value
    uint256 index = CharStorage.lengthToolIds(characterId, cityId);
    StorageToolIndex.set(characterId, cityId, toolId, index);
  }

  /// @dev Remove tool from storage
  function removeTools(uint256 characterId, uint256 cityId, uint256[] memory toolIds) public {
    for (uint256 i = 0; i < toolIds.length; i++) {
      _removeTool(characterId, cityId, toolIds[i]);
    }
    StorageWeightUtils.removeTools(characterId, cityId, toolIds);
  }

  /// @dev Remove tool from storage
  function removeTool(uint256 characterId, uint256 cityId, uint256 toolId) public {
    _removeTool(characterId, cityId, toolId);
    StorageWeightUtils.removeTool(characterId, cityId, toolId);
  }

  function _removeTool(uint256 characterId, uint256 cityId, uint256 toolId) private {
    uint256 index = StorageToolIndex.get(characterId, cityId, toolId);
    if (index == 0) revert Errors.Tool_NotOwned(characterId, toolId);
    // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
    // the array, and then remove the last element (sometimes called as 'swap and pop').
    // This modifies the order of the array, as noted in {at}.
    uint256 valueIndex = index - 1;
    uint256 lastIndex = CharStorage.lengthToolIds(characterId, cityId) - 1;
    if (valueIndex != lastIndex) {
      uint256 lastValue = CharStorage.getItemToolIds(characterId, cityId, lastIndex);
      CharStorage.updateToolIds(characterId, cityId, valueIndex, lastValue);
      StorageToolIndex.set(characterId, cityId, lastValue, index);
    }
    CharStorage.popToolIds(characterId, cityId);
    StorageToolIndex.deleteRecord(characterId, cityId, toolId);
  }

  /// @dev Return whether the character has the tool in storag
  function hasTool(uint256 characterId, uint256 cityId, uint256 toolId) public view returns (bool) {
    uint256 index = StorageToolIndex.get(characterId, cityId, toolId);
    return index != 0;
  }
}
