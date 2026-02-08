pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";
import { Config } from "@common/index.sol";
import { CharFund } from "@codegen/index.sol";
import { UWorldUtils } from "@utils/UWorldUtils.sol";

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

    uint256 appNsBalance = UWorldUtils.balanceOfNs("app");
    console2.log("test app ns balance:", appNsBalance);
    assertEq(appNsBalance, requireEth);
    assertEq(CharFund.getCrystal(characterId), 500);
    // assert player balance
    assertEq(player.balance, 10 ether - requireEth);

    uint256 currentTeamBalance = Config.TEAM_ADDRESS.balance;

    vm.startPrank(player);
    world.app__sellCrystal(characterId, 500);
    vm.stopPrank();

    uint256 fee = (requireEth * 5 + 99) / 100;
    uint256 paymentAmount = requireEth - fee;
    console2.log("test payment amount:", paymentAmount);
    console2.log("test fee amount:", fee);

    // assert player balance after sell
    assertEq(player.balance, 10 ether - requireEth + paymentAmount);
    // assert app ns balance after sell
    uint256 appNsBalanceAfterSell = UWorldUtils.balanceOfNs("app");
    console2.log("test app ns balance after sell:", appNsBalanceAfterSell);
    assertEq(appNsBalanceAfterSell, appNsBalance - requireEth);
    // assert team ns balance after sell
    assertEq(Config.TEAM_ADDRESS.balance, currentTeamBalance + fee);
    // assert character crystal after sell
    assertEq(CharFund.getCrystal(characterId), 0);
  }
}
