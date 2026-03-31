pragma solidity >=0.8.24;

import { Vm } from "forge-std/Vm.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { MoveSystemFixture } from "@fixtures/MoveSystemFixture.sol";
import {
  NonOccupyTile,
  CharOtherItem,
  CharStats,
  CharFund,
  CharInfo,
  CharPositionData,
  Tile,
  TileInventory,
  TileData
} from "@codegen/index.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { TileInventoryUtils, LootItems } from "@utils/TileInventoryUtils.sol";
import { Config } from "@common/Config.sol";
import { Errors } from "@common/Errors.sol";
import { TestHelper } from "./TestHelper.sol";
import { console2 } from "forge-std/console2.sol";
import { KingSetting, Alliance } from "@codegen/index.sol";

contract TileSystemTest is WorldFixture, SpawnSystemFixture, MoveSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  uint256 woodTier1_Id = 1;
  uint256 stoneTier1_Id = 6;
  uint256 fishTier1_Id = 8;
  uint256 oreTier1_Id = 10;
  uint256 wheatTier1_Id = 12;
  uint256 berriesTier1_Id = 14;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, MoveSystemFixture) {
    WorldFixture.setUp();
    characterId = _createDefaultCharacter(player);
  }

  function test_CityShouldHaveTileInfo() external {
    CharPositionData memory charPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    int32 x = charPosition.x;
    int32 y = charPosition.y;
    uint8 kingdomId = Tile.getKingdomId(x, y);
    assertEq(kingdomId, CharInfo.getKingdomId(characterId));
  }

  function test_ShouldOccupySuccessfully() external {
    vm.warp(block.timestamp + 100_000);
    _goUp(player, characterId);

    CharPositionData memory charPosition = CharacterPositionUtils.getCurrentPosition(characterId);

    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, woodTier1_Id, 20);
    InventoryItemUtils.addItem(characterId, stoneTier1_Id, 20);
    InventoryItemUtils.addItem(characterId, fishTier1_Id, 20);

    InventoryItemUtils.addItem(characterId, oreTier1_Id, 30);
    InventoryItemUtils.addItem(characterId, wheatTier1_Id, 30);
    InventoryItemUtils.addItem(characterId, berriesTier1_Id, 30);

    CharFund.setGold(characterId, 20);

    NonOccupyTile.set(charPosition.x, charPosition.y, true);
    vm.stopPrank();
    vm.expectRevert(); // tile is not occupiable
    vm.startPrank(player);
    world.app__occupyTile(characterId);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    NonOccupyTile.set(charPosition.x, charPosition.y, false);
    vm.stopPrank();
    vm.startPrank(player);
    world.app__occupyTile(characterId);
    vm.stopPrank();

    assertEq(CharOtherItem.getAmount(characterId, oreTier1_Id), 20);
    assertEq(CharOtherItem.getAmount(characterId, wheatTier1_Id), 20);
    assertEq(CharOtherItem.getAmount(characterId, berriesTier1_Id), 20);
    assertEq(CharFund.getGold(characterId), 15);

    _goUp(player, characterId);
    vm.startPrank(player);
    world.app__occupyTile(characterId);
    vm.stopPrank();
    assertEq(CharOtherItem.getAmount(characterId, woodTier1_Id), 10);
    assertEq(CharOtherItem.getAmount(characterId, stoneTier1_Id), 10);
    assertEq(CharOtherItem.getAmount(characterId, fishTier1_Id), 10);
    assertEq(CharFund.getGold(characterId), 10);
    charPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    console2.log("position x", charPosition.x);
    console2.log("position y", charPosition.y);

    _goUp(player, characterId);
    _goUp(player, characterId);
    vm.expectRevert();
    vm.startPrank(player);
    world.app__occupyTile(characterId);
    vm.stopPrank();

    _goDown(player, characterId);
    _goRight(player, characterId);
    vm.expectRevert();
    vm.startPrank(player);
    world.app__occupyTile(characterId);
    vm.stopPrank();
    charPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    console2.log("position x", charPosition.x);
    console2.log("position y", charPosition.y);

    _goDown(player, characterId);
    vm.startPrank(player);
    world.app__occupyTile(characterId);
    vm.stopPrank();
    assertEq(CharFund.getGold(characterId), 5);

    // tile is locked
    vm.expectRevert();
    vm.startPrank(player);
    world.app__occupyTile(characterId);
    vm.stopPrank();

    vm.warp(block.timestamp + 28_800);
    _goUp(player, characterId);
    _goDown(player, characterId);
    charPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    vm.startPrank(worldDeployer);
    Tile.setKingdomId(charPosition.x, charPosition.y, 4);
    vm.stopPrank();
    vm.warp(block.timestamp + 301);
    vm.startPrank(player);
    world.app__occupyTile(characterId);
    vm.stopPrank();
    assertEq(CharFund.getGold(characterId), 0);

    assertEq(CharStats.getFame(characterId), 1040);
  }

  function test_OccupyAllianceType() external {
    vm.warp(block.timestamp + 100_000);
    _goUp(player, characterId);

    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, woodTier1_Id, 20);
    InventoryItemUtils.addItem(characterId, stoneTier1_Id, 20);
    InventoryItemUtils.addItem(characterId, fishTier1_Id, 20);

    InventoryItemUtils.addItem(characterId, oreTier1_Id, 30);
    InventoryItemUtils.addItem(characterId, wheatTier1_Id, 30);
    InventoryItemUtils.addItem(characterId, berriesTier1_Id, 30);

    CharFund.setGold(characterId, 20);

    KingSetting.setCaptureTilePenalty(CharInfo.getKingdomId(characterId), 100);
    Alliance.set(1, 2, true, true);
    vm.stopPrank();

    uint32 charFame = CharStats.getFame(characterId);

    vm.startPrank(player);
    world.app__occupyTile(characterId);
    vm.stopPrank();
    assertEq(CharOtherItem.getAmount(characterId, oreTier1_Id), 20);
    assertEq(CharOtherItem.getAmount(characterId, wheatTier1_Id), 20);
    assertEq(CharOtherItem.getAmount(characterId, berriesTier1_Id), 20);
    assertEq(CharFund.getGold(characterId), 15);

    uint32 newFame = CharStats.getFame(characterId);
    assertEq(newFame, charFame + 10); // got 10 fame for occupying tile

    _goUp(player, characterId);
    vm.warp(block.timestamp + 100_000);
    CharPositionData memory charPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    vm.startPrank(worldDeployer);
    Tile.setKingdomId(charPosition.x, charPosition.y, 2);
    vm.stopPrank();
    vm.startPrank(player);
    world.app__occupyTile(characterId);
    vm.stopPrank();
    assertEq(CharOtherItem.getAmount(characterId, woodTier1_Id), 10);
    assertEq(CharOtherItem.getAmount(characterId, stoneTier1_Id), 10);
    assertEq(CharOtherItem.getAmount(characterId, fishTier1_Id), 10);
    assertEq(CharFund.getGold(characterId), 10);
    charPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    console2.log("position x", charPosition.x);
    console2.log("position y", charPosition.y);

    newFame = CharStats.getFame(characterId);
    assertEq(newFame, charFame + 10 - 100); // penalty 100 fame for occupying tile in alliance territory
  }

  function test_LootItems_RevertInvalidParams() external {
    uint256[] memory equipmentIds = new uint256[](0);
    uint256[] memory itemIds = new uint256[](1);
    uint32[] memory itemAmounts = new uint32[](0);
    itemIds[0] = woodTier1_Id;

    vm.expectRevert(abi.encodeWithSelector(Errors.TileSystem_InvalidLootParams.selector, uint256(1), uint256(0)));
    vm.startPrank(player);
    world.app__lootItems(
      characterId, LootItems({ equipmentIds: equipmentIds, itemIds: itemIds, itemAmounts: itemAmounts })
    );
    vm.stopPrank();
  }

  function test_LootItems_RevertNoItemInThisTile_WhenExpired() external {
    CharPositionData memory charPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    int32 x = charPosition.x;
    int32 y = charPosition.y;

    vm.startPrank(worldDeployer);
    TileInventory.setLastDropTime(x, y, block.timestamp - Config.TILE_ITEM_AVAILABLE_DURATION - 1);
    vm.stopPrank();

    uint256[] memory equipmentIds = new uint256[](0);
    uint256[] memory itemIds = new uint256[](1);
    uint32[] memory itemAmounts = new uint32[](1);
    itemIds[0] = woodTier1_Id;
    itemAmounts[0] = 1;

    vm.expectRevert(abi.encodeWithSelector(Errors.TileSystem_NoItemInThisTile.selector, x, y, TileInventory.getLastDropTime(x, y)));
    vm.startPrank(player);
    world.app__lootItems(
      characterId, LootItems({ equipmentIds: equipmentIds, itemIds: itemIds, itemAmounts: itemAmounts })
    );
    vm.stopPrank();
  }

  function test_LootItems_RevertItemNotFound() external {
    CharPositionData memory charPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    int32 x = charPosition.x;
    int32 y = charPosition.y;

    vm.startPrank(worldDeployer);
    TileInventory.setLastDropTime(x, y, block.timestamp);
    vm.stopPrank();

    uint256[] memory equipmentIds = new uint256[](0);
    uint256[] memory itemIds = new uint256[](1);
    uint32[] memory itemAmounts = new uint32[](1);
    itemIds[0] = woodTier1_Id;
    itemAmounts[0] = 1;

    vm.expectRevert(abi.encodeWithSelector(Errors.TileSystem_ItemNotFound.selector, x, y, woodTier1_Id));
    vm.startPrank(player);
    world.app__lootItems(
      characterId, LootItems({ equipmentIds: equipmentIds, itemIds: itemIds, itemAmounts: itemAmounts })
    );
    vm.stopPrank();
  }

  function test_LootItems_Success() external {
    CharPositionData memory charPosition = CharacterPositionUtils.getCurrentPosition(characterId);
    int32 x = charPosition.x;
    int32 y = charPosition.y;

    vm.startPrank(worldDeployer);
    TileInventoryUtils.addItem(x, y, woodTier1_Id, 5);
    vm.stopPrank();

    uint256[] memory equipmentIds = new uint256[](0);
    uint256[] memory itemIds = new uint256[](1);
    uint32[] memory itemAmounts = new uint32[](1);
    itemIds[0] = woodTier1_Id;
    itemAmounts[0] = 3;

    uint32 balanceBefore = CharOtherItem.getAmount(characterId, woodTier1_Id);

    vm.startPrank(player);
    world.app__lootItems(
      characterId, LootItems({ equipmentIds: equipmentIds, itemIds: itemIds, itemAmounts: itemAmounts })
    );
    vm.stopPrank();

    assertEq(CharOtherItem.getAmount(characterId, woodTier1_Id), balanceBefore + 3);
    assertEq(TileInventory.getItemOtherItemAmounts(x, y, 0), 2);
  }
}
