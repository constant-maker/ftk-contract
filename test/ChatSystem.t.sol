pragma solidity >=0.8.24;

import { CharOtherItem, CharCurrentStats, CharStats } from "@codegen/index.sol";
import { WorldFixture, SpawnSystemFixture } from "@fixtures/index.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { ChatCounter } from "@codegen/tables/ChatCounter.sol";
import { GlobalChatV2 } from "@codegen/tables/GlobalChatV2.sol";

contract ChatSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  address player2 = makeAddr("player2");
  uint256 characterId;
  uint256 characterId2;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    characterId2 = _createCharacterWithName(player2, "123");
  }

  function test_Chat() external {
    string memory content = "hello world!";
    for (uint256 i = 1; i <= 51; i++) {
      if (i == 51) {
        content = "hi pro";
      }
      vm.startPrank(player);
      world.app__chat(characterId, content);
      vm.stopPrank();
      vm.startPrank(player2);
      world.app__chat(characterId2, content);
      vm.stopPrank();
    }

    assertEq(ChatCounter.get(), 102);
    assertEq(GlobalChatV2.getRawId(101), 0); // max id is 100
    assertEq(GlobalChatV2.getRawId(2), 102);
    assertEq(GlobalChatV2.getContent(2), "hi pro");
    assertEq(GlobalChatV2.getCharId(2), 2);
    assertEq(GlobalChatV2.getName(2), "123");
    assertEq(GlobalChatV2.getKingdomId(2), 1);
  }

  function test_ChatRevert() external {
    string memory content = "";

    vm.expectRevert();
    vm.startPrank(player);
    world.app__chat(characterId, content);
    vm.stopPrank();

    content =
      "100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    vm.expectRevert();
    vm.startPrank(player);
    world.app__chat(characterId, content);
    vm.stopPrank();
  }
}
