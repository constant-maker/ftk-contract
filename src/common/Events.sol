pragma solidity >=0.8.24;

library Events {
  event CharacterCreated(uint256 indexed characterId, address indexed wallet, uint256 timestamp);
  event PositionChanged(
    uint256 indexed characterId, int32 x, int32 y, int32 nextX, int32 nextY, uint256 arriveTimestamp
  );
}
