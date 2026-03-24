pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import {
  CharState,
  CharInventory,
  CharInventoryData,
  CharPositionFull,
  CharPositionFullData,
  CharStorage,
  CharStorageData,
  CharFarmingState,
  CharFarmingStateData,
  PvEAfk,
  PvEAfkData,
  PvEAfkLoc,
  CharStats,
  CharStatsData,
  CharCurrentStats,
  CharCurrentStatsData,
  CharEquipment,
  CharOtherItem
} from "@codegen/index.sol";
import { SlotType } from "@codegen/common.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { Errors } from "@common/Errors.sol";

contract RescueSystem is System, CharacterAccessControl {
  uint8 constant MAX_SLOT_TYPE = uint8(SlotType.Ring);

  /// @dev re-update data to update indexer
  function rescue(uint256 characterId, uint256[] calldata cityIds, uint256[] calldata inventoryOtherItemIds) public {
    // Position
    CharPositionFullData memory positionData = CharPositionFull.get(characterId);
    CharPositionFull.set(characterId, positionData);

    // State
    _rescueState(characterId, positionData);

    // Stats
    _rescueStats(characterId);

    // Current Stats
    _rescueCurrentStats(characterId);

    // Inventory
    CharInventoryData memory inventory = CharInventory.get(characterId);
    CharInventory.set(characterId, inventory);

    // Equipped Equipment
    _rescueEquipment(characterId);

    // Inventory Other Items
    _rescueInventoryOtherItem(characterId, inventoryOtherItemIds);

    // Storage
    _rescueStorage(characterId, cityIds);
  }

  function _rescueStorage(uint256 characterId, uint256[] calldata cityIds) private {
    for (uint256 i = 0; i < cityIds.length; i++) {
      uint256 cityId = cityIds[i];
      CharStorageData memory storageData = CharStorage.get(characterId, cityId);
      CharStorage.set(characterId, cityId, storageData);
    }
  }

  function _rescueEquipment(uint256 characterId) private {
    for (uint8 i = 0; i <= MAX_SLOT_TYPE; i++) {
      uint256 equipmentId = CharEquipment.getEquipmentId(characterId, SlotType(i));
      CharEquipment.setEquipmentId(characterId, SlotType(i), equipmentId);
    }
  }

  function _rescueState(uint256 characterId, CharPositionFullData memory positionData) private {
    CharState.setState(characterId, CharState.getState(characterId));
    CharFarmingStateData memory farmingState = CharFarmingState.get(characterId);
    CharFarmingState.set(characterId, farmingState);
    PvEAfkData memory pveAfk = PvEAfk.get(characterId);
    PvEAfk.set(characterId, pveAfk);
    uint256 monsterId = PvEAfkLoc.get(positionData.nextX, positionData.nextY);
    PvEAfkLoc.set(positionData.nextX, positionData.nextY, monsterId);
  }

  function _rescueStats(uint256 characterId) private {
    CharStatsData memory stats = CharStats.get(characterId);
    CharStats.set(characterId, stats);
  }

  function _rescueCurrentStats(uint256 characterId) private {
    CharCurrentStatsData memory currentStats = CharCurrentStats.get(characterId);
    CharCurrentStats.set(characterId, currentStats);
  }

  function _rescueInventoryOtherItem(uint256 characterId, uint256[] calldata inventoryOtherItemIds) private {
    for (uint256 i = 0; i < inventoryOtherItemIds.length; i++) {
      uint256 otherItemId = inventoryOtherItemIds[i];
      uint32 amount = CharOtherItem.get(characterId, otherItemId);
      CharOtherItem.set(characterId, otherItemId, amount);
    }
  }
}
