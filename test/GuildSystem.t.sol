pragma solidity >=0.8.24;

import { Vm } from "forge-std/Vm.sol";
import {
  CharFund,
  Guild,
  GuildNameMapping,
  GuildOwnerMapping,
  GuildMemberMapping,
  GuildCounter,
  GuildMemberIndex
} from "@codegen/index.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { CharacterFundUtils, CharacterItemUtils } from "@utils/index.sol";
import { console2 } from "forge-std/console2.sol";
import { LibString } from "@solady/utils/LibString.sol";

contract GuildSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player1 = makeAddr("player1");
  uint256 characterId1;

  address player2 = makeAddr("player2");
  uint256 characterId2;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();
    characterId1 = _createDefaultCharacter(player1);
    _claimWelcomePackages(player1, characterId1);

    characterId2 = _createCharacterWithNameAndKingdomId(player2, "player2", 2);
    _claimWelcomePackages(player2, characterId2);
  }

  function test_GuildSystem() external {
    // create guild
    // vm.expectRevert(); // invalid name
    // vm.startPrank(player1);
    // world.app__createGuild(characterId1, "Guild 1");
    // vm.stopPrank();

    vm.expectRevert(); // not enough gold
    vm.startPrank(player1);
    world.app__createGuild(characterId1, "Guild 1");
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharFund.setGold(characterId1, 20_000);
    CharFund.setGold(characterId2, 20_000);
    vm.stopPrank();

    vm.startPrank(player1);
    world.app__createGuild(characterId1, "Guild 1");
    vm.stopPrank();

    assertEq(CharFund.getGold(characterId1), 10_000);

    vm.expectRevert(); // name existed
    vm.startPrank(player2);
    world.app__createGuild(characterId2, "Guild 1");
    vm.stopPrank();

    vm.startPrank(player2);
    world.app__createGuild(characterId2, "Guild2");
    vm.stopPrank();

    assertEq(CharFund.getGold(characterId2), 10_000);

    uint256 currentCounter = GuildCounter.get();
    assertEq(currentCounter, 2);
    assertEq(GuildMemberMapping.getGuildId(characterId1), 1);
    assertEq(GuildMemberMapping.getGuildId(characterId2), 2);
    assertEq(GuildOwnerMapping.getOwnerId(1), characterId1);
    assertEq(GuildOwnerMapping.getOwnerId(2), characterId2);
    assertEq(GuildMemberIndex.get(1, characterId1), 1); // based index + 1
    assertEq(GuildMemberIndex.get(2, characterId2), 1); // based index + 1

    // request to join guild but revert because already in guild
    vm.expectRevert();
    vm.startPrank(player2);
    world.app__requestToJoinGuild(characterId2, 1);
    vm.stopPrank();

    // leave guild
    vm.startPrank(player2);
    world.app__leaveGuild(characterId2);
    vm.stopPrank();

    console2.log("check member mapping");
    assertEq(GuildMemberMapping.getGuildId(characterId2), 0);
    console2.log("check owner mapping");
    assertEq(GuildOwnerMapping.getOwnerId(2), 0);
    console2.log("check member index");
    assertEq(GuildMemberIndex.get(2, characterId2), 0);
    console2.log("guild name", Guild.getName(2));
    bytes32 nameHash = LibString.packOne(LibString.lower("Guild2"));
    console2.log("check name mapping");
    assertEq(GuildNameMapping.getGuildId(nameHash), 0);
    assertEq(Guild.lengthMemberIds(2), 0);

    // request to join guild
    vm.startPrank(player2);
    world.app__requestToJoinGuild(characterId2, 1);
    vm.stopPrank();

    // cancel request to join guild
    vm.startPrank(player2);
    world.app__cancelJoinGuildRequest(characterId2);
    vm.stopPrank();

    vm.expectRevert(); // no existing request
    vm.startPrank(player2);
    world.app__cancelJoinGuildRequest(characterId2);
    vm.stopPrank();

    // request to join guild
    vm.startPrank(player2);
    world.app__requestToJoinGuild(characterId2, 1);
    vm.stopPrank();

    uint256[] memory characterIds = new uint256[](1);
    characterIds[0] = characterId2;

    // owner approve join request
    vm.startPrank(player1);
    world.app__approveJoinGuildRequest(characterId1, characterIds);
    vm.stopPrank();

    assertEq(GuildMemberMapping.getGuildId(characterId2), 1);
    assertEq(GuildMemberIndex.get(1, characterId2), 2); // based index + 1
    assertEq(Guild.lengthMemberIds(1), 2);

    // transfer ownership
    vm.expectRevert(); // not owner
    vm.startPrank(player2);
    world.app__transferGuildOwnership(characterId2, characterId1);
    vm.stopPrank();

    vm.startPrank(player1);
    world.app__transferGuildOwnership(characterId1, characterId2);
    vm.stopPrank();

    // kick member
    characterIds[0] = characterId2;
    vm.expectRevert(); // not owner
    vm.startPrank(player1);
    world.app__kickMember(characterId1, characterIds);
    vm.stopPrank();

    characterIds[0] = characterId1;
    vm.startPrank(player2);
    world.app__kickMember(characterId2, characterIds);
    vm.stopPrank();

    assertEq(GuildMemberMapping.getGuildId(characterId1), 0);
    assertEq(GuildMemberIndex.get(1, characterId1), 0);
    assertEq(Guild.lengthMemberIds(1), 1);
  }
}
