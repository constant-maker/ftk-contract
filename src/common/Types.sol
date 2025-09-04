pragma solidity >=0.8.24;

/// @dev common struct to transfer, drop, ... items
struct ItemsActionData {
  uint256[] equipmentIds;
  uint256[] toolIds;
  uint256[] itemIds;
  uint32[] itemAmounts;
}

struct EquipmentSnapshotData {
  uint32 barrier;
  uint32 hp;
  uint16 atk;
  uint16 def;
  uint16 agi;
  uint16 ms;
  uint32 weight; // bonus weight
}
