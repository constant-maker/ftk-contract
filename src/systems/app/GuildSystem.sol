pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { LibString } from "@solady/utils/LibString.sol";
import {
  Guild,
  GuildData,
  GuildCounter,
  GuildNameMapping,
  GuildMemberMapping,
  GuildOwnerMapping,
  GuildRequest,
  GuildRequestData
} from "@codegen/index.sol";
import { CharacterFundUtils, GuildUtils } from "@utils/index.sol";
import { Errors, Config } from "@common/index.sol";

contract GuildSystem is CharacterAccessControl, System {
  uint32 constant GUILD_CREATION_COST = 10_000;
  uint16 constant MAX_GUILD_MEMBERS = 50;

  /// @dev Create a guild
  function createGuild(uint256 characterId, string memory name) public onlyAuthorizedWallet(characterId) {
    if (!_isValidName(name)) {
      revert Errors.GuildSystem_InvalidGuildName(name);
    }
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
    CharacterFundUtils.decreaseGold(characterId, GUILD_CREATION_COST);
    uint256[] memory members;
    Guild.set(guildId, characterId, 1, block.timestamp, 0, name, members);
    GuildUtils.addMember(guildId, characterId);
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
      if (Guild.lengthMemberIds(guildId) > 1) {
        revert Errors.GuildSystem_OwnerCannotLeaveGuild(characterId, guildId);
      } else {
        // If owner is the last member, disband the guild
        _removeMember(guildId, characterId);
        GuildNameMapping.deleteRecord(LibString.packOne(LibString.lower(Guild.getName(guildId))));
        GuildOwnerMapping.deleteRecord(guildId);
        Guild.deleteRecord(guildId);
        return;
      }
    }
    _removeMember(guildId, characterId);
  }

  /// @dev Kick member from guild
  function kickMember(uint256 characterId, uint256 memberId) public onlyAuthorizedWallet(characterId) {
    uint256 guildId = GuildMemberMapping.getGuildId(characterId);
    if (guildId == 0) {
      revert Errors.GuildSystem_CharacterNotInGuild(characterId, guildId);
    }
    if (GuildOwnerMapping.getOwnerId(guildId) != characterId) {
      revert Errors.GuildSystem_NotGuildOwner(characterId, guildId);
    }

    if (characterId == memberId) {
      revert Errors.GuildSystem_OwnerCannotKickSelf(characterId, guildId);
    }

    _removeMember(guildId, memberId);
  }

  /// @dev Request to join guild
  function requestToJoinGuild(uint256 characterId, uint256 guildId) public onlyAuthorizedWallet(characterId) {
    if (GuildMemberMapping.getGuildId(characterId) != 0) {
      revert Errors.GuildSystem_CharacterAlreadyInGuild(characterId);
    }
    if (GuildRequest.getRequestedAt(characterId) != 0) {
      revert Errors.GuildSystem_JoinRequestAlreadyExists(characterId);
    }
    if (Guild.lengthMemberIds(guildId) >= MAX_GUILD_MEMBERS) {
      revert Errors.GuildSystem_GuildMemberLimitReached(guildId);
    }
    GuildRequest.set(characterId, guildId, block.timestamp);
  }

  /// @dev Cancel join guild request
  function cancelJoinGuildRequest(uint256 characterId) public onlyAuthorizedWallet(characterId) {
    if (GuildRequest.getRequestedAt(characterId) == 0) {
      revert Errors.GuildSystem_JoinRequestDoesNotExist(characterId);
    }
    GuildRequest.deleteRecord(characterId);
  }

  /// @dev Approve join guild request
  function approveJoinGuildRequest(uint256 characterId, uint256 memberId) public onlyAuthorizedWallet(characterId) {
    uint256 guildId = GuildMemberMapping.getGuildId(characterId);
    if (guildId == 0) {
      revert Errors.GuildSystem_CharacterNotInGuild(characterId, guildId);
    }
    if (GuildOwnerMapping.getOwnerId(guildId) != characterId) {
      revert Errors.GuildSystem_NotGuildOwner(characterId, guildId);
    }
    GuildRequestData memory request = GuildRequest.get(memberId);
    if (request.requestedAt == 0 || request.guildId != guildId) {
      revert Errors.GuildSystem_JoinRequestDoesNotExist(memberId);
    }
    if (Guild.lengthMemberIds(guildId) >= MAX_GUILD_MEMBERS) {
      revert Errors.GuildSystem_GuildMemberLimitReached(guildId);
    }
    GuildRequest.deleteRecord(memberId);
    GuildUtils.addMember(guildId, memberId);
  }

  function _removeMember(uint256 guildId, uint256 memberId) private {
    GuildUtils.removeMember(guildId, memberId);
  }

  function _isValidName(string memory name) private pure returns (bool) {
    bytes memory b = bytes(name);

    // Length check
    if (b.length < 3 || b.length > 25) {
      return false;
    }

    for (uint256 i = 0; i < b.length; i++) {
      bytes1 char = b[i];

      // Allowed: 0-9, A-Z, a-z only
      if (
        !(char >= 0x30 && char <= 0x39) // digits
          && !(char >= 0x41 && char <= 0x5A) // A-Z
          && !(char >= 0x61 && char <= 0x7A) // a-z
          && !(char == 0x20) // space
      ) {
        return false;
      }
    }

    return true;
  }
}
