pragma solidity >=0.8.24;

import { CharOtherItem, CharCurrentStats, CharStats } from "@codegen/index.sol";
import { WorldFixture, SpawnSystemFixture } from "@fixtures/index.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";

contract ConsumeSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  uint256 berryId = 14;
  uint256 healPotionId = 66;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);

    _claimWelcomePackages(player, characterId);
  }

  function test_ConsumeBerriesSuccessfully() external {
    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, berryId, 1000);
    CharCurrentStats.setHp(characterId, 1);
    vm.stopPrank();
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);

    vm.startPrank(player);
    world.app__eatBerries(characterId, berryId, 10);
    vm.stopPrank();

    uint32 currentHp = CharCurrentStats.getHp(characterId);
    assertEq(currentHp, 11);
    uint32 currentBerryAmount = CharOtherItem.getAmount(characterId, berryId);
    assertEq(currentBerryAmount, 990);

    uint32 newCurrentWeight = CharCurrentStats.getWeight(characterId);
    assertEq(newCurrentWeight + 10, currentWeight);

    uint32 maxHp = CharStats.getHp(characterId);

    vm.startPrank(player);
    world.app__eatBerries(characterId, berryId, 990);
    vm.stopPrank();

    currentHp = CharCurrentStats.getHp(characterId);
    assertEq(currentHp, maxHp);
    currentBerryAmount = CharOtherItem.getAmount(characterId, berryId);
    assertEq(currentBerryAmount, 0);
    newCurrentWeight = CharCurrentStats.getWeight(characterId);
    assertEq(newCurrentWeight + 1000, currentWeight);
  }

  function test_ConsumePotionSuccessfully() external {
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);
    vm.startPrank(worldDeployer);
    CharCurrentStats.setHp(characterId, 1);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__consumeItems(characterId, healPotionId, 1);
    vm.stopPrank();

    uint32 currentHp = CharCurrentStats.getHp(characterId);
    assertEq(currentHp, 51);
    uint32 currentPotionAmount = CharOtherItem.getAmount(characterId, healPotionId);
    assertEq(currentPotionAmount, 0);
    uint32 newCurrentWeight = CharCurrentStats.getWeight(characterId);
    assertEq(newCurrentWeight + 2, currentWeight);

    uint32 maxHp = CharStats.getHp(characterId);

    vm.startPrank(worldDeployer);
    CharCurrentStats.setHp(characterId, maxHp - 1);
    InventoryItemUtils.addItem(characterId, healPotionId, 1);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__consumeItems(characterId, healPotionId, 1);
    vm.stopPrank();

    currentHp = CharCurrentStats.getHp(characterId);
    assertEq(currentHp, maxHp);
    currentPotionAmount = CharOtherItem.getAmount(characterId, healPotionId);
    assertEq(currentPotionAmount, 0);
  }

  function test_RevertConsumeExceedBalance() external {
    vm.expectRevert();
    vm.startPrank(player);
    world.app__eatBerries(characterId, berryId, 10);
    vm.stopPrank();

    vm.expectRevert();
    vm.startPrank(player);
    world.app__consumeItems(characterId, healPotionId, 2);
    vm.stopPrank();
  }
}
