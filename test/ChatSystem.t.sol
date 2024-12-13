pragma solidity >=0.8.24;

import { CharOtherItem, CharCurrentStats, CharStats } from "@codegen/index.sol";
import { WorldFixture, SpawnSystemFixture } from "@fixtures/index.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { ChatCounter } from "@codegen/tables/ChatCounter.sol";
import { GlobalChat } from "@codegen/tables/GlobalChat.sol";

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
    assertEq(GlobalChat.getRawId(101), 0); // max id is 100
    assertEq(GlobalChat.getRawId(2), 102);
    assertEq(GlobalChat.getContent(2), "hi pro");
    assertEq(GlobalChat.getCharId(2), 2);
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
