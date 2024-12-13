pragma solidity >=0.8.24;

import { StoreHook } from "@latticexyz/store/src/StoreHook.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EncodedLengths } from "@latticexyz/store/src/EncodedLengths.sol";
import { FieldLayout } from "@latticexyz/store/src/FieldLayout.sol";
import { Tool2, Tool2Data } from "@codegen/index.sol";
import { InventoryToolUtils } from "@utils/index.sol";

/// Hook only work when we set the whole fields data like Tool2.set(...)

contract ToolHook is StoreHook {
  function onAfterSetRecord(
    ResourceId tableId,
    bytes32[] memory keyTuple,
    bytes memory staticData,
    EncodedLengths encodedLengths,
    bytes memory dynamicData,
    FieldLayout fieldLayout
  )
    public
    override
  {
    Tool2Data memory tool = Tool2.decode(staticData, encodedLengths, dynamicData);
    uint256 toolId = uint256(keyTuple[0]);
    uint256 characterId = tool.characterId;
    if (InventoryToolUtils.hasTool(characterId, toolId)) {
      return;
    }
    InventoryToolUtils.addTool(characterId, toolId);
  }

  function onBeforeDeleteRecord(ResourceId tableId, bytes32[] memory keyTuple, FieldLayout fieldLayout) public override {
    uint256 toolId = uint256(keyTuple[0]);
    Tool2Data memory tool = Tool2.get(toolId);
    InventoryToolUtils.removeTool(tool.characterId, toolId);
  }
}
