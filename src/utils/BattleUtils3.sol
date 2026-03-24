pragma solidity >=0.8.24;

import { CharInventory, Item, Equipment } from "@codegen/index.sol";
import { ZoneType, CharacterStateType, ItemType } from "@codegen/common.sol";

library BattleUtils3 {
  /// @dev get up to 2 equipments that can be dropped when character lost
  function getDropEquipment(uint256 characterId) public view returns (uint256[] memory) {
    uint256[] memory equipmentIds = CharInventory.getEquipmentIds(characterId);

    uint256 oLen = equipmentIds.length;
    uint256[] memory petExcludedEquipmentIds = new uint256[](oLen);

    uint256 count;

    for (uint256 i; i < oLen; i++) {
      uint256 equipmentId = equipmentIds[i];

      ItemType itemType = Item.getItemType(Equipment.getItemId(equipmentId));

      if (itemType != ItemType.Pet) {
        petExcludedEquipmentIds[count++] = equipmentId;
      }
    }

    assembly {
      mstore(petExcludedEquipmentIds, count)
    }

    if (petExcludedEquipmentIds.length <= 2) return petExcludedEquipmentIds;

    (uint8[] memory tiers, uint8 highest, uint8 second) = scanTiers(petExcludedEquipmentIds);

    (uint256[] memory high, uint256[] memory sec) = collectCandidates(petExcludedEquipmentIds, tiers, highest, second);

    return pickResult(characterId, high, sec);
  }

  /// @dev compute tiers array, highest and second highest tier
  function scanTiers(uint256[] memory equipmentIds)
    public
    view
    returns (uint8[] memory tiers, uint8 highest, uint8 second)
  {
    uint256 len = equipmentIds.length;
    tiers = new uint8[](len);
    highest = 0;
    second = 0;

    for (uint256 i = 0; i < len; i++) {
      uint8 tier = Item.getTier(Equipment.getItemId(equipmentIds[i]));
      tiers[i] = tier;
      if (tier > highest) {
        second = highest;
        highest = tier;
      } else if (tier > second && tier < highest) {
        second = tier;
      }
    }
  }

  /// @dev partition items into highest tier and second tier candidates
  function collectCandidates(
    uint256[] memory equipmentIds,
    uint8[] memory tiers,
    uint8 highest,
    uint8 second
  )
    public
    pure
    returns (uint256[] memory high, uint256[] memory sec)
  {
    uint256 len = equipmentIds.length;
    uint256[] memory tmpHigh = new uint256[](len);
    uint256[] memory tmpSec = new uint256[](len);
    uint256 highCount = 0;
    uint256 secCount = 0;

    for (uint256 i = 0; i < len; i++) {
      if (tiers[i] == highest) {
        tmpHigh[highCount++] = equipmentIds[i];
      } else if (tiers[i] == second) {
        tmpSec[secCount++] = equipmentIds[i];
      }
    }

    // Trim to exact counts
    high = new uint256[](highCount);
    for (uint256 i = 0; i < highCount; i++) {
      high[i] = tmpHigh[i];
    }

    sec = new uint256[](secCount);
    for (uint256 i = 0; i < secCount; i++) {
      sec[i] = tmpSec[i];
    }
  }

  /// @dev choose result based on counts; pseudo-random shuffle and slice
  function pickResult(
    uint256 characterId,
    uint256[] memory high,
    uint256[] memory sec
  )
    public
    view
    returns (uint256[] memory)
  {
    uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1), characterId)));

    uint256 highCount = high.length;
    uint256 secCount = sec.length;
    if (highCount >= 2) {
      shuffle(high, seed);
      uint256[] memory res = new uint256[](2);
      res[0] = high[0];
      res[1] = high[1];
      return res;
    }

    if (highCount == 1 && secCount > 0) {
      shuffle(sec, seed);
      uint256[] memory res = new uint256[](2);
      res[0] = high[0];
      res[1] = sec[0];
      return res;
    }

    if (highCount == 1) {
      uint256[] memory onlyOne = new uint256[](1);
      onlyOne[0] = high[0];
      return onlyOne;
    }

    return new uint256[](0);
  }

  /// @dev Fisher–Yates shuffle for the whole array
  function shuffle(uint256[] memory arr, uint256 seed) public pure {
    uint256 n = arr.length;

    for (uint256 i; i < n - 1; i++) {
      uint256 randomWord = uint256(keccak256(abi.encodePacked(seed, i)));

      uint256 j = i + (randomWord % (n - i));

      (arr[i], arr[j]) = (arr[j], arr[i]);
    }
  }
}
