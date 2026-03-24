pragma solidity >=0.8.24;

import { Tile, MonsterLocIndex } from "@codegen/index.sol";

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
      Tile.pushMonsterIds(x, y, monsterId);
      // The value is stored at length-1, but we add 1 to all indexes
      // and use 0 as a sentinel value
      uint256 index = Tile.lengthMonsterIds(x, y);
      MonsterLocIndex.set(x, y, monsterId, index);
      return true;
    } else {
      return false;
    }
  }

  /// @dev Remove monster from inventory for character
  function removeMonster(int32 x, int32 y, uint256 monsterId) internal returns (bool) {
    uint256 index = MonsterLocIndex.get(x, y, monsterId);

    if (index != 0) {
      // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
      // the array, and then remove the last element (sometimes called as 'swap and pop').
      // This modifies the order of the array, as noted in {at}.
      uint256 valueIndex = index - 1;
      uint256 lastIndex = Tile.lengthMonsterIds(x, y) - 1;
      if (valueIndex != lastIndex) {
        uint256 lastValue = Tile.getItemMonsterIds(x, y, lastIndex);
        Tile.updateMonsterIds(x, y, valueIndex, lastValue);
        MonsterLocIndex.set(x, y, lastValue, index);
      }
      Tile.popMonsterIds(x, y);
      MonsterLocIndex.deleteRecord(x, y, monsterId);
      return true;
    } else {
      return false;
    }
  }

  /// @dev Return whether the has the monster in the location
  function hasMonster(int32 x, int32 y, uint256 monsterId) private view returns (bool) {
    uint256 index = MonsterLocIndex.get(x, y, monsterId);
    return index != 0;
  }
}
