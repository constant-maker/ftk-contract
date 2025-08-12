pragma solidity >=0.8.24;

import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";
import { console2 } from "forge-std/console2.sol";
import {
  KingElection,
  CharInfo,
  CharStats,
  CharStats2,
  CharCurrentStats,
  CharCurrentStatsData,
  CharRole,
  CharRoleCounter,
  CResourceRequire,
  CityVault,
  RestrictLocation,
  TileInfo3,
  CityCounter,
  City,
  CityData,
  CharFund,
  CVaultHistory,
  CVaultHistoryData,
  CharOtherItem,
  CharPositionData
} from "@codegen/index.sol";
import { RoleType } from "@codegen/common.sol";
import { CharacterPositionUtils, InventoryItemUtils } from "@utils/index.sol";

contract CitySystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address candidate = makeAddr("candidate");
  uint256 candidateId;

  address voter = makeAddr("voter");
  uint256 voterId;

  address voter2 = makeAddr("voter2");
  uint256 voter2Id;

  uint32 constant KING_MIN_FAME_REQUIRE = 2000;
  uint32 constant VOTER_MIN_FAME_REQUIRE = 1050;
  uint32 constant TERM_DURATION = 1_209_600; // 14 days in seconds
  uint32 constant OFFSET_DURATION = 172_800; // 2 days in seconds
  uint256 constant KING_ACHIEVEMENT_ID = 10;

  uint256 cityId = 1;
  int32 newCityX = -10;
  int32 newCityY = -5;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    candidateId = _createDefaultCharacter(candidate);
    _claimWelcomePackages(candidate, candidateId);

    voterId = _createCharacterWithName(voter, "abc");
    _claimWelcomePackages(voter, voterId);

    voter2Id = _createCharacterWithNameAndKingdomId(voter2, "123", 2);
    _claimWelcomePackages(voter2, voter2Id);
  }

  function test_CitySystem() external {
    // test revert set city place
    vm.expectRevert(); // must be in city
    vm.startPrank(candidate);
    world.app__setNewCity(candidateId, newCityX, newCityY, "New City");
    vm.stopPrank();

    uint256[] memory candidateIds;
    uint32[] memory votesReceived;

    vm.startPrank(worldDeployer);
    CityCounter.setCounter(4);
    KingElection.set(1, candidateId, block.timestamp + 10_000, candidateIds, votesReceived);
    CityVault.setAmount(cityId, 1, 1000);
    CityVault.setAmount(cityId, 2, 1000);
    CityVault.setAmount(cityId, 3, 1000);
    uint256[] memory resourceIds = new uint256[](3);
    resourceIds[0] = 1;
    resourceIds[1] = 2;
    resourceIds[2] = 3;
    uint32[] memory amounts = new uint32[](3);
    amounts[0] = 100;
    amounts[1] = 200;
    amounts[2] = 10;
    CResourceRequire.set(1, resourceIds, amounts);
    CResourceRequire.set(2, resourceIds, amounts);
    CResourceRequire.set(3, resourceIds, amounts);
    vm.stopPrank();

    uint32[] memory withdrawAmounts = new uint32[](3);
    withdrawAmounts[0] = 300;
    withdrawAmounts[1] = 600;
    withdrawAmounts[2] = 33;

    // test withdraw resource from city vault
    // revert - not the keeper
    vm.expectRevert();
    vm.startPrank(voter);
    world.app__withdrawItemFromCity(voterId, cityId, resourceIds, withdrawAmounts);
    vm.stopPrank();

    vm.startPrank(candidate);
    world.app__setRole(candidateId, voterId, RoleType.None);
    vm.stopPrank();

    RoleType voterRole = CharRole.getRoleType(voterId);
    assertEq(uint8(voterRole), uint8(RoleType.None));

    CharCurrentStatsData memory prevVoterCurrentStats = CharCurrentStats.get(voterId);
    vm.startPrank(candidate);
    world.app__setRole(candidateId, voterId, RoleType.VaultKeeper);
    vm.stopPrank();

    // achievement give each attribute 1 point
    assertEq(CharCurrentStats.getAtk(voterId), prevVoterCurrentStats.atk + 1);
    assertEq(CharRoleCounter.getCount(1, RoleType.VaultKeeper), 1);
    assertEq(uint8(CharRole.getRoleType(voterId)), uint8(RoleType.VaultKeeper));

    // withdraw resource
    vm.startPrank(voter);
    world.app__withdrawItemFromCity(voterId, cityId, resourceIds, withdrawAmounts);
    vm.stopPrank();
    CVaultHistoryData memory history = CVaultHistory.get(cityId, 1);
    assertEq(history.itemId, 1);
    assertEq(history.amount, 300);
    assertFalse(history.isContributed);
    history = CVaultHistory.get(cityId, 3);
    assertEq(history.itemId, 3);
    assertEq(history.amount, 33);
    assertFalse(history.isContributed);
    assertEq(CharOtherItem.getAmount(voterId, 1), 300);
    assertEq(CharOtherItem.getAmount(voterId, 3), 33);
    assertEq(CityVault.getAmount(cityId, 1), 700);

    // test set new city
    vm.expectRevert(); // the coordinates must belong to the kingdom
    vm.startPrank(candidate);
    world.app__setNewCity(candidateId, newCityX, newCityY - 1, "New City");
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    TileInfo3.setKingdomId(newCityX, newCityY, 1);
    TileInfo3.setKingdomId(newCityX, newCityY + 1, 1);
    RestrictLocation.set(newCityX, newCityY - 1, true);
    vm.stopPrank();

    vm.expectRevert(); // the coordinates must be valid
    vm.startPrank(candidate);
    world.app__setNewCity(candidateId, newCityX, newCityY - 1, "New City");
    vm.stopPrank();

    vm.startPrank(candidate);
    world.app__setNewCity(candidateId, newCityX, newCityY, "New City");
    vm.stopPrank();
    assertEq(CityCounter.getCounter(), 5);
    uint256 newCityId = 5;
    CityData memory city = City.get(newCityId);
    assertEq(city.x, newCityX);
    assertEq(city.y, newCityY);
    assertEq(city.level, 0);

    console2.log("place new city but revert because this place already had a city");
    vm.expectRevert();
    vm.startPrank(candidate);
    world.app__setNewCity(candidateId, newCityX, newCityY, "New City");
    vm.stopPrank();

    console2.log("test healing");
    vm.startPrank(worldDeployer);
    CharStats.setHp(voterId, 500);
    CharCurrentStats.setHp(voterId, 500 - 102);
    CharFund.setGold(voterId, 200);
    vm.stopPrank();
    vm.expectRevert(); // city level too low
    vm.startPrank(voter);
    world.app__cityHealing(voterId, cityId, 200);
    vm.stopPrank();

    console2.log("test upgrade city");
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(candidateId, newCityX, newCityY);
    CharacterPositionUtils.moveToLocation(voterId, newCityX, newCityY);
    City.setLevel(cityId, 3);
    vm.stopPrank();
    vm.startPrank(voter);
    world.app__contributeItemToCity(voterId, newCityId, resourceIds, withdrawAmounts);
    vm.stopPrank();
    history = CVaultHistory.get(newCityId, 1);
    assertTrue(history.isContributed);
    assertEq(history.itemId, 1);
    assertEq(history.amount, 300);

    console2.log("upgrade city to level 1");
    vm.startPrank(candidate);
    world.app__upgradeCity(candidateId, newCityId);
    vm.stopPrank();
    city = City.get(newCityId);
    assertEq(city.level, 1);
    assertEq(CityVault.getAmount(newCityId, 1), 200);
    assertEq(CityVault.getAmount(newCityId, 2), 400);
    assertEq(CityVault.getAmount(newCityId, 3), 23);

    console2.log("re-test healing");
    vm.startPrank(voter);
    world.app__cityHealing(voterId, newCityId, 200);
    vm.stopPrank();

    assertEq(CharCurrentStats.getHp(voterId), 500);
    assertEq(CharFund.getGold(voterId), 198);

    vm.startPrank(candidate);
    world.app__upgradeCity(candidateId, newCityId);
    world.app__upgradeCity(candidateId, newCityId);
    vm.stopPrank();
    city = City.get(newCityId);
    assertEq(city.level, 3);
    assertEq(CityVault.getAmount(newCityId, 3), 3);

    console2.log("test teleport");
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToCapital(voterId);
    vm.stopPrank();
    vm.startPrank(voter);
    world.app__cityTeleport(voterId, cityId, newCityId); // only can teleport from capital to new city
    vm.stopPrank();
    assertEq(CharFund.getGold(voterId), 98);
    CharPositionData memory position = CharacterPositionUtils.currentPosition(voterId);
    assertEq(position.x, newCityX);
    assertEq(position.y, newCityY);

    console2.log("test save point");
    vm.startPrank(voter);
    world.app__citySavePoint(voterId, newCityId, false);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(candidateId, newCityX, newCityY + 1);
    CharacterPositionUtils.moveToLocation(voterId, newCityX, newCityY + 1);
    CharCurrentStats.setAgi(candidateId, 10_000);
    CharCurrentStats.setAtk(candidateId, 10_000);
    vm.stopPrank();
    vm.warp(block.timestamp + 100);
    vm.startPrank(candidate);
    world.app__battlePvP(candidateId, voterId);
    vm.stopPrank();
      
    position = CharacterPositionUtils.currentPosition(voterId);
    assertEq(position.x, newCityX);
    assertEq(position.y, newCityY);

    vm.startPrank(voter);
    world.app__citySavePoint(voterId, newCityId, true);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(candidateId, newCityX, newCityY + 1);
    CharacterPositionUtils.moveToLocation(voterId, newCityX, newCityY + 1);
    vm.stopPrank();
    vm.warp(block.timestamp + 100);
    vm.startPrank(candidate);
    world.app__battlePvP(candidateId, voterId);
    vm.stopPrank();
    city = City.get(cityId);
    position = CharacterPositionUtils.currentPosition(voterId);
    assertEq(position.x, city.x);
    assertEq(position.y, city.y);
  }
}
