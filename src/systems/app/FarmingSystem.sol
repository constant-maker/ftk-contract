pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import {
  CharPositionData,
  CharState,
  Item,
  ItemData,
  CharFarmingState,
  CharFarmingStateData,
  ResourceInfo
} from "@codegen/index.sol";
import {
  CharacterStateUtils,
  CharacterStatsUtils,
  CharacterPerkUtils,
  ToolUtils,
  DailyQuestUtils,
  TileUtils,
  CharacterPositionUtils,
  InventoryToolUtils,
  FarmingUtils,
  InventoryItemUtils
} from "@utils/index.sol";
import { Tool2, Tool2Data } from "@codegen/index.sol";
import { CharacterStateType, ResourceType, ItemType } from "@codegen/common.sol";
import { CharacterAccessControl } from "@abstracts/index.sol";
import { Errors, Config } from "@common/index.sol";

contract FarmingSystem is CharacterAccessControl, System {
  /// @dev Start farming resourceItemId for a specific character
  function startFarming(
    uint256 characterId,
    uint256 resourceItemId,
    uint256 toolId,
    bool claimResource
  )
    public
    onlyAuthorizedWallet(characterId)
    mustInState(characterId, CharacterStateType.Standby)
  {
    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    // ensure the tile has enough farming slot and resource
    FarmingUtils.validateTile(characterPosition, resourceItemId);
    FarmingUtils.checkAndUpdateTileQuota(characterPosition, resourceItemId);
    // check if character has tool
    _validateTool(characterId, toolId);
    _startFarming(characterId, toolId, resourceItemId, claimResource, characterPosition);
  }

  /// @dev Finish the current farming state for character, anyone can call this function so make sure to avoid any
  /// ownership interaction
  function finishFarming(
    uint256 characterId,
    bool continueFarming,
    bool claimResource
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    CharacterStateUtils.checkLastActionFinished(characterId, CharacterStateType.Farming);

    CharFarmingStateData memory characterFarmingState = CharFarmingState.get(characterId);
    uint256 resourceItemId = characterFarmingState.itemId;

    if (resourceItemId == 0) {
      revert Errors.FarmingSystem_NoCurrentFarming(characterId);
    }

    // increase the character resource amount in inventory
    uint256 timestamp = block.timestamp;
    if (claimResource) {
      uint32 receiveAmount = _calculateFarmingAmount(Item.getTier(resourceItemId));
      InventoryItemUtils.addItem(characterId, resourceItemId, receiveAmount);
    }

    // change character state to standby
    CharState.set(characterId, CharacterStateType.Standby, timestamp);

    // reset last farming state, set resourceItemId to zero
    CharFarmingState.setItemId(characterId, 0);

    // update character perk
    CharacterPerkUtils.updateCharacterPerkExp(
      characterId, characterFarmingState.itemType, FarmingUtils.calculateResourcePerkExp(resourceItemId)
    );

    // check and update daily quest
    DailyQuestUtils.updateFarmCount(characterId);

    if (continueFarming) {
      startFarming(characterId, resourceItemId, characterFarmingState.toolId, claimResource);
    }
  }

  function _startFarming(
    uint256 characterId,
    uint256 toolId,
    uint256 resourceItemId,
    bool claimResource,
    CharPositionData memory characterPosition
  )
    private
  {
    (ItemData memory resourceItem, ResourceType resourceType) =
      FarmingUtils.getResourceItemAndResourceType(resourceItemId);

    Tool2Data memory tool = ToolUtils.mustGetToolData(toolId);
    // ensure using the right tool, enough tool durability
    (ItemType itemType, uint16 requireDurability) =
      FarmingUtils.validateResourceAndTool(characterId, resourceType, resourceItem.tier, tool, toolId);

    // check if the resourceItem weight is exceed the character max weight
    if (claimResource) {
      CharacterStatsUtils.validateWeight(characterId, _calculateFarmingAmount(resourceItem.tier) * resourceItem.weight);
    }

    // update tool durability
    _updateTool(toolId, tool, requireDurability);
    // update tile farming slot
    TileUtils.decreaseFarmSlot(characterPosition.x, characterPosition.y);
    // update character state
    _updateState(characterId, toolId, resourceItemId, itemType);
  }

  function _updateState(uint256 characterId, uint256 toolId, uint256 resourceItemId, ItemType itemType) private {
    // set character state
    CharState.set(characterId, CharacterStateType.Farming, block.timestamp);
    // save last farming resourceItemId
    CharFarmingState.set(characterId, resourceItemId, toolId, itemType);
  }

  function _calculateFarmingAmount(uint8 itemTier) private pure returns (uint32) {
    return Config.AMOUNT_RECEIVE_FROM_FARMING - (itemTier - 1) / 2;
  }

  function _validateTool(uint256 characterId, uint256 toolId) private view {
    if (!InventoryToolUtils.hasTool(characterId, toolId)) {
      revert Errors.Tool_NotOwned(characterId, toolId);
    }
  }

  function _updateTool(uint256 toolId, Tool2Data memory tool, uint16 requireDurability) private {
    if (tool.durability == requireDurability) {
      Tool2.deleteRecord(toolId); // hook will auto remove the tool from player inventory
    } else {
      Tool2.setDurability(toolId, tool.durability - requireDurability);
    }
  }
}
