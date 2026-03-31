pragma solidity >=0.8.24;

import { StatType } from "@codegen/common.sol";

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

struct IncreaseStatData {
  StatType statType;
  uint16 amount;
}

struct NpcTradeData {
  uint256 itemId;
  uint32 amount;
}
