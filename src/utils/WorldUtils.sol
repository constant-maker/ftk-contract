pragma solidity >=0.8.24;

import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldContextConsumerLib } from "@latticexyz/world/src/WorldContext.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
import { Config, Errors } from "@common/index.sol";
import { Balances } from "@latticexyz/world/src/codegen/tables/Balances.sol";

library WorldUtils {
  /// @dev Send fund to team address
  function transferToTeam(uint256 ethValue) internal {
    if (ethValue == 0) return;
    validateWorldBalance(ethValue);
    IWorld world = IWorld(WorldContextConsumerLib._world());
    world.transferBalanceToAddress(WorldResourceIdLib.encodeNamespace(""), Config.TEAM_ADDRESS, ethValue);
  }

  /// @dev transferToTeamBasedOnCrystal calculate the eth value based on crystal amount and transfer to team address
  function transferToTeamBasedOnCrystal(uint256 crystalValue) internal {
    if (crystalValue == 0) return;
    IWorld world = IWorld(WorldContextConsumerLib._world());
    uint256 ethValue = crystalValue * Config.CRYSTAL_UNIT_PRICE;
    validateWorldBalance(ethValue);
    world.transferBalanceToAddress(WorldResourceIdLib.encodeNamespace(""), Config.TEAM_ADDRESS, ethValue);
  }

  /// @dev validateWorldBalance ensure the world contract has enough balance
  function validateWorldBalance(uint256 requiredAmount) internal view {
    uint256 worldBalance = balanceOfWorld();
    if (worldBalance < requiredAmount) {
      revert Errors.WorldBalanceInsufficient(worldBalance, requiredAmount);
    }
  }

  /// @dev balanceOfWorld return the balance of the world contract
  function balanceOfWorld() internal view returns (uint256) {
    return Balances.get(WorldResourceIdLib.encodeNamespace(""));
  }
}
