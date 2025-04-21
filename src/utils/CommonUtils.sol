library CommonUtils {
  /// @dev Returns the new weight after applying a weight change.
  function getNewWeight(
    uint32 currentWeight,
    uint32 weightChange,
    bool isReduce
  ) internal pure returns (uint32) {
    if (!isReduce) {
      return currentWeight + weightChange;
    } 
    if (weightChange > currentWeight) {
      // This might happen if we increase weight of an item
      // and then remove it from the inventory
      return 0;
    }
    return currentWeight - weightChange;
  }

  /// @dev Wraps a single uint256 into a one-element array.
  function wrapUint256(uint256 value) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](1);
    arr[0] = value;
  }

  /// @dev Wraps a single uint32 into a one-element array.
  function wrapUint32(uint32 value) internal pure returns (uint32[] memory arr) {
    arr = new uint32[](1);
    arr[0] = value;
  }
}