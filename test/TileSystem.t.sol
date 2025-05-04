pragma solidity >=0.8.24;

import { Vm } from "forge-std/Vm.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { MoveSystemFixture } from "@fixtures/MoveSystemFixture.sol";
import { TileInfo3, TileInfo3Data } from "@codegen/tables/TileInfo3.sol";
import { CharPosition, CharPositionData } from "@codegen/tables/CharPosition.sol";
import { CharInfo } from "@codegen/tables/CharInfo.sol";
import { CharFund } from "@codegen/tables/CharFund.sol";
import { CharStats2 } from "@codegen/tables/CharStats2.sol";
import { CharOtherItem } from "@codegen/tables/CharOtherItem.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { TestHelper } from "./TestHelper.sol";
import { console2 } from "forge-std/console2.sol";

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
    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(characterId);
    int32 x = charPosition.x;
    int32 y = charPosition.y;
    uint8 kingdomId = TileInfo3.getKingdomId(x, y);
    assertEq(kingdomId, CharInfo.getKingdomId(characterId));
  }

  function test_ShouldOccupySuccessfully() external {
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
    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(characterId);
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
    charPosition = CharacterPositionUtils.currentPosition(characterId);
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

    vm.warp(block.timestamp + 3600);
    vm.startPrank(player);
    world.app__occupyTile(characterId);
    vm.stopPrank();
    assertEq(CharFund.getGold(characterId), 0);

    assertEq(CharStats2.getFame(characterId), 1030);
  }
}
