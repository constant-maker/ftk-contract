pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { Guild, GuildData, GuildCounter, GuildNameMapping, GuildMemberMapping, GuildOwnerMapping } from "@codegen/index.sol";
import { CharacterFundUtils } from "@utils/index.sol";
import { Errors, Config } from "@common/index.sol";

contract GuildSystem is CharacterAccessControl, System {
  uint32 constant GUILD_CREATION_COST = 10_000;
  uint16 constant MAX_GUILD_MEMBERS = 50;

  /// @dev Create a guild
  function createGuild(uint256 characterId, string memory name) public onlyAuthorizedWallet(characterId) {
    if (GuildMemberMapping.getGuildId(characterId) != 0) {
      revert Errors.GuildSystem_CharacterAlreadyInGuild(characterId);
    }
    uint256 guildId = GuildCounter.getCount() + 1;
    bytes32 nameHash = LibString.packOne(LibString.lower(name));
    if (GuildNameMapping.getGuildId(nameHash) != 0) {
      revert Errors.GuildSystem_GuildNameExisted(name);
    }
    GuildCounter.setCount(guildId);
    GuildNameMapping.setGuildId(nameHash, guildId);
    GuildMemberMapping.setGuildId(characterId, guildId);
    CharacterFundUtils.decreaseGold(characterId, GUILD_CREATION_COST);
    uint256[] memory members = new uint256[](1);
    members[0] = characterId;
    Guild.set(guildId, characterId, 1, block.timestamp, 0, name, members);
    GuildOwnerMapping.setOwnerId(guildId, characterId);
  }

  /// @dev Transfer guild ownership to another member
  function transferGuildOwnership(uint256 characterId, uint256 newOwnerId) public onlyAuthorizedWallet(characterId) {
    uint256 guildId = GuildMemberMapping.getGuildId(characterId);
    if (guildId == 0) {
      revert Errors.GuildSystem_CharacterNotInGuild(characterId, guildId);
    }
    if (GuildOwnerMapping.getOwnerId(guildId) != characterId) {
      revert Errors.GuildSystem_NotGuildOwner(characterId, guildId);
    }
    if (GuildMemberMapping.getGuildId(newOwnerId) != guildId) {
      revert Errors.GuildSystem_CharacterNotInGuild(newOwnerId, guildId);
    }
    GuildOwnerMapping.setOwnerId(guildId, newOwnerId);
  }

  /// @dev Leave guild
  function leaveGuild(uint256 characterId) public onlyAuthorizedWallet(characterId) {
    uint256 guildId = GuildMemberMapping.getGuildId(characterId);
    if (guildId == 0) {
      revert Errors.GuildSystem_CharacterNotInGuild(characterId, guildId);
    }
    if (GuildOwnerMapping.getOwnerId(guildId) == characterId) {
      revert Errors.GuildSystem_OwnerCannotLeaveGuild(characterId, guildId);
    }
    
    GuildMemberMapping.setGuildId(characterId, 0);
    Guild.remove(guildId, characterId);
  }

}
