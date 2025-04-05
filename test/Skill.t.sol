pragma solidity >=0.8.24;

import { Skill, SkillData } from "@codegen/index.sol";
import { ItemType } from "@codegen/common.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";

contract SkillTest is WorldFixture, SpawnSystemFixture {
  function setUp() public virtual override(WorldFixture, SpawnSystemFixture) {
    WorldFixture.setUp();
  }

  function testFuzz_UserShouldNotAbleToSetSkill(address user) external {
    vm.assume(user != worldDeployer);
    vm.assume(user != creator);
    vm.assume(user != address(0));
    uint256 characterId = _createDefaultCharacter(user);
    vm.startPrank(user);
    bytes memory accessDeniedError = TestHelper.getAccessDeniedError(user, Skill._tableId);
    vm.expectRevert(accessDeniedError);
    Skill.set(1, 2, 3, 4, ItemType.Axe, 1, false, "123");
    vm.stopPrank();
  }

  function test_HaveData() external {
    SkillData memory skillData = Skill.get(0);
    assertEq(skillData.damage, 100);
    assertEq(skillData.sp, 0);
  }
}
