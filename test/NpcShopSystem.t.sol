pragma solidity >=0.8.24;

import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture } from "./fixtures/index.sol";
import { WorldFixture } from "./fixtures/WorldFixture.sol";
import { console } from "forge-std/console.sol";
import { NpcShop } from "@codegen/tables/NpcShop.sol";
import { CharFund } from "@codegen/tables/CharFund.sol";
import { CharOtherItem } from "@codegen/tables/CharOtherItem.sol";
import { NpcShopInventory } from "@codegen/tables/NpcShopInventory.sol";
import { CharInventory } from "@codegen/tables/CharInventory.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { TradeData } from "@systems/app/NpcShopSystem.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";

contract NpcShopSystem is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;
  uint256 cityId = 1;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_ShouldHaveRightData() external {
    uint32 npcBalance = NpcShop.getGold(1);
    assertEq(npcBalance, 100_000);
  }

  function test_BuyItemFromNpc() external {
    vm.startPrank(worldDeployer);
    CharFund.setGold(characterId, 75);
    vm.stopPrank();

    uint256 prevLen = CharInventory.lengthToolIds(characterId);

    TradeData[] memory buyData = new TradeData[](1);
    buyData[0] = TradeData({ itemId: 18, amount: 1 });
    TradeData[] memory sellData;

    vm.startPrank(player);
    world.app__tradeWithNpc(characterId, cityId, buyData, sellData);
    vm.stopPrank();
    assertEq(CharInventory.lengthToolIds(characterId), prevLen + 1);
    assertEq(CharFund.getGold(characterId), 50);

    buyData[0].amount = 2;
    vm.startPrank(player);
    world.app__tradeWithNpc(characterId, cityId, buyData, sellData);
    vm.stopPrank();

    assertEq(CharInventory.lengthToolIds(characterId), prevLen + 3);
    assertEq(CharFund.getGold(characterId), 0);

    vm.startPrank(worldDeployer);
    CharFund.setGold(characterId, 10);
    vm.stopPrank();

    buyData[0].amount = 3;
    vm.expectRevert(); // not enough gold
    vm.startPrank(player);
    world.app__tradeWithNpc(characterId, cityId, buyData, sellData);
    vm.stopPrank();

    buyData[0].itemId = 1;
    vm.expectRevert(); // buy item which is not tool
    vm.startPrank(player);
    world.app__tradeWithNpc(characterId, cityId, buyData, sellData);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    NpcShopInventory.set(1, 1, 1, 100);
    vm.stopPrank();

    buyData[0].itemId = 1;
    buyData[0].amount = 3;
    vm.startPrank(player);
    world.app__tradeWithNpc(characterId, cityId, buyData, sellData);
    vm.stopPrank();

    assertEq(CharFund.getGold(characterId), 1);
    assertEq(CharOtherItem.getAmount(characterId, 1), 3);
    assertEq(NpcShopInventory.getAmount(1, 1), 97);
  }

  function test_SellItemToNpc() external {
    TradeData[] memory buyData;
    TradeData[] memory sellData = new TradeData[](2);
    sellData[0] = TradeData({ itemId: 18, amount: 1 });
    sellData[1] = TradeData({ itemId: 1, amount: 100 });

    vm.expectRevert();
    vm.startPrank(player);
    world.app__tradeWithNpc(characterId, cityId, buyData, sellData);
    vm.stopPrank();

    sellData = new TradeData[](1);
    sellData[0] = TradeData({ itemId: 1, amount: 100 });

    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, 1, 101);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__tradeWithNpc(characterId, cityId, buyData, sellData);
    vm.stopPrank();

    assertEq(CharFund.getGold(characterId), 100);
    assertEq(CharOtherItem.getAmount(characterId, 1), 1);
    assertEq(NpcShopInventory.getAmount(1, 1), 100);
    assertEq(NpcShop.get(1), 99_900);

    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, 1, 9900);
    vm.stopPrank();

    sellData[0].amount = 9900;
    vm.startPrank(player);
    world.app__tradeWithNpc(characterId, cityId, buyData, sellData);
    vm.stopPrank();

    assertEq(CharFund.getGold(characterId), 10_000);
    assertEq(CharOtherItem.getAmount(characterId, 1), 1);
    assertEq(NpcShopInventory.getAmount(1, 1), 10_000);
    assertEq(NpcShop.get(1), 90_000);

    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, 2, 10_001);
    vm.stopPrank();

    sellData[0].itemId = 2;
    sellData[0].amount = 5000;
    vm.startPrank(player);
    world.app__tradeWithNpc(characterId, cityId, buyData, sellData);
    vm.stopPrank();

    assertEq(CharFund.getGold(characterId), 20_000);
    assertEq(CharOtherItem.getAmount(characterId, 2), 5001);
    assertEq(NpcShopInventory.getAmount(1, 2), 5000);
    assertEq(NpcShop.get(1), 80_000);
    assertEq(NpcShop.get(2), 100_000);
  }
}
