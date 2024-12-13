pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { TileInfo3, TileInfo3Data } from "@codegen/tables/TileInfo3.sol";
import { CharPosition, CharPositionData } from "@codegen/tables/CharPosition.sol";
import { CharInfo } from "@codegen/tables/CharInfo.sol";
import { CharStats2 } from "@codegen/tables/CharStats2.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { Errors } from "@common/Errors.sol";

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
    uint256[] memory itemIds = TileInfo3.getItemIds(x, y);
    if (itemIds.length > 0) {
      uint32[] memory amounts = new uint32[](itemIds.length);
      for (uint256 i = 0; i < itemIds.length; i++) {
        amounts[i] = TILE_OCCUPATION_RESOURCE_AMOUNT;
      }
      InventoryItemUtils.removeItems(characterId, itemIds, amounts);
    }
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
}
