pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";
import { Config } from "@common/index.sol";
import { CharFund, CrystalFee, CityVault2 } from "@codegen/index.sol";
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

    uint256 requireEth = Config.CRYSTAL_UNIT_PRICE * 5000;

    vm.startPrank(player);
    world.app__buyCrystal{ value: requireEth }(characterId, 5000);
    vm.stopPrank();

    uint256 appNsBalance = UWorldUtils.balanceOfNs("app");
    console2.log("test app ns balance:", appNsBalance);
    assertEq(appNsBalance, requireEth);
    assertEq(CharFund.getCrystal(characterId), 5000);
    // assert player balance
    assertEq(player.balance, 10 ether - requireEth);

    uint256 currentTeamBalance = Config.TEAM_ADDRESS.balance;

    vm.startPrank(worldDeployer);
    CrystalFee.setFee(1, 5);
    vm.stopPrank();

    uint256 cityVaultCrystal = CityVault2.getCrystal(1);

    vm.startPrank(player);
    world.app__requestSellCrystal(characterId, 5000); // reqId = 1
    vm.stopPrank();

    vm.startPrank(player);
    world.app__cancelSellCrystal(characterId, 1);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__requestSellCrystal(characterId, 5000); // reqId = 2
    vm.stopPrank();

    vm.expectRevert(); // need to wait for the processing time
    vm.startPrank(player);
    world.app__executeSellCrystal(characterId, 2);
    vm.stopPrank();

    vm.warp(block.timestamp + Config.SELL_CRYSTAL_PROCESSING_TIME);

    vm.startPrank(player);
    world.app__executeSellCrystal(characterId, 2);
    vm.stopPrank();

    uint256 platformFeeCrystal = (5000 * uint256(Config.PLATFORM_FEE_PERCENTAGE) + 99) / 100;
    uint256 remainAmount = 5000 - platformFeeCrystal;
    uint8 kingdomFeePercentage = CrystalFee.getFee(1);
    uint256 kingdomFeeCrystal = (remainAmount * uint256(kingdomFeePercentage)) / 100;
    console2.log("kingdomFeeCrystal:", kingdomFeeCrystal);
    uint256 netAmount = remainAmount - kingdomFeeCrystal;

    uint256 platFormFee = platformFeeCrystal * Config.CRYSTAL_UNIT_PRICE;
    uint256 paymentAmount = netAmount * Config.CRYSTAL_UNIT_PRICE;
    console2.log("test paymentAmount:", paymentAmount);
    console2.log("test platFormFee:", platFormFee);

    uint256 cityVaultCrystalAfter = CityVault2.getCrystal(1);
    assertEq(cityVaultCrystalAfter, cityVaultCrystal + kingdomFeeCrystal);

    // assert player balance after sell
    assertEq(player.balance, 10 ether - requireEth + paymentAmount);
    // assert app ns balance after sell
    uint256 appNsBalanceAfterSell = UWorldUtils.balanceOfNs("app");
    console2.log("test app ns balance after sell:", appNsBalanceAfterSell);
    assertEq(appNsBalanceAfterSell, kingdomFeeCrystal * Config.CRYSTAL_UNIT_PRICE);
    // assert team ns balance after sell
    assertEq(Config.TEAM_ADDRESS.balance, currentTeamBalance + platFormFee);
    // assert character crystal after sell
    assertEq(CharFund.getCrystal(characterId), 0);
  }
}
