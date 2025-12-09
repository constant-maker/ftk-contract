pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import {
  CharState,
  CharInventory,
  CharInventoryData,
  CharPosition,
  CharPositionData,
  CharNextPosition,
  CharNextPositionData,
  CharStorage,
  CharStorageData,
  CharFarmingState,
  CharFarmingStateData,
  PvEAfk,
  PvEAfkData,
  PvEAfkLoc,
  CharStats,
  CharStatsData,
  CharStats2,
  CharCurrentStats,
  CharCurrentStatsData,
  CharCStats2,
  CharEquipment
} from "@codegen/index.sol";
import { SlotType } from "@codegen/common.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { Errors } from "@common/Errors.sol";

contract RescueSystem is System, CharacterAccessControl {
  /// @dev re-update data to update indexer
  function rescue(uint256 characterId, uint256[] calldata cityIds) public {
    // Position
    CharPositionData memory position = CharPosition.get(characterId);
    CharPosition.set(characterId, position);
    CharNextPositionData memory nextPosition = CharNextPosition.get(characterId);
    CharNextPosition.set(characterId, nextPosition);

    // State
    CharState.setState(characterId, CharState.getState(characterId));
    CharFarmingStateData memory farmingState = CharFarmingState.get(characterId);
    CharFarmingState.set(characterId, farmingState);
    PvEAfkData memory pveAfk = PvEAfk.get(characterId);
    PvEAfk.set(characterId, pveAfk);
    uint256 monsterId = PvEAfkLoc.get(nextPosition.x, nextPosition.y);
    if (monsterId != 0) {
      PvEAfkLoc.set(nextPosition.x, nextPosition.y, monsterId);
    }

    // Stats
    CharStatsData memory stats = CharStats.get(characterId);
    CharStats.set(characterId, stats);
    CharStats2.set(characterId, CharStats2.get(characterId));

    // Current Stats
    CharCurrentStatsData memory currentStats = CharCurrentStats.get(characterId);
    CharCurrentStats.set(characterId, currentStats);
    CharCStats2.set(characterId, CharCStats2.get(characterId));

    // Inventory
    CharInventoryData memory inventory = CharInventory.get(characterId);
    CharInventory.set(characterId, inventory);

    // Equipped Equipment
    _rescueEquipment(characterId);

    // Storage
    for (uint256 i = 0; i < cityIds.length; i++) {
      uint256 cityId = cityIds[i];
      CharStorageData memory storageData = CharStorage.get(characterId, cityId);
      CharStorage.set(characterId, cityId, storageData);
    }
  }

  function _rescueEquipment(uint256 characterId) private {
    for (uint8 i = 0; i <= uint8(SlotType.Mount); i++) {
      uint256 equipmentId = CharEquipment.getEquipmentId(characterId, SlotType(i));
      if (equipmentId == 0) {
        continue;
      }
      CharEquipment.setEquipmentId(characterId, SlotType(i), equipmentId);
    }
  }
}
