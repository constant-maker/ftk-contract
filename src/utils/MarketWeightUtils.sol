pragma solidity >=0.8.24;

import { CharMarketWeight, OrderData, ItemV2 } from "@codegen/index.sol";
import { Errors, Config } from "@common/index.sol";

library MarketWeightUtils {
  function checkAndSetMaxWeight(uint256 characterId, uint256 cityId) public {
    uint32 maxWeight = CharMarketWeight.getMaxWeight(characterId, cityId);
    if (maxWeight == 0) {
      maxWeight = Config.INIT_STORAGE_MAX_WEIGHT;
      CharMarketWeight.setMaxWeight(characterId, cityId, maxWeight);
    }
  }

  function updateWeight(uint256 characterId, uint256 cityId, uint256 itemId, uint32 amount, bool isReduce) public {
    uint32 weight = CharMarketWeight.getWeight(characterId, cityId);
    uint32 maxWeight = CharMarketWeight.getMaxWeight(characterId, cityId);
    uint32 weightChange = ItemV2.getWeight(itemId) * amount;
    if (isReduce) {
      weight -= weightChange;
    } else {
      weight += weightChange;
    }
    if (weight > maxWeight) {
      revert Errors.MarketSystem_ExceedMaxWeight(characterId, cityId, weight, maxWeight);
    }
    CharMarketWeight.setWeight(characterId, cityId, weight);
  }
}
