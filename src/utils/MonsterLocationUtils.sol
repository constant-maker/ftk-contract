pragma solidity >=0.8.24;

import { TileInfo3, MonsterIndexLocation } from "@codegen/index.sol";

library MonsterLocationUtils {
  /// @dev Add monsters to location
  function addMonsters(int32[] memory xArr, int32[] memory yArr, uint256[] memory monsterIds) internal {
    for (uint256 i = 0; i < monsterIds.length; i++) {
      uint256 monsterId = monsterIds[i];
      int32 x = xArr[i];
      int32 y = yArr[i];
      addMonster(x, y, monsterId);
    }
  }

  /// @dev Add monster to location
  function addMonster(int32 x, int32 y, uint256 monsterId) internal returns (bool) {
    if (!hasMonster(x, y, monsterId)) {
      TileInfo3.pushMonsterIds(x, y, monsterId);
      // The value is stored at length-1, but we add 1 to all indexes
      // and use 0 as a sentinel value
      uint256 index = TileInfo3.lengthMonsterIds(x, y);
      MonsterIndexLocation.set(x, y, monsterId, index);
      return true;
    } else {
      return false;
    }
  }

  /// @dev Remove monster from inventory for character
  function removeMonster(int32 x, int32 y, uint256 monsterId) internal returns (bool) {
    uint256 index = MonsterIndexLocation.get(x, y, monsterId);

    if (index != 0) {
      // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
      // the array, and then remove the last element (sometimes called as 'swap and pop').
      // This modifies the order of the array, as noted in {at}.
      uint256 valueIndex = index - 1;
      uint256 lastIndex = TileInfo3.lengthMonsterIds(x, y) - 1;
      if (valueIndex != lastIndex) {
        uint256 lastValue = TileInfo3.getItemMonsterIds(x, y, lastIndex);
        TileInfo3.updateMonsterIds(x, y, valueIndex, lastValue);
        MonsterIndexLocation.set(x, y, lastValue, index);
      }
      TileInfo3.popMonsterIds(x, y);
      MonsterIndexLocation.deleteRecord(x, y, monsterId);
      return true;
    } else {
      return false;
    }
  }

  /// @dev Return whether the has the monster in the location
  function hasMonster(int32 x, int32 y, uint256 monsterId) private view returns (bool) {
    uint256 index = MonsterIndexLocation.get(x, y, monsterId);
    return index != 0;
  }
}
