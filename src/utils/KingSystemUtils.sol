pragma solidity >=0.8.24;

import {
  CharStats,
  CharStats2,
  City,
  CityData,
  KingElection,
  Kingdom,
  CharRoleCounter,
  AllianceV2,
  AllianceV2Data,
  CityMoveHistory,
  RestrictLocV2,
  CityVault2,
  TileInfo3,
  CharInfo
} from "@codegen/index.sol";
import { RoleType } from "@codegen/common.sol";
import { CharAchievementUtils } from "./CharAchievementUtils.sol";
import { MapUtils } from "./MapUtils.sol";
import { CharacterRoleUtils } from "./CharacterRoleUtils.sol";
import { CharacterPositionUtils } from "./CharacterPositionUtils.sol";
import { Errors } from "@common/index.sol";

library KingSystemUtils {
  uint32 constant TERM_DURATION = 1_209_600; // 14 days in seconds
  uint256 constant KING_ACHIEVEMENT_ID = 10;
  uint32 constant OFFSET_DURATION = 172_800; // 2 days in seconds
  uint256 constant VAULT_KEEPER_MIN_LEVEL_REQUIRED = 80;
  uint256 constant CITY_MOVE_COOLDOWN = 1_209_600;

  function findTopCandidate(uint256[] memory candidateIds, uint32[] memory voteReceived) public view returns (uint256) {
    uint32 maxVote;
    uint32 count;

    for (uint256 i = 0; i < voteReceived.length; i++) {
      if (voteReceived[i] > maxVote) {
        maxVote = voteReceived[i];
        count = 1;
      } else if (voteReceived[i] == maxVote) {
        count++;
      }
    }

    uint256[] memory topCandidates = new uint256[](count);
    uint256 idx;

    for (uint256 i = 0; i < voteReceived.length; i++) {
      if (voteReceived[i] == maxVote) {
        topCandidates[idx++] = candidateIds[i];
      }
    }

    if (count == 1) {
      return topCandidates[0];
    }

    uint32 maxFame;
    uint256 maxFameIndex;
    for (uint256 i = 0; i < count; i++) {
      uint32 fame = CharStats2.getFame(topCandidates[i]);
      if (fame > maxFame) {
        maxFame = fame;
        maxFameIndex = i;
      }
    }

    return topCandidates[maxFameIndex];
  }

  /// @dev Check if the user is eligible for the role in the kingdom
  function checkUserEligible(uint256 citizenId, RoleType roleType) public view {
    if (roleType == RoleType.VaultKeeper) {
      uint16 level = CharStats.getLevel(citizenId);
      if (level < VAULT_KEEPER_MIN_LEVEL_REQUIRED) {
        revert Errors.KingSystem_InsufficientLevelForRole(citizenId, level, roleType);
      }
    } else if (roleType == RoleType.KingGuard) {
      // No specific requirement for KingGuard as of now
    }
  }

  /// @dev Check and update the role limit for a specific role in a kingdom
  function checkAndUpdateRoleLimit(uint8 kingdomId, RoleType roleType) public {
    uint32 currentCount = CharRoleCounter.getCount(kingdomId, roleType);
    uint32 maxLimit = City.getLevel(Kingdom.getCapitalId(kingdomId)) * 5;
    if (currentCount >= maxLimit) {
      revert Errors.KingSystem_RoleLimitReached(roleType, maxLimit);
    }
    CharRoleCounter.setCount(kingdomId, roleType, currentCount + 1);
  }

  function validateKingdomId(uint8 kingdomId) public pure {
    if (kingdomId < 1 || kingdomId > 4) {
      revert Errors.KingSystem_InvalidKingdomId(kingdomId);
    }
  }

  function checkElectionTime(uint8 kingdomId) public view {
    if (!isInElectionTime(kingdomId, block.timestamp)) {
      revert Errors.KingSystem_NotInElectionTime();
    }
  }

  function isInElectionTime(uint8 kingdomId, uint256 timeCheck) public view returns (bool) {
    uint256 electionTimestamp = KingElection.getTimestamp(kingdomId);
    return (timeCheck + OFFSET_DURATION) >= electionTimestamp && timeCheck <= electionTimestamp;
  }

  function assignKing(uint8 kingdomId, uint256 oldKingId, uint256 candidateId) public {
    // transfer the king's achievement from the old king to the new king
    if (oldKingId != 0) {
      CharAchievementUtils.removeAchievement(oldKingId, KING_ACHIEVEMENT_ID);
    }
    CharAchievementUtils.addAchievement(candidateId, KING_ACHIEVEMENT_ID);
    // set the new king, reset the election data
    uint256[] memory emptyCandidateIds;
    uint32[] memory emptyVotes;
    uint256 nextElectionTimestamp = KingElection.getTimestamp(kingdomId) + TERM_DURATION;
    KingElection.setCandidateIds(kingdomId, emptyCandidateIds);
    KingElection.set(kingdomId, candidateId, nextElectionTimestamp, emptyCandidateIds, emptyVotes);
  }

  function setAlliance(uint8 charKingdomId, uint8 otherKingdomId, bool value) public {
    if (!value) {
      AllianceV2.deleteRecord(charKingdomId, otherKingdomId);
      AllianceV2.deleteRecord(otherKingdomId, charKingdomId);
      return;
    }
    AllianceV2Data memory allianceData = AllianceV2.get(charKingdomId, otherKingdomId);
    if (allianceData.isAlliance) {
      // Already in alliance or already proposed
      return;
    }

    // Check if the other kingdom has proposed an alliance
    allianceData = AllianceV2.get(otherKingdomId, charKingdomId);
    if (allianceData.isAlliance) {
      if (allianceData.isApproved) {
        // The other kingdom has already approved the alliance
        return;
      }
      // The other kingdom has proposed but not approved yet, so approve it.
      AllianceV2.set(otherKingdomId, charKingdomId, true, true);
      return;
    }

    // Initiate alliance request from this kingdom
    AllianceV2.set(charKingdomId, otherKingdomId, true, false);
  }

  function moveCity(uint256 characterId, int32 x, int32 y, uint256 cityId) public {
    // CharacterPositionUtils.mustInCity(characterId, cityId);
    MapUtils.mustBeActiveCity(cityId);
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);
    if (City.getKingdomId(cityId) != charKingdomId) {
      revert Errors.KingSystem_CityNotInYourKingdom(cityId, charKingdomId);
    }
    if (Kingdom.getCapitalId(charKingdomId) == cityId) {
      revert Errors.KingSystem_CannotMoveCapitalCity();
    }
    if (!MapUtils.isValidCityLocation(x, y)) {
      revert Errors.KingSystem_InvalidCityLocation(x, y);
    }
    if (CityMoveHistory.getMoveTimestamp(cityId) + CITY_MOVE_COOLDOWN > block.timestamp) {
      revert Errors.KingSystem_CityMoveOnCooldown(cityId);
    }
    CityData memory city = City.get(cityId);
    if (city.x == x && city.y == y) {
      return; // No change in position
    }
    uint32 goldCost = (city.level + 1) * 2000;
    uint32 cityGold = CityVault2.getGold(cityId);
    if (cityGold < goldCost) {
      revert Errors.KingSystem_InsufficientCityGold(cityId, goldCost);
    }
    CityMoveHistory.set(cityId, city.x, city.y, block.timestamp);
    RestrictLocV2.deleteRecord(city.x, city.y); // Unmark the old location
    CityVault2.setGold(cityId, cityGold - goldCost);
    // Set new city position
    city.x = x;
    city.y = y;
    City.set(cityId, city);
    RestrictLocV2.set(x, y, cityId, true); // Mark the new location as restricted for cities
  }
}
