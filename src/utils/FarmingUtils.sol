pragma solidity >=0.8.24;

import {
  CharPositionData,
  TileInfo3,
  Item,
  ItemData,
  CharPerk,
  Tool2Data,
  TileInfo3,
  TileInfo3Data,
  ResourceInfo,
  ExpAmpConfig,
  CharExpAmp,
  CharExpAmpData
} from "@codegen/index.sol";
import { ResourceType, ItemType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";

library FarmingUtils {
  /// @dev Validate tile
  function validateTile(CharPositionData memory characterPosition, uint256 resourceItemId) public view {
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

  /// @dev Check and update the farming quota
  function checkAndUpdateTileQuota(CharPositionData memory characterPosition, uint256 resourceItemId) public {
    int32 x = characterPosition.x;
    int32 y = characterPosition.y;
    TileInfo3Data memory tileInfo = TileInfo3.get(x, y);
    uint256[] memory itemIds = tileInfo.itemIds;
    uint256 lenItem = itemIds.length;

    if (tileInfo.farmingQuotas.length != itemIds.length || block.timestamp > tileInfo.replenishTime) {
      // Initialize quotas if they haven't been set or after replenish time
      uint16[] memory quotas = new uint16[](lenItem);

      for (uint256 i = 0; i < lenItem; i++) {
        uint256 itemId = itemIds[i];
        uint16 tier = Item.getTier(itemId);
        uint16 quota;
        if (tier <= 5) {
          quota = 20 - (tier - 1) * 2;
        } else {
          quota = uint16((11 - tier) * 12 / 10); // scaled up by 1.2x
        }
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
        uint16 newQuota = tileInfo.farmingQuotas[i] - 1;
        TileInfo3.updateFarmingQuotas(x, y, i, newQuota);
        break;
      }
    }
  }

  /// @dev Calculate resource perk exp
  function calculateResourcePerkExp(uint256 characterId, uint256 resourceItemId) public view returns (uint32 perkExp) {
    uint32 tier = uint32(Item.getTier(resourceItemId));
    perkExp = Config.BASE_RESOURCE_PERK_EXP * tier + (tier - 1) * 2; // all tier starts from 1
    uint32 basePercent = 100;
    uint32 farmingPerkAmp = ExpAmpConfig.getFarmingPerkAmp();
    uint256 ampExpireTime = ExpAmpConfig.getExpireTime();
    if (block.timestamp <= ampExpireTime) {
      basePercent += farmingPerkAmp;
    }
    CharExpAmpData memory charExpAmp = CharExpAmp.get(characterId);
    if (block.timestamp <= charExpAmp.expireTime) {
      basePercent += charExpAmp.farmingPerkAmp;
    }
    return (perkExp * basePercent) / 100;
  }

  /// @dev Validate resource and tool
  function validateResourceAndTool(
    uint256 characterId,
    ResourceType resourceType,
    uint8 resourceItemTier,
    Tool2Data memory tool,
    uint256 toolId
  )
    public
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
    if (resourceType != getResourceTypeByItemType(item.itemType)) {
      revert Errors.Tool_InvalidItemType(resourceType, item.itemType);
    }
    if (item.tier < resourceItemTier) {
      revert Errors.Tool_TierNotSatisfied(resourceItemTier, item.tier);
    }
    if (tool.durability < requireDurability) {
      revert Errors.Tool_InsufficientDurability(toolId);
    }
    return (item.itemType, requireDurability);
  }

  function getResourceTypeByItemType(ItemType itemType) public pure returns (ResourceType) {
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

  function getResourceItemAndResourceType(uint256 resourceItemId)
    public
    returns (ItemData memory resourceItem, ResourceType resourceType)
  {
    resourceItem = Item.get(resourceItemId);
    if (resourceItem.itemType != ItemType.Resource) {
      revert Errors.FarmingSystem_MustFarmAResource(resourceItemId);
    }
    resourceType = ResourceInfo.getResourceType(resourceItemId);
    if (resourceType == ResourceType.MonsterLoot) {
      revert Errors.FarmingSystem_MonsterLootResourceNeedHunting();
    }
    return (resourceItem, resourceType);
  }
}
