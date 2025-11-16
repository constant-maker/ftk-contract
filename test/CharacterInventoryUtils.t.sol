pragma solidity >=0.8.24;

import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture } from "./fixtures/index.sol";
import { InventoryEquipmentUtils, InventoryToolUtils, InventoryItemUtils } from "@utils/index.sol";
import { CharInventory, CharInventoryData, CharCurrentStats, CharOtherItem } from "@codegen/index.sol";
import { console } from "forge-std/console.sol";

contract CharacterInventoryUtilsTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    uint32 weight = CharCurrentStats.getWeight(characterId);
    _claimWelcomePackages(player, characterId);
    uint32 currentWeight = CharCurrentStats.getWeight(characterId);

    CharInventoryData memory characterInventory = CharInventory.get(characterId);
    assertEq(characterInventory.toolIds.length, 6);

    assertEq(weight + 19, currentWeight);
  }

  function test_CanBringManyExpBuffItem() external {
    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, 358, 50); // exp buff item
    vm.stopPrank();
    assertEq(CharOtherItem.getAmount(characterId, 358), 50);
  }
}
