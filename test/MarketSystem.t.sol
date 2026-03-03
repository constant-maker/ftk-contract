pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture } from "./fixtures/index.sol";
import {
  CharacterPositionUtils,
  InventoryEquipmentUtils,
  CharacterItemUtils,
  CharAchievementUtils,
  StorageEquipmentUtils,
  StorageItemUtils,
  CharacterFundUtils
} from "@utils/index.sol";
import { OrderParams, TakeOrderParams, MarketSystemUtils } from "@utils/MarketSystemUtils.sol";
import { Config } from "@common/index.sol";
import { CurrencyType } from "@codegen/common.sol";
import {
  City,
  CityData,
  OrderData,
  Order,
  CharStats2,
  CharMarketWeight,
  CharCurrentStats,
  OrderCounter,
  Equipment,
  CharFund,
  CharOtherItem,
  MarketFee,
  CharAchievement,
  CharAchievementIndex,
  FillOrder,
  FillOrderData,
  CharOtherItemStorage,
  CrystalFee,
  CityVault2V2,
  RestrictLocV2
} from "@codegen/index.sol";

contract MarketSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player1 = makeAddr("player1");
  uint256 characterId1;
  address player2 = makeAddr("player2");
  uint256 characterId2;
  uint256 city1 = 1;
  uint256 city2 = 2;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    super.setUp();

    characterId1 = _createDefaultCharacter(player1);
    _claimWelcomePackages(player1, characterId1);

    characterId2 = _createCharacterWithNameAndKingdomId(player2, "123", 2);
    _claimWelcomePackages(player2, characterId2);
  }

  function test_SellAndTakeEquipmentOrder() public {
    // sell equipment
    OrderParams memory orderParams = OrderParams({
      orderId: 0,
      cityId: city1,
      equipmentId: 1,
      itemId: Equipment.getItemId(1),
      amount: 1,
      unitPrice: 100,
      currency: CurrencyType.Gold,
      isBuy: false
    });
    vm.expectRevert(); // fame too low
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharStats2.setFame(characterId1, 1050);
    CharFund.setGold(characterId1, 105); // 100 + 5% fee
    CharStats2.setFame(characterId2, 1050);
    CharFund.setGold(characterId2, 100);
    vm.stopPrank();

    uint32 prevMarketWeight = CharMarketWeight.getWeight(characterId1, city1);
    console2.log("current character market weight", prevMarketWeight);
    uint32 prevCurrentWeight = CharCurrentStats.getWeight(characterId1);
    console2.log("current character weight", prevCurrentWeight);

    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    uint32 newMarketWeight = CharMarketWeight.getWeight(characterId1, city1);
    console2.log("new character market weight", newMarketWeight);
    assertEq(newMarketWeight, prevMarketWeight + 5);
    assertEq(CharMarketWeight.getMaxWeight(characterId1, city1), Config.INIT_STORAGE_MAX_WEIGHT);
    assertEq(CharCurrentStats.getWeight(characterId1), prevCurrentWeight - 5);

    orderParams.equipmentId = 2; // equipment not owned (belong to player2)
    vm.expectRevert();
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    vm.expectRevert();
    vm.startPrank(player1);
    world.app__cancelOrder(characterId1, 2); // order not exist
    vm.stopPrank();

    vm.expectRevert(); // not in the city1
    vm.startPrank(player2);
    world.app__placeOrder(characterId2, orderParams);
    vm.stopPrank();

    _moveToCity(characterId2, city1);
    vm.startPrank(player2);
    world.app__placeOrder(characterId2, orderParams);
    vm.stopPrank();

    console2.log("player2 order id", OrderCounter.get());

    vm.expectRevert(); // not order owner
    vm.startPrank(player1);
    world.app__cancelOrder(characterId1, 2);
    vm.stopPrank();

    vm.startPrank(player1);
    world.app__cancelOrder(characterId1, 1);
    vm.stopPrank();

    newMarketWeight = CharMarketWeight.getWeight(characterId1, city1);
    console2.log("new character market weight", newMarketWeight);
    assertEq(newMarketWeight, prevMarketWeight);
    assertEq(CharMarketWeight.getMaxWeight(characterId1, city1), Config.INIT_STORAGE_MAX_WEIGHT);
    assertEq(CharCurrentStats.getWeight(characterId1), prevCurrentWeight);

    OrderData memory order = Order.get(2);
    assertEq(order.characterId, characterId2);
    assertEq(order.cityId, city1);
    assertEq(order.equipmentId, 2);
    assertEq(order.itemId, 33);
    assertEq(order.amount, 1);
    assertEq(order.unitPrice, 100);
    assertEq(order.isBuy, false);
    assertEq(order.isDone, false);

    // take order
    TakeOrderParams memory takeOrderParams = TakeOrderParams({ orderId: 2, amount: 1, equipmentIds: new uint256[](0) });
    TakeOrderParams[] memory takeOrderParamsArray = new TakeOrderParams[](1);
    takeOrderParamsArray[0] = takeOrderParams;
    vm.startPrank(player1);
    world.app__takeOrder(characterId1, takeOrderParamsArray);
    vm.stopPrank();

    FillOrderData memory fillOrder = FillOrder.get(1);
    console2.log("fill order city id", fillOrder.cityId);
    console2.log("fill order character id", fillOrder.characterId);
    console2.log("fill order equipment id", fillOrder.equipmentId);
    console2.log("fill order item id", fillOrder.itemId);
    console2.log("fill order amount", fillOrder.amount);
    console2.log("fill order unit price", fillOrder.unitPrice);
    console2.log("fill order is buy", fillOrder.isBuy);
    console2.log("fill order timestamp", fillOrder.filledAt);
    assertEq(fillOrder.cityId, city1);
    assertEq(fillOrder.characterId, characterId1);
    assertEq(fillOrder.equipmentId, 2);
    assertEq(fillOrder.itemId, 33);
    assertEq(fillOrder.amount, 1);
    assertEq(fillOrder.unitPrice, 100);
    assertEq(fillOrder.isBuy, true);

    assertEq(CharMarketWeight.getWeight(characterId2, city1), 0); // market weight decrease because of taking order
    assertEq(CharCurrentStats.getWeight(characterId1), prevCurrentWeight + 5); // weight increase because of taking
    // order
    assertEq(CharFund.getGold(characterId2), 200); // 100 + 100 - 0% fee
    assertEq(CharFund.getGold(characterId1), 5); // already spent to take order
    assertEq(Equipment.getCharacterId(2), characterId1); // transfer equipment to player1
    assertTrue(InventoryEquipmentUtils.hasEquipment(characterId1, 2));
  }

  function test_SellOtherItemOrder() public {
    // sell equipment
    OrderParams memory orderParams = OrderParams({
      orderId: 0,
      cityId: city1,
      equipmentId: 0,
      itemId: 33,
      amount: 100,
      unitPrice: 1,
      currency: CurrencyType.Gold,
      isBuy: false
    });

    vm.startPrank(worldDeployer);

    CharOtherItem.setAmount(characterId1, 1, 100);
    CharOtherItem.setAmount(characterId1, 2, 100);
    CharCurrentStats.setWeight(characterId1, CharCurrentStats.getWeight(characterId1) + 330);

    CharStats2.setFame(characterId1, 1050);
    CharFund.setGold(characterId1, 200);

    CharStats2.setFame(characterId2, 1050);
    CharFund.setGold(characterId2, 200);

    vm.stopPrank();

    uint32 prevMarketWeight = CharMarketWeight.getWeight(characterId1, city1);
    console2.log("current character1 market weight", prevMarketWeight);
    uint32 prevCurrentWeight = CharCurrentStats.getWeight(characterId1);
    console2.log("current character1 weight", prevCurrentWeight);

    uint32 prevChar2CurrentWeight = CharCurrentStats.getWeight(characterId2);
    console2.log("current character2 weight", prevChar2CurrentWeight);

    vm.expectRevert(); // invalid item category, it should be OtherItem
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    orderParams.itemId = 3;
    vm.expectRevert(); // not enough item
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    orderParams.itemId = 1;
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    uint32 newMarketWeight = CharMarketWeight.getWeight(characterId1, city1);
    console2.log("new character market weight", newMarketWeight);
    assertEq(newMarketWeight, prevMarketWeight + 100);
    assertEq(CharCurrentStats.getWeight(characterId1), prevCurrentWeight - 100);
    assertEq(CharOtherItem.getAmount(characterId1, 1), 0); // locked in market

    console2.log("move character2 to city1");
    _moveToCity(characterId2, city1);

    TakeOrderParams memory takeOrderParams = TakeOrderParams({ orderId: 1, amount: 50, equipmentIds: new uint256[](0) });
    TakeOrderParams[] memory takeOrderParamsArray = new TakeOrderParams[](1);
    takeOrderParamsArray[0] = takeOrderParams;
    vm.startPrank(player2);
    world.app__takeOrder(characterId2, takeOrderParamsArray);
    vm.stopPrank();

    FillOrderData memory fillOrder = FillOrder.get(1);
    console2.log("fill order city id", fillOrder.cityId);
    console2.log("fill order character id", fillOrder.characterId);
    console2.log("fill order equipment id", fillOrder.equipmentId);
    console2.log("fill order item id", fillOrder.itemId);
    console2.log("fill order amount", fillOrder.amount);
    console2.log("fill order unit price", fillOrder.unitPrice);
    console2.log("fill order is buy", fillOrder.isBuy);
    console2.log("fill order timestamp", fillOrder.filledAt);
    assertEq(fillOrder.cityId, city1);
    assertEq(fillOrder.characterId, characterId2);
    assertEq(fillOrder.equipmentId, 0);
    assertEq(fillOrder.itemId, 1);
    assertEq(fillOrder.amount, 50);
    assertEq(fillOrder.unitPrice, 1);
    assertEq(fillOrder.isBuy, true);

    console2.log("character2 take order success");
    assertEq(CharMarketWeight.getWeight(characterId1, city1), 50); // from 100 to 50 (50 is taken)
    assertEq(CharCurrentStats.getWeight(characterId2), prevChar2CurrentWeight + 50); // weight increase because of
    // taking order
    assertEq(CharOtherItem.getAmount(characterId2, 1), 50);
    assertEq(CharFund.getGold(characterId2), 150); // 200 - 50 - 0 (fee)
    assertEq(CharFund.getGold(characterId1), 250); // 200 + 50 - 0 (fee)
    assertEq(Order.getAmount(1), 50); // 100 - 50
    assertFalse(Order.getIsDone(1));

    // update order
    orderParams.orderId = 2; // test wrong order id
    vm.expectRevert(); // not order owner
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    orderParams.orderId = 1;
    orderParams.cityId = city2; // test wrong city
    vm.expectRevert(); // not in the city2
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    orderParams.cityId = city1;
    orderParams.unitPrice = 0; // invalid unit price
    vm.expectRevert();
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    orderParams.unitPrice = 2;
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();
    assertEq(Order.getUnitPrice(1), 2); // order updated
    assertEq(Order.getAmount(1), 50); // order amount not updated

    takeOrderParamsArray[0].amount = 51; // bigger than order amount
    vm.expectRevert();
    vm.startPrank(player2);
    world.app__takeOrder(characterId2, takeOrderParamsArray);
    vm.stopPrank();
    console2.log("character2 take order part 2");
    takeOrderParamsArray[0].amount = 50;
    vm.startPrank(player2);
    world.app__takeOrder(characterId2, takeOrderParamsArray);
    vm.stopPrank();
    console2.log("character2 take order part 2 success");

    fillOrder = FillOrder.get(2);
    console2.log("fill order city id", fillOrder.cityId);
    console2.log("fill order character id", fillOrder.characterId);
    console2.log("fill order equipment id", fillOrder.equipmentId);
    console2.log("fill order item id", fillOrder.itemId);
    console2.log("fill order amount", fillOrder.amount);
    console2.log("fill order unit price", fillOrder.unitPrice);
    console2.log("fill order is buy", fillOrder.isBuy);
    console2.log("fill order timestamp", fillOrder.filledAt);
    assertEq(fillOrder.cityId, city1);
    assertEq(fillOrder.characterId, characterId2);
    assertEq(fillOrder.equipmentId, 0);
    assertEq(fillOrder.itemId, 1);
    assertEq(fillOrder.amount, 50);
    assertEq(fillOrder.unitPrice, 2);
    assertEq(fillOrder.isBuy, true);

    assertEq(CharMarketWeight.getWeight(characterId1, city1), 0); // from 50 to 0 (50 is taken)
    assertEq(CharCurrentStats.getWeight(characterId1), prevCurrentWeight - 100);
    assertEq(CharCurrentStats.getWeight(characterId2), prevChar2CurrentWeight + 100); // weight increase because of
    // taking order
    assertEq(CharOtherItem.getAmount(characterId2, 1), 100);
    assertEq(CharFund.getGold(characterId2), 50); // 150 - 100 - 0 (fee) (unit price changed to 2)
    assertEq(CharFund.getGold(characterId1), 350); // 200 + 100 - 0 (fee)
    assertTrue(Order.getIsDone(1));
    console2.log("orderParams", orderParams.orderId);
    vm.expectRevert(); // order already done
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    // move to city2, to test kingdom fee
    prevCurrentWeight = CharCurrentStats.getWeight(characterId1);
    vm.startPrank(worldDeployer);
    MarketFee.setFee(2, 1, 100);
    vm.stopPrank();
    _moveAllToCity(city2);
    orderParams = OrderParams({
      orderId: 0,
      cityId: city2,
      equipmentId: 0,
      itemId: 2,
      amount: 10,
      unitPrice: 2,
      currency: CurrencyType.Gold,
      isBuy: false
    });
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();
    assertEq(CharMarketWeight.getWeight(characterId1, city2), 10); // 10 * 2 = 20
    assertEq(CharCurrentStats.getWeight(characterId1), prevCurrentWeight - 10);
    takeOrderParams = TakeOrderParams({ orderId: 2, amount: 10, equipmentIds: new uint256[](0) });
    takeOrderParamsArray[0] = takeOrderParams;
    vm.startPrank(player2);
    world.app__takeOrder(characterId2, takeOrderParamsArray);
    vm.stopPrank();
    assertEq(CharMarketWeight.getWeight(characterId1, city2), 0);
    assertEq(CharFund.getGold(characterId1), 250 + 100); // nothing changed because of kingdom fee
    assertEq(CharFund.getGold(characterId2), 30); // 50 - (10 * 2) - 0 (fee)
  }

  function test_BuyOtherItemOrder() public {
    // buy other item
    OrderParams memory orderParams = OrderParams({
      orderId: 0,
      cityId: city1,
      equipmentId: 0,
      itemId: 1,
      amount: 100,
      unitPrice: 100,
      currency: CurrencyType.Gold,
      isBuy: true
    });

    vm.startPrank(worldDeployer);

    CharOtherItem.setAmount(characterId1, 1, 100);
    CharCurrentStats.setWeight(characterId1, CharCurrentStats.getWeight(characterId1) + 100);
    CharOtherItem.setAmount(characterId2, 1, 100);
    CharCurrentStats.setWeight(characterId2, CharCurrentStats.getWeight(characterId2) + 100);

    CharStats2.setFame(characterId1, 1050);
    CharFund.setGold(characterId1, 200);

    CharStats2.setFame(characterId2, 1050);
    CharFund.setGold(characterId2, 200);

    vm.stopPrank();

    uint32 prevMarketWeight = CharMarketWeight.getWeight(characterId1, city2);
    console2.log("current character1 market weight", prevMarketWeight);
    uint32 prevCurrentWeight = CharCurrentStats.getWeight(characterId1);
    console2.log("current character1 weight", prevCurrentWeight);
    uint32 prevFund = CharFund.getGold(characterId1);

    uint32 prevChar2MarketWeight = CharMarketWeight.getWeight(characterId2, city2);
    console2.log("current character1 market weight", prevMarketWeight);
    uint32 prevChar2CurrentWeight = CharCurrentStats.getWeight(characterId2);
    console2.log("current character2 weight", prevChar2CurrentWeight);
    uint32 prevChar2Fund = CharFund.getGold(characterId2);

    vm.expectRevert(); // not enough gold
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    orderParams.unitPrice = 1;
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    uint32 newFund = CharFund.getGold(characterId1);
    console2.log("new character1 fund", newFund);
    assertEq(newFund, prevFund - 100); // locked in order

    // take order
    _moveToCity(characterId2, city1);

    TakeOrderParams memory takeOrderParams = TakeOrderParams({ orderId: 1, amount: 50, equipmentIds: new uint256[](0) });
    TakeOrderParams[] memory takeOrderParamsArray = new TakeOrderParams[](1);
    takeOrderParamsArray[0] = takeOrderParams;
    vm.startPrank(player2);
    world.app__takeOrder(characterId2, takeOrderParamsArray);
    vm.stopPrank();

    FillOrderData memory fillOrder = FillOrder.get(1);
    console2.log("fill order city id", fillOrder.cityId);
    console2.log("fill order character id", fillOrder.characterId);
    console2.log("fill order equipment id", fillOrder.equipmentId);
    console2.log("fill order item id", fillOrder.itemId);
    console2.log("fill order amount", fillOrder.amount);
    console2.log("fill order unit price", fillOrder.unitPrice);
    console2.log("fill order is buy", fillOrder.isBuy);
    console2.log("fill order timestamp", fillOrder.filledAt);
    assertEq(fillOrder.cityId, city1);
    assertEq(fillOrder.characterId, characterId2);
    assertEq(fillOrder.equipmentId, 0);
    assertEq(fillOrder.itemId, 1);
    assertEq(fillOrder.amount, 50);
    assertEq(fillOrder.unitPrice, 1);
    assertEq(fillOrder.isBuy, false);

    console2.log("character2 take order success");

    assertEq(CharCurrentStats.getWeight(characterId2), prevChar2CurrentWeight - 50); // selling order decrease weight
    assertEq(CharOtherItem.getAmount(characterId2, 1), 50);
    assertEq(CharFund.getGold(characterId2), 250); // 200 + 50 - 0% fee
    assertEq(CharOtherItemStorage.getAmount(characterId1, 1, 1), 50); // + 50
    assertEq(Order.getAmount(1), 50); // 100 - 50
    assertFalse(Order.getIsDone(1));

    console2.log("update price to test repay fund");
    // update order
    orderParams.orderId = 1;
    orderParams.unitPrice = 2;
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();
    assertEq(Order.getUnitPrice(1), 2); // order updated
    assertEq(Order.getAmount(1), 50); // order amount not updated
    assertEq(CharFund.getGold(characterId1), prevFund - 100 - 50); // price changed to 2, so locked amount
    // increased

    // test repay fund when price changed smaller
    orderParams.unitPrice = 1;
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();
    assertEq(Order.getUnitPrice(1), 1); // order updated
    assertEq(Order.getAmount(1), 50); // order amount not updated
    assertEq(CharFund.getGold(characterId1), prevFund - 100); // price changed to 1, user get repay

    // update order price again to 2
    orderParams.unitPrice = 2;
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    MarketFee.setFee(1, 2, 100);
    vm.stopPrank();
    takeOrderParamsArray[0].amount = 50;
    vm.startPrank(player2);
    world.app__takeOrder(characterId2, takeOrderParamsArray);
    vm.stopPrank();
    assertTrue(Order.getIsDone(1));
    assertEq(CharFund.getGold(characterId2), 250); // nothing changed because of kingdom fee is 100%
    assertEq(CharOtherItemStorage.getAmount(characterId1, 1, 1), 100); // 50 + 50
  }

  function test_BuyEquipment() public {
    vm.startPrank(worldDeployer);

    CharOtherItem.setAmount(characterId1, 1, 100);
    CharCurrentStats.setWeight(characterId1, CharCurrentStats.getWeight(characterId1) + 100);
    CharOtherItem.setAmount(characterId2, 1, 100);
    CharCurrentStats.setWeight(characterId2, CharCurrentStats.getWeight(characterId2) + 100);

    CharStats2.setFame(characterId1, 1050);
    CharFund.setGold(characterId1, 200);

    CharStats2.setFame(characterId2, 1050);
    CharFund.setGold(characterId2, 200);

    vm.stopPrank();

    uint32 prevMarketWeight = CharMarketWeight.getWeight(characterId1, city2);
    console2.log("current character1 market weight", prevMarketWeight);
    uint32 prevCurrentWeight = CharCurrentStats.getWeight(characterId1);
    console2.log("current character1 weight", prevCurrentWeight);
    uint32 prevFund = CharFund.getGold(characterId1);

    uint32 prevChar2MarketWeight = CharMarketWeight.getWeight(characterId2, city2);
    console2.log("current character1 market weight", prevMarketWeight);
    uint32 prevChar2CurrentWeight = CharCurrentStats.getWeight(characterId2);
    console2.log("current character2 weight", prevChar2CurrentWeight);
    uint32 prevChar2Fund = CharFund.getGold(characterId2);

    // buy equipment
    OrderParams memory orderParams = OrderParams({
      orderId: 0,
      cityId: city1,
      equipmentId: 0,
      itemId: 33,
      amount: 2,
      unitPrice: 100,
      currency: CurrencyType.Gold,
      isBuy: true
    });
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();
    uint32 newFund = CharFund.getGold(characterId1);
    console2.log("new character1 fund", newFund);
    assertEq(newFund, prevFund - 200); // locked in order

    console2.log("move character2 to city1 to take order");
    _moveToCity(characterId2, city1);
    TakeOrderParams memory takeOrderParams = TakeOrderParams({ orderId: 1, amount: 1, equipmentIds: new uint256[](1) });
    takeOrderParams.equipmentIds[0] = 2; // equipment owned by player2
    TakeOrderParams[] memory takeOrderParamsArray = new TakeOrderParams[](1);
    takeOrderParamsArray[0] = takeOrderParams;
    vm.startPrank(player2);
    world.app__takeOrder(characterId2, takeOrderParamsArray);
    vm.stopPrank();
    console2.log("character2 take order success");

    assertEq(CharCurrentStats.getWeight(characterId2), prevChar2CurrentWeight - 5); // transfer equipment to player1
    assertEq(CharFund.getGold(characterId2), prevChar2Fund + 100); // 200 + 100 - 0% fee
    assertEq(Order.getAmount(1), 1); // 2 - 1
    assertFalse(Order.getIsDone(1));

    vm.startPrank(worldDeployer);
    CharacterItemUtils.addNewItem(characterId2, 33, 1); // equipment id 3
    vm.stopPrank();
    assertTrue(InventoryEquipmentUtils.hasEquipment(characterId2, 3));
    takeOrderParams.equipmentIds[0] = 3; // equipment owned by player2
    takeOrderParamsArray[0] = takeOrderParams;
    vm.startPrank(player2);
    world.app__takeOrder(characterId2, takeOrderParamsArray);
    vm.stopPrank();
    console2.log("character2 take order success 2");
    assertTrue(Order.getIsDone(1));
    assertEq(CharFund.getGold(characterId2), prevChar2Fund + 100 + 100); // 200 + 100 - 0% fee + 100 - 0% fee
    assertTrue(StorageEquipmentUtils.hasEquipment(characterId1, 1, 3));
    assertTrue(StorageEquipmentUtils.hasEquipment(characterId1, 1, 2));
    assertEq(Equipment.getCharacterId(2), characterId1);
    assertEq(Equipment.getCharacterId(3), characterId1);
  }

  function test_PlaceOrderWithFameOrAchievement() public {
    vm.startPrank(worldDeployer);

    CharOtherItem.setAmount(characterId1, 1, 100);
    CharCurrentStats.setWeight(characterId1, CharCurrentStats.getWeight(characterId1) + 100);
    CharOtherItem.setAmount(characterId2, 1, 100);
    CharCurrentStats.setWeight(characterId2, CharCurrentStats.getWeight(characterId2) + 100);
    // CharStats2.setFame(characterId1, 1050);
    CharFund.setGold(characterId1, 200);
    // CharStats2.setFame(characterId2, 1050);
    CharFund.setGold(characterId2, 200);
    vm.stopPrank();

    // buy equipment
    OrderParams memory orderParams = OrderParams({
      orderId: 0,
      cityId: city1,
      equipmentId: 0,
      itemId: 33,
      amount: 2,
      unitPrice: 100,
      currency: CurrencyType.Gold,
      isBuy: true
    });
    vm.expectRevert(); // fame too low
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharAchievement.pushAchievementIds(characterId1, 3);
    // The value is stored at length-1, but we add 1 to all indexes
    // and use 0 as a sentinel value
    uint256 index = CharAchievement.lengthAchievementIds(characterId1);
    CharAchievementIndex.set(characterId1, 3, index);
    vm.stopPrank();

    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();
  }

  function test_PlaceOrderWithCrystal() public {
    vm.startPrank(worldDeployer);

    CharOtherItem.setAmount(characterId1, 1, 100);
    CharCurrentStats.setWeight(characterId1, CharCurrentStats.getWeight(characterId1) + 100);

    CharOtherItem.setAmount(characterId2, 1, 100);
    CharCurrentStats.setWeight(characterId2, CharCurrentStats.getWeight(characterId2) + 100);

    CharacterFundUtils.increaseCrystal(characterId1, 1000);

    CharStats2.setFame(characterId1, 1050);
    CharStats2.setFame(characterId2, 1050);
    vm.stopPrank();

    // buy item
    OrderParams memory orderParams = OrderParams({
      orderId: 0,
      cityId: city1,
      equipmentId: 0,
      itemId: 1,
      amount: 5,
      unitPrice: 99,
      currency: CurrencyType.Crystal,
      isBuy: true
    });

    vm.expectRevert(); // invalid price, too small
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    orderParams.unitPrice = 101;
    vm.expectRevert(); // invalid price, must be multiple of 100
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    orderParams.unitPrice = 100;
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    orderParams.orderId = 1;
    orderParams.unitPrice = 150;
    vm.expectRevert(); // try to update invalid price, must be multiple of 100
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    orderParams.unitPrice = 200;
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();

    assertEq(CharFund.getCrystal(characterId1), 0); // all crystal locked in order

    // take order
    vm.startPrank(worldDeployer);
    CityData memory city2Data = City.get(city2);
    RestrictLocV2.set(city2Data.x, city2Data.y, city2, true);
    CrystalFee.set(1, 5); // 5% fee when take order in kingdom 1
    CrystalFee.set(2, 3); // 3% fee when take order in kingdom 2
    vm.stopPrank();
    _moveToCity(characterId2, city2); // with crystal, no need to be in the same city, but must be in another capital
    TakeOrderParams memory takeOrderParams = TakeOrderParams({ orderId: 1, amount: 5, equipmentIds: new uint256[](0) });
    TakeOrderParams[] memory takeOrderParamsArray = new TakeOrderParams[](1);
    takeOrderParamsArray[0] = takeOrderParams;
    vm.startPrank(player2);
    world.app__takeOrder(characterId2, takeOrderParamsArray);
    vm.stopPrank();
    FillOrderData memory fillOrder = FillOrder.get(1);
    console2.log("fill order city id", fillOrder.cityId);
    console2.log("fill order character id", fillOrder.characterId);
    console2.log("fill order equipment id", fillOrder.equipmentId);
    console2.log("fill order item id", fillOrder.itemId);
    console2.log("fill order amount", fillOrder.amount);
    console2.log("fill order unit price", fillOrder.unitPrice);
    console2.log("fill order is buy", fillOrder.isBuy);
    console2.log("fill order timestamp", fillOrder.filledAt);
    assertEq(fillOrder.cityId, city1);
    assertEq(fillOrder.characterId, characterId2);
    assertEq(fillOrder.equipmentId, 0);
    assertEq(fillOrder.itemId, 1);
    assertEq(fillOrder.amount, 5);
    assertEq(fillOrder.unitPrice, 200);
    assertEq(fillOrder.isBuy, false);

    uint32 char2Crystal = CharFund.getCrystal(characterId2);
    console2.log("character2 crystal after take order", char2Crystal);
    uint32 platFormFee = (1000 * Config.PLATFORM_FEE_PERCENTAGE + 99) / 100;
    uint32 finalOrderValue = 1000 - platFormFee;
    uint32 kingdomFee = (finalOrderValue * CrystalFee.get(2)) / 100; // 29
    assertEq(char2Crystal, finalOrderValue - kingdomFee); // 970 - 29 = 941
    // uint32 cityVaultCrystal = uint32(CityVault2V2.getCrystal(1));
    // console2.log("city vault crystal after take order", cityVaultCrystal);
    // assertEq(cityVaultCrystal, kingdomFee);

    uint32 city2VaultCrystal = uint32(CityVault2V2.getCrystal(2));
    console2.log("city2 vault crystal after take order", city2VaultCrystal);
    assertEq(city2VaultCrystal, kingdomFee);

    assertEq(CharOtherItem.getAmount(characterId1, 1), 100);
    assertEq(CharOtherItemStorage.getAmount(characterId1, 1, 1), 5); // just bought 5, so 5 in storage
    assertEq(CharOtherItem.getAmount(characterId2, 1), 95); // just sold 5, so 95 left

    _moveAllToCity(city2);

    uint32 char1CrystalBalance = CharFund.getCrystal(characterId1);
    console2.log("character1 crystal balance", char1CrystalBalance);
    assertEq(char1CrystalBalance, 0); // spent all crystal in previous order

    orderParams.orderId = 0; // to create new order
    orderParams.cityId = city2;
    orderParams.unitPrice = 100;
    orderParams.isBuy = false;
    // test place order sell with crystal
    vm.startPrank(player1);
    world.app__placeOrder(characterId1, orderParams);
    vm.stopPrank();
    OrderData memory order = Order.get(2);
    assertEq(order.isBuy, false);

    // test take order sell with crystal
    takeOrderParams = TakeOrderParams({ orderId: 2, amount: 5, equipmentIds: new uint256[](0) });
    takeOrderParamsArray[0] = takeOrderParams;
    vm.startPrank(player2);
    world.app__takeOrder(characterId2, takeOrderParamsArray);
    vm.stopPrank();
    fillOrder = FillOrder.get(2);
    console2.log("fill order city id", fillOrder.cityId);
    console2.log("fill order character id", fillOrder.characterId);
    console2.log("fill order equipment id", fillOrder.equipmentId);
    console2.log("fill order item id", fillOrder.itemId);
    console2.log("fill order amount", fillOrder.amount);
    console2.log("fill order unit price", fillOrder.unitPrice);
    console2.log("fill order is buy", fillOrder.isBuy);
    assertEq(fillOrder.cityId, city2);
    assertEq(fillOrder.characterId, characterId2);
    assertEq(fillOrder.equipmentId, 0);
    assertEq(fillOrder.itemId, 1);
    assertEq(fillOrder.amount, 5);
    assertEq(fillOrder.unitPrice, 100);
    assertEq(fillOrder.isBuy, true);

    char2Crystal = CharFund.getCrystal(characterId2);
    console2.log("character2 crystal after take order", char2Crystal);
    assertEq(char2Crystal, 441); // 941 - 5 * 100 (no fee for taker of a sell order)
    uint32 orderValue = 5 * 100;
    platFormFee = (orderValue * Config.PLATFORM_FEE_PERCENTAGE + 99) / 100;
    finalOrderValue = orderValue - platFormFee;
    kingdomFee = (finalOrderValue * CrystalFee.get(1)) / 100; // character 1 is the seller, so use kingdom 1 fee
    uint32 newChar1Crystal = CharFund.getCrystal(characterId1);
    assertEq(newChar1Crystal, char1CrystalBalance + (finalOrderValue - kingdomFee));
    uint32 cityVaultCrystal = uint32(CityVault2V2.getCrystal(city1));
    console2.log("city vault crystal after take order", cityVaultCrystal);
    assertEq(cityVaultCrystal, kingdomFee); // (500 - 500 * 0.03) * 0.05 = 24 // 3% platform fee, then 5% kingdom fee
    assertEq(CharOtherItem.getAmount(characterId1, 1), 95); // just sold 5, so 95 left
    assertEq(CharOtherItem.getAmount(characterId2, 1), 100); // sold 5, bought 5, back to 100
  }

  function _moveToCity(uint256 characterId, uint256 cityId) internal {
    int32 x = City.getX(cityId);
    int32 y = City.getY(cityId);
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId, x, y);
    vm.stopPrank();
  }

  function _moveAllToCity(uint256 cityId) internal {
    int32 x = City.getX(cityId);
    int32 y = City.getY(cityId);
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(characterId1, x, y);
    CharacterPositionUtils.moveToLocation(characterId2, x, y);
    vm.stopPrank();
  }
}
