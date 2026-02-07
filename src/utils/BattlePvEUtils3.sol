pragma solidity >=0.8.24;

import {
  CharPositionData,
  MonsterLocation,
  MonsterLocationData,
  Monster,
  PvE,
  PvEExtraV2,
  PvEExtraV2Data,
  BossInfo,
  BossInfoData,
  MonsterStats,
  CharCurrentStats,
  CharStats,
  ItemV2,
  CharCStats2
} from "@codegen/index.sol";
import { CharacterFundUtils } from "./CharacterFundUtils.sol";
import { InventoryItemUtils } from "./InventoryItemUtils.sol";
import { AdvantageType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";

library BattlePvEUtils3 {
  uint256 constant KALYNDRA_ID = 42;
  uint256 constant BEOWULF_ID = 43;

  function handleBossResult(
    uint256 characterId,
    uint256 monsterId,
    uint32 monsterHp,
    CharPositionData memory charPosition
  )
    public
  {
    if (!Monster.getIsBoss(monsterId)) {
      return;
    }
    int32 x = charPosition.x;
    int32 y = charPosition.y;
    if (monsterHp == 0) {
      CharacterFundUtils.increaseCrystal(characterId, BossInfo.getCrystal(monsterId, x, y));
      BossInfo.setHp(monsterId, x, y, MonsterStats.getHp(monsterId));
      BossInfo.setLastDefeatedTime(monsterId, x, y, block.timestamp);
      switchBossColor(x, y, monsterId);
      // switch location for specific bosses
      if (monsterId == KALYNDRA_ID) {
        // Kalyndra
        switchBossLocation(18, -1, -28, 17, monsterId, charPosition);
      } else if (monsterId == BEOWULF_ID) {
        // Beowulf
        switchBossLocation(9, 34, -31, -39, monsterId, charPosition);
      }
    } else {
      BossInfo.setHp(monsterId, x, y, monsterHp);
    }
  }

  function switchBossLocation(
    int32 x1,
    int32 y1,
    int32 x2,
    int32 y2,
    uint256 monsterId,
    CharPositionData memory charPosition
  )
    public
  {
    int32 x = charPosition.x;
    int32 y = charPosition.y;
    int32 newX = x == x1 ? x2 : x1;
    int32 newY = y == y1 ? y2 : y1;
    MonsterLocationData memory currentMonsterLocation = MonsterLocation.get(x, y, monsterId);
    MonsterLocation.deleteRecord(x, y, monsterId); // delete old location
    MonsterLocation.set(newX, newY, monsterId, currentMonsterLocation);
    BossInfoData memory currentBossInfo = BossInfo.get(monsterId, x, y);
    BossInfo.deleteRecord(monsterId, x, y); // delete old boss info
    BossInfo.set(monsterId, newX, newY, currentBossInfo);
  }

  function switchBossColor(int32 x, int32 y, uint256 monsterId) public {
    AdvantageType currentAdvantage = MonsterLocation.getAdvantageType(x, y, monsterId);
    // cycle through advantage types
    // e.g current is blue ~ 2 then new is grey ~ (2 + 1) % (3 + 1) = 3
    uint8 newAdvantage = (uint8(currentAdvantage) + 1) % (uint8(AdvantageType.Grey) + 1);
    MonsterLocation.setAdvantageType(x, y, monsterId, AdvantageType(newAdvantage));
  }

  function claimReward(uint256 characterId, uint256 monsterId) public {
    uint256[] memory itemIds = Monster.getItemIds(monsterId);
    uint32[] memory itemAmounts = Monster.getItemAmounts(monsterId);
    if (itemIds.length == 0) {
      return;
    }
    if (itemIds.length != itemAmounts.length) {
      revert Errors.Monster_InvalidResourceData(monsterId, itemIds.length, itemAmounts.length);
    }
    uint256 index;
    if (itemIds.length > 1) {
      index = PvE.getCounter(characterId) % itemIds.length;
    }
    uint256 itemId = itemIds[index];
    uint32 amount = itemAmounts[index];
    uint32 itemWeight = ItemV2.getWeight(itemId);
    uint32 newWeight = CharCurrentStats.getWeight(characterId) + itemWeight * amount;
    uint32 maxWeight = CharStats.getWeight(characterId);
    if (newWeight > maxWeight) {
      revert Errors.Character_WeightsExceed(newWeight, maxWeight);
    }
    InventoryItemUtils.addItem(characterId, itemId, amount);
    storePvEExtraData(characterId, itemId, amount);
  }

  function storePvEExtraData(uint256 characterId, uint256 rewardItemId, uint32 rewardItemAmount) public {
    PvEExtraV2Data memory pveExtra = PvEExtraV2Data({
      itemId: rewardItemId,
      itemAmount: rewardItemAmount,
      characterBarrier: CharCStats2.getBarrier(characterId)
    });
    PvEExtraV2.set(characterId, pveExtra);
  }
}
