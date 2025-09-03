pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  TileInfo3,
  TileInfo3Data,
  TileInventory,
  Equipment,
  CharNextPosition,
  CharPosition,
  CharPositionData,
  CharInfo,
  CharStats2,
  KingSetting
} from "@codegen/index.sol";
import { ZoneType } from "@codegen/common.sol";
import {
  InventoryItemUtils,
  CharacterFundUtils,
  CharacterPositionUtils,
  TileInventoryUtils,
  InventoryEquipmentUtils,
  KingdomUtils
} from "@utils/index.sol";
import { Errors, Config } from "@common/index.sol";
import { LootItems } from "./TileSystem.sol";

struct LootItems {
  uint256[] equipmentIds;
  uint256[] itemIds;
  uint32[] itemAmounts;
}

contract TileSystem is System, CharacterAccessControl {
  uint32 constant TILE_OCCUPATION_COST = 5; // gold
  uint32 constant TILE_OCCUPATION_RESOURCE_AMOUNT = 10;
  uint32 constant TILE_LOCKED_DURATION = 28_800; // 8 hours (second)
  uint32 constant TILE_OCCUPATION_DURATION_REQUIRE = 300; // 5 minutes (second)

  /// @dev Occupy a tile to expand your kingdom area
  function occupyTile(uint256 characterId) public onlyAuthorizedWallet(characterId) {
    CharPositionData memory position = CharacterPositionUtils.currentPosition(characterId);
    int32 x = position.x;
    int32 y = position.y;
    uint256 occupiedTime = TileInfo3.getOccupiedTime(x, y);
    if (block.timestamp < occupiedTime + TILE_LOCKED_DURATION) {
      revert Errors.TileSystem_TileIsLocked(x, y, occupiedTime);
    }
    uint8 kingdomId = CharInfo.getKingdomId(characterId);
    uint8 tileKingdomId = TileInfo3.getKingdomId(x, y);
    if (tileKingdomId == kingdomId) {
      revert Errors.TileSystem_TileAlreadyOccupied(x, y);
    }
    if (tileKingdomId != 0 && tileKingdomId != kingdomId) {
      uint256 arriveTimestamp = CharNextPosition.getArriveTimestamp(characterId);
      if (arriveTimestamp + TILE_OCCUPATION_DURATION_REQUIRE >= block.timestamp) {
        revert Errors.TileSystem_TileIsNotReadyToOccupy(x, y, arriveTimestamp);
      }
    }
    _checkTileNearBy(x, y, kingdomId);
    CharacterFundUtils.decreaseGold(characterId, TILE_OCCUPATION_COST);
    uint256[] memory itemIds = _getRequiredItemIds(x, y);
    uint32[] memory amounts = new uint32[](itemIds.length);
    for (uint256 i = 0; i < itemIds.length; i++) {
      amounts[i] = TILE_OCCUPATION_RESOURCE_AMOUNT;
    }
    bool isAlliance = KingdomUtils.getIsAlliance(kingdomId, tileKingdomId);
    InventoryItemUtils.removeItems(characterId, itemIds, amounts);
    // Set new tile data
    TileInfo3.setKingdomId(x, y, kingdomId);
    // increase fame
    uint32 currentFame = CharStats2.getFame(characterId);
    if (currentFame == 0) {
      currentFame = 1000; // default
    }
    if (isAlliance) {
      uint16 captureTilePenalty = KingSetting.getCaptureTilePenalty(kingdomId);
      if (captureTilePenalty > 0) {
        currentFame = currentFame > captureTilePenalty ? currentFame - captureTilePenalty : 1; // min fame is 1
      }
    } else {
      currentFame += 10;
    }
    CharStats2.setFame(characterId, currentFame);
    TileInfo3.setOccupiedTime(x, y, block.timestamp);
  }

  function lootItems(uint256 characterId, LootItems calldata data) public onlyAuthorizedWallet(characterId) {
    if (data.itemIds.length != data.itemAmounts.length) {
      revert("Invalid input: itemIds and itemAmounts");
    }
    CharPositionData memory position = CharacterPositionUtils.currentPosition(characterId);
    int32 x = position.x;
    int32 y = position.y;
    uint256 lastDropTime = TileInventory.getLastDropTime(x, y);
    if (lastDropTime + Config.TILE_ITEM_AVAILABLE_DURATION < block.timestamp) {
      revert Errors.TileSystem_NoItemInThisTile(x, y, lastDropTime);
    }
    for (uint256 i = 0; i < data.equipmentIds.length; i++) {
      uint256 equipmentId = data.equipmentIds[i];
      TileInventoryUtils.removeEquipment(x, y, equipmentId);
      Equipment.setCharacterId(equipmentId, characterId);
      InventoryEquipmentUtils.addEquipment(characterId, equipmentId, true);
    }
    if (data.itemIds.length > 0) {
      for (uint256 i = 0; i < data.itemIds.length; i++) {
        uint256 itemId = data.itemIds[i];
        if (!TileInventoryUtils.hasItem(x, y, itemId)) {
          revert Errors.TileSystem_ItemNotFound(x, y, itemId);
        }
      }
      TileInventoryUtils.removeItems(x, y, data.itemIds, data.itemAmounts);
      InventoryItemUtils.addItems(characterId, data.itemIds, data.itemAmounts);
    }
  }

  function _checkTileNearBy(int32 x, int32 y, uint8 kingdomId) private view {
    if (TileInfo3.getKingdomId(x - 1, y) == kingdomId) {
      return;
    }
    if (TileInfo3.getKingdomId(x + 1, y) == kingdomId) {
      return;
    }
    if (TileInfo3.getKingdomId(x, y - 1) == kingdomId) {
      return;
    }
    if (TileInfo3.getKingdomId(x, y + 1) == kingdomId) {
      return;
    }
    revert Errors.TileSystem_NoValidTileNearBy(x, y);
  }

  function _getRequiredItemIds(int32 x, int32 y) private view returns (uint256[] memory) {
    uint256[] memory itemIds = new uint256[](3);
    ZoneType zoneType = TileInfo3.getZoneType(x, y);
    if ((x + y) % 2 == 0) {
      if (zoneType == ZoneType.Black) {
        itemIds[0] = 3; // Wood tier 3
        itemIds[1] = 78; // Stone tier 3
        itemIds[2] = 86; // Fish tier 3
      } else {
        itemIds[0] = 1; // Wood tier 1
        itemIds[1] = 6; // Stone tier 1
        itemIds[2] = 8; // Fish tier 1
      }
    } else {
      if (zoneType == ZoneType.Black) {
        itemIds[0] = 94; // Ore tier 3
        itemIds[1] = 102; // Wheat tier 3
        itemIds[2] = 110; // Berries tier 3
      } else {
        itemIds[0] = 10; // Ore tier 1
        itemIds[1] = 12; // Wheat tier 1
        itemIds[2] = 14; // Berries tier 1
      }
    }
    return itemIds;
  }
}
