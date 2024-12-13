pragma solidity >=0.8.24;

import { Tool2, Tool2Data } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";

library ToolUtils {
  /// @dev Return tool data, revert if it is not exist
  function mustGetToolData(uint256 toolId) internal view returns (Tool2Data memory toolData) {
    toolData = Tool2.get(toolId);
    if (toolData.itemId == 0) {
      revert Errors.Tool_NotExisted(toolId);
    }
    return toolData;
  }
}
