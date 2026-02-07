pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
// import { Balances } from "@latticexyz/world/src/codegen/tables/Balances.sol";
// import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";
import { Config } from "@common/index.sol";
import { CharFund } from "@codegen/index.sol";
import { WorldUtils } from "@utils/WorldUtils.sol";

contract PortalSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_Portal() external {
    vm.deal(player, 10 ether);

    uint256 requireEth = Config.CRYSTAL_UNIT_PRICE * 500;

    vm.startPrank(player);
    world.app__buyCrystal{ value: requireEth }(characterId, 500);
    vm.stopPrank();

    uint256 appNsBalance = WorldUtils.balanceOfNs("app");
    console2.log("app ns balance:", appNsBalance);
    assertEq(appNsBalance, requireEth);
    assertEq(CharFund.getCrystal(characterId), 500);
    // assert player balance
    assertEq(player.balance, 10 ether - requireEth);

    vm.startPrank(player);
    world.app__sellCrystal(characterId, 500);
    vm.stopPrank();

    uint256 fee = (requireEth * 5) / 100;
    uint256 paymentAmount = requireEth - fee;
    console2.log("payment amount:", paymentAmount);
    console2.log("fee amount:", fee);

    // assert player balance after sell
    assertEq(player.balance, 10 ether - requireEth + paymentAmount);
    // assert app ns balance after sell
    uint256 appNsBalanceAfterSell = WorldUtils.balanceOfNs("app");
    assertEq(appNsBalanceAfterSell, appNsBalance - requireEth);
    // assert team ns balance after sell
    assertEq(Config.TEAM_ADDRESS.balance, fee);
    // assert character crystal after sell
    assertEq(CharFund.getCrystal(characterId), 0);
  }
}
