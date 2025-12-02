pragma solidity >=0.8.24;

import { GuildMemberIndex, Guild, GuildData, GuildMemberMapping } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";
import { CharAchievementUtils } from "./CharAchievementUtils.sol";

library GuildUtils {
  uint256 constant GUILD_ACHIEVEMENT_ID = 21;

  /// @dev Add members to guild
  function addMembers(uint256 guildId, uint256[] memory memberIds) public {
    for (uint256 i = 0; i < memberIds.length; i++) {
      addMember(guildId, memberIds[i]);
    }
  }

  function addMember(uint256 guildId, uint256 memberId) public {
    if (hasMember(guildId, memberId)) {
      revert Errors.GuildSystem_CharacterAlreadyInGuild(memberId);
    }
    Guild.pushMemberIds(guildId, memberId);
    GuildMemberMapping.set(memberId, guildId);
    // The value is stored at length-1, but we add 1 to all indexes
    // and use 0 as a sentinel value
    uint256 index = Guild.lengthMemberIds(guildId);
    GuildMemberIndex.set(guildId, memberId, index);
    CharAchievementUtils.addAchievement(memberId, GUILD_ACHIEVEMENT_ID);
  }

  /// @dev Remove members from guild
  function removeMembers(uint256 guildId, uint256[] memory memberIds) public {
    for (uint256 i = 0; i < memberIds.length; i++) {
      removeMember(guildId, memberIds[i]);
    }
  }

  /// @dev Remove member from guild
  function removeMember(uint256 guildId, uint256 memberId) public {
    uint256 index = GuildMemberIndex.get(guildId, memberId);
    if (index == 0) revert Errors.GuildSystem_CharacterNotInGuild(guildId, memberId);
    // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
    // the array, and then remove the last element (sometimes called as 'swap and pop').
    // This modifies the order of the array, as noted in {at}.
    uint256 valueIndex = index - 1;
    uint256 lastIndex = Guild.lengthMemberIds(guildId) - 1;
    if (valueIndex != lastIndex) {
      uint256 lastValue = Guild.getItemMemberIds(guildId, lastIndex);
      Guild.updateMemberIds(guildId, valueIndex, lastValue);
      GuildMemberIndex.set(guildId, lastValue, index);
    }
    Guild.popMemberIds(guildId);
    GuildMemberIndex.deleteRecord(guildId, memberId);
    GuildMemberMapping.deleteRecord(memberId);
    CharAchievementUtils.removeAchievement(memberId, GUILD_ACHIEVEMENT_ID);
  }

  /// @dev Return whether the character has the equipment in inventory
  function hasMember(uint256 guildId, uint256 memberId) public view returns (bool) {
    uint256 index = GuildMemberIndex.get(guildId, memberId);
    return index != 0;
  }
}
