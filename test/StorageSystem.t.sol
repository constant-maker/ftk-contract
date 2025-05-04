pragma solidity >=0.8.24;

import { Vm } from "forge-std/Vm.sol";
import {
  CharStorage,
  CharStorageData,
  CharOtherItemStorage,
  CharInventory,
  CharInventoryData,
  CharCurrentStats,
  CharFund,
  ItemWeightCache,
  Item,
  CharMigration,
  CharStorageMigration
} from "@codegen/index.sol";

import { CharOtherItem } from "@codegen/tables/CharOtherItem.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { CharacterFundUtils, CharacterItemUtils } from "@utils/index.sol";
import { console2 } from "forge-std/console2.sol";
import { Config } from "@common/Config.sol";
import { ItemsActionData } from "@common/Types.sol";

contract StorageSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  uint256 healingPotion = 35;
  uint256 cityId = 1;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();
    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_UpgradeStorageSuccessfully() external {
    vm.startPrank(worldDeployer);
    CharacterFundUtils.increaseGold(characterId, 3 * Config.UPGRADE_STORAGE_COST);
    vm.stopPrank();
    // the default is 300 but need to upgrade or transfer item in to trigger this
    assertEq(CharStorage.getMaxWeight(characterId, cityId), 0);
    vm.startPrank(player);
    world.app__upgradeStorage(characterId, cityId);
    world.app__upgradeStorage(characterId, cityId);
    vm.stopPrank();
    assertEq(
      CharStorage.getMaxWeight(characterId, cityId),
      Config.INIT_STORAGE_MAX_WEIGHT + 2 * Config.STORAGE_MAX_WEIGHT_INCREMENT
    );
    assertEq(CharFund.getGold(characterId), 0);
  }

  function test_StorageLevel5() external {
    vm.startPrank(worldDeployer);
    CharacterFundUtils.increaseGold(characterId, 100_000);
    CharOtherItem.setAmount(characterId, healingPotion, 500);
    vm.stopPrank();
    // the default is 300 but need to upgrade or transfer item in to trigger this
    assertEq(CharStorage.getMaxWeight(characterId, cityId), 0);
    vm.startPrank(player);
    world.app__upgradeStorage(characterId, cityId);
    world.app__upgradeStorage(characterId, cityId);
    world.app__upgradeStorage(characterId, cityId);
    world.app__upgradeStorage(characterId, cityId);
    world.app__upgradeStorage(characterId, cityId);
    vm.stopPrank();
    assertEq(CharStorage.getMaxWeight(characterId, cityId), 800);

    ItemsActionData memory transferInData = ItemsActionData({
      equipmentIds: new uint256[](0),
      toolIds: new uint256[](0),
      itemIds: new uint256[](1),
      itemAmounts: new uint32[](1)
    });
    transferInData.itemIds[0] = healingPotion;
    transferInData.itemAmounts[0] = 400;
    ItemsActionData memory emptyTransferOutData;
    vm.startPrank(player);
    world.app__updateStorage(characterId, cityId, transferInData, emptyTransferOutData);
    vm.stopPrank();
    uint32 currentWeight = CharStorage.getWeight(characterId, cityId);
    assertEq(currentWeight, 800);
  }

  function test_UpdateStorageSuccessfully() external {
    ItemsActionData memory transferInData = ItemsActionData({
      equipmentIds: new uint256[](1),
      toolIds: new uint256[](2),
      itemIds: new uint256[](1),
      itemAmounts: new uint32[](1)
    });
    uint32 prevWeight = CharCurrentStats.getWeight(characterId);
    console2.log("prevWeight", prevWeight);
    transferInData.equipmentIds[0] = 1;
    transferInData.toolIds[0] = 1;
    transferInData.toolIds[1] = 2;
    transferInData.itemIds[0] = healingPotion;
    transferInData.itemAmounts[0] = 1;
    ItemsActionData memory emptyTransferOutData;
    vm.startPrank(player);
    world.app__updateStorage(characterId, cityId, transferInData, emptyTransferOutData);
    vm.stopPrank();

    CharInventoryData memory charInventory = CharInventory.get(characterId);
    assertEq(charInventory.toolIds.length, 4);
    assertEq(charInventory.equipmentIds.length, 0);
    uint32 potionAmount = CharOtherItem.getAmount(characterId, healingPotion);
    console2.log("potionAmount", potionAmount);
    assertEq(potionAmount, 0);
    assertEq(CharCurrentStats.getWeight(characterId), 8);

    CharStorageData memory charStorage = CharStorage.get(characterId, cityId);
    assertEq(charStorage.toolIds[0], 1);
    assertEq(charStorage.equipmentIds[0], 1);
    uint32 storagePotionAmount = CharOtherItemStorage.getAmount(characterId, cityId, healingPotion);
    console2.log("storagePotionAmount", storagePotionAmount);
    assertEq(storagePotionAmount, 1);
    assertEq(charStorage.weight, 9);

    ItemsActionData memory emptyTransferInData;
    ItemsActionData memory transferOutData = ItemsActionData({
      equipmentIds: new uint256[](1),
      toolIds: new uint256[](1),
      itemIds: new uint256[](1),
      itemAmounts: new uint32[](1)
    });
    transferOutData.equipmentIds[0] = 1;
    transferOutData.toolIds[0] = 2;
    transferOutData.itemIds[0] = healingPotion;
    transferOutData.itemAmounts[0] = 1;

    vm.startPrank(player);
    world.app__updateStorage(characterId, cityId, emptyTransferInData, transferOutData);
    vm.stopPrank();
    charStorage = CharStorage.get(characterId, cityId);

    assertEq(charStorage.toolIds[0], 1);
    assertEq(charStorage.equipmentIds.length, 0);
    storagePotionAmount = CharOtherItemStorage.getAmount(characterId, cityId, healingPotion);
    console2.log("new storagePotionAmount", storagePotionAmount);
    assertEq(storagePotionAmount, 0);
    assertEq(charStorage.weight, 2);
  }

  function test_RevertExceedStorageMaxWeight() external {
    vm.startPrank(worldDeployer);
    CharStorage.setMaxWeight(characterId, cityId, 5);
    vm.stopPrank();
    ItemsActionData memory transferInData = ItemsActionData({
      equipmentIds: new uint256[](1),
      toolIds: new uint256[](2),
      itemIds: new uint256[](1),
      itemAmounts: new uint32[](1)
    });
    uint32 prevWeight = CharCurrentStats.getWeight(characterId);
    console2.log("prevWeight", prevWeight);
    transferInData.equipmentIds[0] = 1;
    transferInData.toolIds[0] = 1;
    transferInData.toolIds[1] = 2;
    transferInData.itemIds[0] = healingPotion;
    transferInData.itemAmounts[0] = 1;
    ItemsActionData memory emptyTransferOutData;
    // revert because of exceeding the max weight
    vm.expectRevert();
    vm.startPrank(player);
    world.app__updateStorage(characterId, cityId, transferInData, emptyTransferOutData);
    vm.stopPrank();

    // set new max weight and retry, expect success
    vm.startPrank(worldDeployer);
    CharStorage.setMaxWeight(characterId, cityId, 10);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__updateStorage(characterId, cityId, transferInData, emptyTransferOutData);
    vm.stopPrank();

    CharInventoryData memory charInventory = CharInventory.get(characterId);
    assertEq(charInventory.toolIds.length, 4);
    assertEq(charInventory.equipmentIds.length, 0);
    uint32 potionAmount = CharOtherItem.getAmount(characterId, healingPotion);
    console2.log("potionAmount", potionAmount);
    assertEq(potionAmount, 0);
    assertEq(CharCurrentStats.getWeight(characterId), 8);

    CharStorageData memory charStorage = CharStorage.get(characterId, cityId);
    assertEq(charStorage.toolIds[0], 1);
    assertEq(charStorage.equipmentIds[0], 1);
    uint32 storagePotionAmount = CharOtherItemStorage.getAmount(characterId, cityId, healingPotion);
    console2.log("storagePotionAmount", storagePotionAmount);
    assertEq(storagePotionAmount, 1);
    assertEq(charStorage.weight, 9);
  }

  // function test_WeightMigration() external {
  //   vm.startPrank(worldDeployer);
  //   uint32 prevWeight = CharCurrentStats.getWeight(characterId);
  //   // weight is 17 at the beginning
  //   console2.log("prevWeight", prevWeight);

  //   ItemWeightCache.setWeight(30, 3);
  //   Item.setWeight(30, 1);
  //   // add more swords to the inventory
  //   CharacterItemUtils.addNewItem(characterId, 30); // equipment id 2
  //   CharacterItemUtils.addNewItem(characterId, 30); // equipment id 3
  //   CharacterItemUtils.addNewItem(characterId, 30); // equipment id 4
  //   vm.stopPrank();
  //   // weight now is 17 + 3 * 1 = 20
  //   uint32 newWeight = CharCurrentStats.getWeight(characterId);
  //   console2.log("newWeight", newWeight);
  //   assertEq(newWeight, 20);
  //   assertTrue(!CharMigration.get(characterId, 1));
  //   assertTrue(CharMigration.get(characterId, 2));
  //   assertTrue(CharMigration.get(characterId, 3));
  //   assertTrue(CharMigration.get(characterId, 4));
  //   assertTrue(!CharStorageMigration.get(characterId, 1));
  //   assertTrue(CharStorageMigration.get(characterId, 2));
  //   assertTrue(CharStorageMigration.get(characterId, 3));
  //   assertTrue(CharStorageMigration.get(characterId, 4));

  //   // transfer in 1 sword
  //   ItemsActionData memory transferInData = ItemsActionData({
  //     equipmentIds: new uint256[](1),
  //     toolIds: new uint256[](0),
  //     itemIds: new uint256[](0),
  //     itemAmounts: new uint32[](0)
  //   });
  //   transferInData.equipmentIds[0] = 1;
  //   ItemsActionData memory emptyTransferOutData;
  //   vm.startPrank(player);
  //   world.app__updateStorage(characterId, cityId, transferInData, emptyTransferOutData);
  //   vm.stopPrank();

  //   CharInventoryData memory charInventory = CharInventory.get(characterId);
  //   assertEq(charInventory.equipmentIds.length, 3);

  //   CharStorageData memory charStorage = CharStorage.get(characterId, cityId);
  //   assertEq(charStorage.equipmentIds[0], 1);

  //   uint32 storageWeight = CharStorage.getWeight(characterId, cityId);
  //   console2.log("storageWeight", storageWeight);
  //   assertEq(storageWeight, 1);
  //   assertTrue(CharMigration.get(characterId, 1));
  //   assertTrue(CharStorageMigration.get(characterId, 1));
  //   newWeight = CharCurrentStats.getWeight(characterId);
  //   console2.log("char newWeight", newWeight);
  //   assertEq(newWeight, 17);

  //   // ItemsActionData memory emptyTransferInData;
  //   // ItemsActionData memory transferOutData = ItemsActionData({
  //   //   equipmentIds: new uint256[](1),
  //   //   toolIds: new uint256[](1),
  //   //   itemIds: new uint256[](1),
  //   //   itemAmounts: new uint32[](1)
  //   // });
  //   // transferOutData.equipmentIds[0] = 1;
  //   // transferOutData.toolIds[0] = 2;
  //   // transferOutData.itemIds[0] = healingPotion;
  //   // transferOutData.itemAmounts[0] = 1;

  //   // vm.startPrank(player);
  //   // world.app__updateStorage(characterId, cityId, emptyTransferInData, transferOutData);
  //   // vm.stopPrank();
  //   // charStorage = CharStorage.get(characterId, cityId);

  //   // assertEq(charStorage.toolIds[0], 1);
  //   // assertEq(charStorage.equipmentIds.length, 0);
  //   // storagePotionAmount = CharOtherItemStorage.getAmount(characterId, cityId, healingPotion);
  //   // console2.log("new storagePotionAmount", storagePotionAmount);
  //   // assertEq(storagePotionAmount, 0);
  //   // assertEq(charStorage.weight, 2);
  // }
}
