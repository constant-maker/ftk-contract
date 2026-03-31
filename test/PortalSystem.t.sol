pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { Config } from "@common/index.sol";
import { CharFund, CrystalFee, CityVault2, PlatformRevenue, PlatformRevenueData } from "@codegen/index.sol";
import { UWorldUtils } from "@utils/UWorldUtils.sol";
import { PlatformUtils } from "@utils/PlatformUtils.sol";

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

    uint256 amount = 5000;
    uint256 requireEth = Config.CRYSTAL_UNIT_PRICE * amount;
    PlatformRevenueData memory platformRevenue = PlatformRevenue.get();

    vm.startPrank(player);
    world.app__buyCrystal{ value: requireEth }(characterId, amount);
    vm.stopPrank();

    assertEq(UWorldUtils.balanceOfNs("app"), requireEth);
    assertEq(CharFund.getCrystal(characterId), amount);
    // assert player balance
    assertEq(player.balance, 10 ether - requireEth);

    vm.startPrank(worldDeployer);
    CrystalFee.setFee(1, 5);
    vm.stopPrank();

    uint256 cityVaultCrystal = CityVault2.getCrystal(1);

    vm.startPrank(player);
    world.app__requestSellCrystal(characterId, amount); // reqId = 1
    vm.stopPrank();

    vm.startPrank(player);
    world.app__cancelSellCrystal(characterId, 1);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__requestSellCrystal(characterId, amount); // reqId = 2
    vm.stopPrank();

    vm.expectRevert(); // need to wait for the processing time
    vm.startPrank(player);
    world.app__executeSellCrystal(characterId, 2);
    vm.stopPrank();

    vm.warp(block.timestamp + Config.SELL_CRYSTAL_PROCESSING_TIME);

    vm.startPrank(player);
    world.app__executeSellCrystal(characterId, 2);
    vm.stopPrank();

    uint256 platformFeeCrystal = PlatformUtils.getPlatformFee(amount);
    uint256 kingdomFeeCrystal = ((amount - platformFeeCrystal) * uint256(CrystalFee.getFee(1))) / 100;
    uint256 netAmount = amount - platformFeeCrystal - kingdomFeeCrystal;

    uint256 cityVaultCrystalAfter = CityVault2.getCrystal(1);
    assertEq(cityVaultCrystalAfter, cityVaultCrystal + kingdomFeeCrystal);

    // assert player balance after sell
    assertEq(player.balance, 10 ether - requireEth + (netAmount * Config.CRYSTAL_UNIT_PRICE));
    // assert app ns balance after sell
    assertEq(UWorldUtils.balanceOfNs("app"), (platformFeeCrystal + kingdomFeeCrystal) * Config.CRYSTAL_UNIT_PRICE);

    // assert platform revenue updates after sell
    assertEq(PlatformRevenue.getAppVaultCrystal(), platformRevenue.appVaultCrystal + kingdomFeeCrystal);
    assertEq(PlatformRevenue.getAppTeamCrystal(), platformRevenue.appTeamCrystal + (platformFeeCrystal / 2));
    assertEq(PlatformRevenue.getAppBackerCrystal(), platformRevenue.appBackerCrystal + (platformFeeCrystal / 2));
    assertEq(PlatformRevenue.getTotalRevenue(), platformRevenue.totalRevenue + platformFeeCrystal + kingdomFeeCrystal);

    // assert character crystal after sell
    assertEq(CharFund.getCrystal(characterId), 0);
  }

  function test_TransferCrystal_Accounting() external {
    address receiver = makeAddr("receiver");
    uint256 receiverCharacterId = _createDefaultCharacter(receiver);
    _claimWelcomePackages(receiver, receiverCharacterId);

    vm.deal(player, 10 ether);

    uint256 buyAmount = 5000;
    uint256 requireEth = Config.CRYSTAL_UNIT_PRICE * buyAmount;
    uint256 totalRevenueBefore = PlatformRevenue.getTotalRevenue();
    uint256 appVaultBefore = PlatformRevenue.getAppVaultCrystal();
    uint256 appTeamBefore = PlatformRevenue.getAppTeamCrystal();
    uint256 appBackerBefore = PlatformRevenue.getAppBackerCrystal();
    uint256 cityVaultBefore = CityVault2.getCrystal(1);

    vm.startPrank(worldDeployer);
    CrystalFee.setFee(1, 5);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__buyCrystal{ value: requireEth }(characterId, buyAmount);
    world.app__transferCrystal(characterId, receiverCharacterId, buyAmount);
    vm.stopPrank();

    uint256 platformFeeCrystal = PlatformUtils.getPlatformFee(buyAmount);
    uint256 remainAmount = buyAmount - platformFeeCrystal;
    uint256 kingdomFeeCrystal = (remainAmount * uint256(CrystalFee.getFee(1))) / 100;
    uint256 netAmount = remainAmount - kingdomFeeCrystal;

    assertEq(CharFund.getCrystal(characterId), 0);
    assertEq(CharFund.getCrystal(receiverCharacterId), netAmount);
    assertEq(CityVault2.getCrystal(1), cityVaultBefore + kingdomFeeCrystal);

    assertEq(PlatformRevenue.getAppVaultCrystal(), appVaultBefore + kingdomFeeCrystal);
    assertEq(PlatformRevenue.getAppTeamCrystal(), appTeamBefore + (platformFeeCrystal / 2));
    assertEq(PlatformRevenue.getAppBackerCrystal(), appBackerBefore + (platformFeeCrystal / 2));
    assertEq(PlatformRevenue.getTotalRevenue(), totalRevenueBefore + platformFeeCrystal + kingdomFeeCrystal);
  }
}
