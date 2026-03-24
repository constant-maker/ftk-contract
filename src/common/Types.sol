pragma solidity >=0.8.24;

/// @dev common struct to transfer, drop, ... items
struct ItemsActionData {
  uint256[] equipmentIds;
  uint256[] toolIds;
  uint256[] itemIds;
  uint32[] itemAmounts;
}

struct VaultActionParams {
  uint32 gold;
  uint256 crystal;
  uint256[] itemIds;
  uint32[] amounts;
}
