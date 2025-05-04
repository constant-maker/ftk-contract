pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { TileInfo3, TileInfo3Data, TileInventory } from "@codegen/index.sol";
import { CharPosition, CharPositionData } from "@codegen/tables/CharPosition.sol";
import { CharInfo } from "@codegen/tables/CharInfo.sol";
import { CharStats2 } from "@codegen/tables/CharStats2.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  InventoryItemUtils,
  CharacterFundUtils,
  CharacterPositionUtils,
  TileInventoryUtils,
  InventoryEquipmentUtils
} from "@utils/index.sol";
import { Errors, Config } from "@common/index.sol";
import { LootItems } from "./TileSystem.sol";

struct LootItems {
  uint256[] equipmentIndexes;
  uint256[] itemIndexes;
  uint32[] itemAmounts;
}

contract TileSystem is System, CharacterAccessControl {
  uint32 constant TILE_OCCUPATION_COST = 5; // gold
  uint32 constant TILE_OCCUPATION_RESOURCE_AMOUNT = 10;
  uint32 constant TILE_LOCKED_DURATION = 3600; // 1 hour (second)

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
    _checkTileNearBy(x, y, kingdomId);
    CharacterFundUtils.decreaseGold(characterId, TILE_OCCUPATION_COST);
    uint256[] memory itemIds = _getRequiredItemIds(x, y);
    uint32[] memory amounts = new uint32[](itemIds.length);
    for (uint256 i = 0; i < itemIds.length; i++) {
      amounts[i] = TILE_OCCUPATION_RESOURCE_AMOUNT;
    }
    InventoryItemUtils.removeItems(characterId, itemIds, amounts);
    // Set new tile data
    uint8 tileKingdomId = TileInfo3.getKingdomId(x, y);
    if (kingdomId != tileKingdomId) {
      TileInfo3.setKingdomId(x, y, kingdomId);
      // increase fame
      uint32 currentFame = CharStats2.getFame(characterId);
      if (currentFame == 0) {
        currentFame = 1000; // default
      }
      CharStats2.setFame(characterId, currentFame + 10);
    }
    TileInfo3.setOccupiedTime(x, y, block.timestamp);
  }

  function lootItems(uint256 characterId, LootItems calldata data) public onlyAuthorizedWallet(characterId) {
    if (data.itemIndexes.length != data.itemAmounts.length) {
      revert("Invalid input: itemIndexes and itemAmounts");
    }
    CharPositionData memory position = CharacterPositionUtils.currentPosition(characterId);
    int32 x = position.x;
    int32 y = position.y;
    uint256 lastDropTime = TileInventory.getLastDropTime(x, y);
    if (lastDropTime + Config.TILE_ITEM_AVAILABLE_DURATION < block.timestamp) {
      revert Errors.TileSystem_NoItemInThisTile(x, y, lastDropTime);
    }
    for (uint256 i = 0; i < data.equipmentIndexes.length; i++) {
      uint256 equipmentIndex = data.equipmentIndexes[i];
      if (equipmentIndex >= TileInventory.lengthEquipmentIds(x, y)) {
        revert Errors.TileSystem_EquipmentNotFound(x, y, equipmentIndex);
      }
      uint256 equipmentId = TileInventory.getItemEquipmentIds(x, y, equipmentIndex);
      TileInventoryUtils.removeEquipment(x, y, equipmentIndex);
      InventoryEquipmentUtils.addEquipment(characterId, equipmentId, true);
    }
    if (data.itemIndexes.length > 0) {
      uint256[] memory itemIds = new uint256[](data.itemIndexes.length);
      for (uint256 i = 0; i < data.itemIndexes.length; i++) {
        uint256 index = data.itemIndexes[i];
        if (index >= TileInventory.lengthOtherItemIds(x, y)) {
          revert Errors.TileSystem_ItemNotFound(x, y, index);
        }
        itemIds[i] = TileInventory.getItemOtherItemIds(x, y, index);
      }
      TileInventoryUtils.removeItems(x, y, itemIds, data.itemAmounts);
      InventoryItemUtils.addItems(characterId, itemIds, data.itemAmounts);
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

  function _getRequiredItemIds(int32 x, int32 y) private pure returns (uint256[] memory) {
    uint256[] memory itemIds = new uint256[](3);
    if ((x + y) % 2 == 0) {
      itemIds[0] = 1; // Wood tier 1
      itemIds[1] = 6; // Stone tier 1
      itemIds[2] = 8; // Fish tier 1
    } else {
      itemIds[0] = 10; // Ore tier 1
      itemIds[1] = 12; // Wheat tier 1
      itemIds[2] = 14; // Berries tier 1
    }
    return itemIds;
  }
}
