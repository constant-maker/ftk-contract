pragma solidity >=0.8.24;

import { TileInfo3 } from "@codegen/index.sol";

library TileUtils {
  uint8 public constant MAX_FARM_SLOT = 10;
  uint8 public constant DEFAULT_INCREASE_FARM_SLOT = 2;

  /// @dev increase farm slot
  function increaseFarmSlot(int32 x, int32 y) internal {
    _updateFarmSlot(x, y, true);
  }

  /// @dev decrease farm slot
  function decreaseFarmSlot(int32 x, int32 y) internal {
    _updateFarmSlot(x, y, false);
  }

  /// @dev update farm slot increase or decrease
  function _updateFarmSlot(int32 x, int32 y, bool isIncreased) private {
    uint8 farmSlot = TileInfo3.getFarmSlot(x, y);
    if (isIncreased) {
      if (farmSlot == MAX_FARM_SLOT) return;
      farmSlot += DEFAULT_INCREASE_FARM_SLOT;
      if (farmSlot > MAX_FARM_SLOT) {
        farmSlot = MAX_FARM_SLOT;
      }
    } else {
      if (farmSlot == 0) return;
      farmSlot--;
    }
    TileInfo3.setFarmSlot(x, y, farmSlot);
  }
}
