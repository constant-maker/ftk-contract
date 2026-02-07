pragma solidity >=0.8.24;

import { Balances } from "@latticexyz/world/src/codegen/tables/Balances.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldContextConsumerLib } from "@latticexyz/world/src/WorldContext.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
import { Config, Errors } from "@common/index.sol";

library WorldUtils {
  bytes14 constant APP_NAMESPACE = "app";
  bytes14 constant ROOT_NAMESPACE = "";

  /// @dev Send fund from namespace app to a specified address
  function transferTo(uint256 ethValue, address to) internal {
    if (ethValue == 0) return;
    validateNsBalance(APP_NAMESPACE, ethValue);
    IWorld world = IWorld(WorldContextConsumerLib._world());
    world.transferBalanceToAddress(WorldResourceIdLib.encodeNamespace(APP_NAMESPACE), to, ethValue);
  }

  /// @dev Send fund from namespace app to team treasury address
  function transferToTeam(uint256 ethValue) internal {
    if (ethValue == 0) return;
    validateNsBalance(APP_NAMESPACE, ethValue);
    IWorld world = IWorld(WorldContextConsumerLib._world());
    world.transferBalanceToAddress(WorldResourceIdLib.encodeNamespace(APP_NAMESPACE), Config.TEAM_ADDRESS, ethValue);
  }

  /// @dev transferToTeamBasedOnCrystal calculate the eth value based on crystal amount and transfer to team treasury
  /// address
  function transferToTeamBasedOnCrystal(uint256 crystalValue) internal {
    if (crystalValue == 0) return;
    uint256 ethValue = crystalValue * Config.CRYSTAL_UNIT_PRICE;
    transferToTeam(ethValue);
  }

  /// @dev validateNsBalance ensure the namespace has sufficient balance
  function validateNsBalance(bytes14 namespace, uint256 requiredAmount) internal view {
    uint256 nsBalance = balanceOfNs(namespace);
    if (nsBalance < requiredAmount) {
      revert Errors.WorldBalanceInsufficient(nsBalance, requiredAmount);
    }
  }

  /// @dev balanceOfWorld return the balance of the world (root namespace "")
  function balanceOfWorld() internal view returns (uint256) {
    return Balances.get(WorldResourceIdLib.encodeNamespace(ROOT_NAMESPACE));
  }

  /// @dev balanceOfNs return the balance of a namespace
  function balanceOfNs(bytes14 namespace) internal view returns (uint256) {
    return Balances.get(WorldResourceIdLib.encodeNamespace(namespace));
  }
}
