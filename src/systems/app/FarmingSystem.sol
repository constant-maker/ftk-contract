pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import {
  CharPositionData,
  CharState,
  Item,
  ItemData,
  CharFarmingState,
  CharFarmingStateData,
  CharPerk,
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
  InventoryToolUtils
} from "@utils/index.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { Tool2, Tool2Data } from "@codegen/index.sol";
import { TileInfo3, TileInfo3Data } from "@codegen/tables/TileInfo3.sol";
import { Item, ItemData } from "@codegen/tables/Item.sol";
import { CharacterStateType, ResourceType, ItemType } from "@codegen/common.sol";
import { CharacterAccessControl } from "@abstracts/index.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";

contract FarmingSystem is CharacterAccessControl, System {
  /// @dev Start farming resourceItemId for a specific character
  function startFarming(
    uint256 characterId,
    uint256 resourceItemId,
    uint256 toolId
  )
    public
    onlyAuthorizedWallet(characterId)
    mustInState(characterId, CharacterStateType.Standby)
  {
    ItemData memory resourceItem = Item.get(resourceItemId);
    if (resourceItem.itemType != ItemType.Resource) {
      revert Errors.FarmingSystem_MustFarmAResource(resourceItemId);
    }
    ResourceType resourceType = ResourceInfo.getResourceType(resourceItemId);
    if (resourceType == ResourceType.MonsterLoot) {
      revert Errors.FarmingSystem_MonsterLootResourceNeedHunting();
    }

    CharPositionData memory characterPosition = CharacterPositionUtils.currentPosition(characterId);
    // ensure the tile has enough farming slot and resource
    _validateTile(characterPosition, resourceItemId);
    _checkTileQuota(characterPosition, resourceItemId);

    if (!InventoryToolUtils.hasTool(characterId, toolId)) {
      revert Errors.Tool_NotOwned(characterId, toolId);
    }

    Tool2Data memory tool = ToolUtils.mustGetToolData(toolId);

    // ensure using the right tool, enough tool durability
    (ItemType itemType, uint16 requireDurability) =
      _validateResourceAndTool(characterId, resourceType, resourceItem.tier, tool);

    // check if the resourceItem weight is exceed the character max weight
    CharacterStatsUtils.validateWeight(characterId, _calculateFarmingAmount(resourceItem.tier) * resourceItem.weight);

    // update tool durability
    if (tool.durability == requireDurability) {
      InventoryToolUtils.removeTool(characterId, toolId);
    } else {
      Tool2.setDurability(toolId, tool.durability - requireDurability);
    }

    // reduce farm slot
    TileUtils.decreaseFarmSlot(characterPosition.x, characterPosition.y);

    // set character state
    CharState.set(characterId, CharacterStateType.Farming, block.timestamp);

    // save last farming resourceItemId
    CharFarmingState.set(characterId, resourceItemId, toolId, itemType);
  }

  /// @dev Finish the current farming state for character, anyone can call this function so make sure to avoid any
  /// ownership interaction
  function finishFarming(uint256 characterId, bool continueFarming) public onlyAuthorizedWallet(characterId) {
    CharacterStateUtils.checkLastActionFinished(characterId, CharacterStateType.Farming);

    CharFarmingStateData memory characterFarmingState = CharFarmingState.get(characterId);
    uint256 resourceItemId = characterFarmingState.itemId;

    if (resourceItemId == 0) {
      revert Errors.FarmingSystem_NoCurrentFarming(characterId);
    }

    // increase the character resource amount in inventory
    uint256 timestamp = block.timestamp;
    uint32 receiveAmount = _calculateFarmingAmount(Item.getTier(resourceItemId));
    InventoryItemUtils.addItem(characterId, resourceItemId, receiveAmount);

    // change character state to standby
    CharState.set(characterId, CharacterStateType.Standby, timestamp);

    // reset last farming state, set resourceItemId to zero
    CharFarmingState.setItemId(characterId, 0);

    // update character perk
    CharacterPerkUtils.updateCharacterPerkExp(
      characterId, characterFarmingState.itemType, _calculateResourcePerkExp(resourceItemId)
    );

    // check and update daily quest
    DailyQuestUtils.updateFarmCount(characterId);

    if (continueFarming) {
      startFarming(characterId, resourceItemId, characterFarmingState.toolId);
    }
  }

  function _calculateFarmingAmount(uint8 itemTier) private pure returns (uint32) {
    return Config.AMOUNT_RECEIVE_FROM_FARMING - (itemTier - 1) / 2;
  }

  /// @dev Check the farming quota
  function _checkTileQuota(CharPositionData memory characterPosition, uint256 resourceItemId) private {
    int32 x = characterPosition.x;
    int32 y = characterPosition.y;
    TileInfo3Data memory tileInfo = TileInfo3.get(x, y);
    uint256[] memory itemIds = tileInfo.itemIds;
    uint256 lenItem = itemIds.length;

    if (tileInfo.farmingQuotas.length == 0 || block.timestamp > tileInfo.replenishTime) {
      // Initialize quotas if they haven't been set or after replenish time
      uint16[] memory quotas = new uint16[](lenItem);

      for (uint256 i = 0; i < lenItem; i++) {
        uint256 itemId = itemIds[i];
        uint16 quota = 20 - (Item.getTier(itemId) - 1) * 2; // Min tier is 1, Max tier is 10
        quotas[i] = quota;
      }

      tileInfo.farmingQuotas = quotas;

      // Update quota and replenish time
      TileInfo3.setFarmingQuotas(x, y, quotas);
      TileInfo3.setReplenishTime(x, y, block.timestamp + 3 hours);
    }

    // Check quota for the specified resourceItemId
    for (uint256 i = 0; i < lenItem; i++) {
      if (resourceItemId == itemIds[i]) {
        if (tileInfo.farmingQuotas[i] == 0) {
          revert Errors.FarmingSystem_ExceedFarmingQuota(x, y, resourceItemId);
        }
        // Decrease quota and store updated value
        tileInfo.farmingQuotas[i]--;
        TileInfo3.setFarmingQuotas(x, y, tileInfo.farmingQuotas);
        break;
      }
    }
  }

  /// @dev Validate tile
  function _validateTile(CharPositionData memory characterPosition, uint256 resourceItemId) private view {
    int32 x = characterPosition.x;
    int32 y = characterPosition.y;
    if (TileInfo3.getFarmSlot(x, y) == 0) {
      revert Errors.FarmingSystem_NoFarmSlot(x, y);
    }
    uint256[] memory itemIds = TileInfo3.getItemIds(x, y);
    bool hasResource = false;
    for (uint256 i = 0; i < itemIds.length; i++) {
      if (itemIds[i] == resourceItemId) {
        hasResource = true;
        break;
      }
    }
    if (!hasResource) {
      revert Errors.FarmingSystem_NoResourceInCurrentTile(x, y, resourceItemId);
    }
  }

  /// @dev Calculate resource perk exp
  function _calculateResourcePerkExp(uint256 resourceItemId) private view returns (uint32 perkExp) {
    uint8 tier = Item.getTier(resourceItemId);
    return Config.BASE_RESOURCE_PERK_EXP * tier + (tier - 1) * 2; // all tier starts from 1
  }

  /// @dev Validate resource and tool
  function _validateResourceAndTool(
    uint256 characterId,
    ResourceType resourceType,
    uint8 resourceItemTier,
    Tool2Data memory tool
  )
    private
    view
    returns (ItemType itemType, uint16 requireDurability)
  {
    ItemData memory item = Item.get(tool.itemId);
    requireDurability = uint16(resourceItemTier);
    uint8 perkLevel = CharPerk.getLevel(characterId, item.itemType);
    if (perkLevel + 1 < resourceItemTier) {
      // perk starts from zero
      revert Errors.FarmingSystem_PerkLevelTooLow(perkLevel, resourceItemTier);
    }
    if (resourceType != _getResourceTypeByItemType(item.itemType)) {
      revert Errors.Tool_InvalidItemType(resourceType, item.itemType);
    }
    if (item.tier < resourceItemTier) {
      revert Errors.Tool_TierNotSatisfied(resourceItemTier, item.tier);
    }
    if (tool.durability < requireDurability) {
      revert Errors.Tool_InsufficientDurability();
    }
    return (item.itemType, requireDurability);
  }

  function _getResourceTypeByItemType(ItemType itemType) private pure returns (ResourceType) {
    if (itemType == ItemType.WoodAxe) {
      return ResourceType.Wood;
    } else if (itemType == ItemType.StoneHammer) {
      return ResourceType.Stone;
    } else if (itemType == ItemType.FishingRod) {
      return ResourceType.Fish;
    } else if (itemType == ItemType.Pickaxe) {
      return ResourceType.Ore;
    } else if (itemType == ItemType.Sickle) {
      return ResourceType.Wheat;
    } else if (itemType == ItemType.BerryShears) {
      return ResourceType.Berry;
    } else {
      return ResourceType.MonsterLoot;
    }
  }
}
