pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharStats2,
  KingElection,
  KingElectionData,
  CandidatePromise,
  CharVote,
  CharInfo,
  MarketFee,
  AllianceV2,
  AllianceV2Data,
  KingSetting,
  TileInfo3,
  City,
  RestrictLocation,
  CityCounter,
  KingdomV2,
  CharRole
} from "@codegen/index.sol";
import { CharAchievementUtils, MapUtils, CharacterRoleUtils } from "@utils/index.sol";
import { Errors } from "@common/index.sol";
import { ZoneType, RoleType } from "@codegen/common.sol";

contract KingSystem is CharacterAccessControl, System {
  uint32 constant KING_MIN_FAME_REQUIRE = 2000;
  uint32 constant VOTER_MIN_FAME_REQUIRE = 1020;
  uint32 constant TERM_DURATION = 1_209_600; // 14 days in seconds
  uint32 constant OFFSET_DURATION = 172_800; // 2 days in seconds
  uint256 constant KING_ACHIEVEMENT_ID = 10;

  function registerKing(uint256 characterId, string memory promiseSummary) public onlyAuthorizedWallet(characterId) {
    uint8 kingdomId = CharInfo.getKingdomId(characterId);
    KingElectionData memory kingElection = KingElection.get(kingdomId);
    if (kingElection.timestamp == 0) {
      kingElection.timestamp = block.timestamp + OFFSET_DURATION;
      KingElection.setTimestamp(kingdomId, kingElection.timestamp);
    }
    uint32 fame = CharStats2.getFame(characterId);
    if (fame < KING_MIN_FAME_REQUIRE) {
      revert Errors.KingSystem_InsufficientFameForKingElection(characterId, fame);
    }
    _checkElectionTime(kingdomId);
    for (uint256 i = 0; i < kingElection.candidateIds.length; i++) {
      if (kingElection.candidateIds[i] == characterId) {
        revert Errors.KingSystem_AlreadyRegistered(characterId);
      }
    }
    KingElection.pushCandidateIds(kingdomId, characterId);
    KingElection.pushVotesReceived(kingdomId, 0);
    CandidatePromise.set(characterId, block.timestamp, promiseSummary);
  }

  function assignKing(uint8 kingdomId) public {
    KingElectionData memory kingElection = KingElection.get(kingdomId);
    if (kingElection.timestamp > block.timestamp) {
      revert Errors.KingSystem_ElectionPeriodNotOverYet();
    }
    if (kingElection.candidateIds.length == 0) {
      uint256 nextElectionTimestamp = KingElection.getTimestamp(kingdomId) + TERM_DURATION;
      KingElection.setTimestamp(kingdomId, nextElectionTimestamp);
    }

    uint256 topCandidateId = _findTopCandidate(kingElection.candidateIds, kingElection.votesReceived);
    _assignKing(kingdomId, kingElection.kingId, topCandidateId);
  }

  function voteKing(uint256 characterId, uint256 candidateId) public onlyAuthorizedWallet(characterId) {
    uint8 kingdomId = CharInfo.getKingdomId(characterId);
    _checkElectionTime(kingdomId);

    if (characterId == candidateId) {
      revert Errors.KingSystem_CannotVoteForSelf(characterId);
    }

    uint32 fame = CharStats2.getFame(characterId);
    if (fame < VOTER_MIN_FAME_REQUIRE) {
      revert Errors.KingSystem_InsufficientFameForVoting(characterId, fame);
    }

    if (_isInElectionTime(kingdomId, CharVote.getTimestamp(characterId)) && CharVote.getCandidateId(characterId) != 0) {
      revert Errors.KingSystem_AlreadyVoted(characterId);
    }

    KingElectionData memory kingElection = KingElection.get(kingdomId);

    uint256 candidateIndex = type(uint256).max;
    for (uint256 i = 0; i < kingElection.candidateIds.length; i++) {
      if (kingElection.candidateIds[i] == candidateId) {
        candidateIndex = i;
        break;
      }
    }

    if (candidateIndex == type(uint256).max) {
      revert Errors.KingSystem_InvalidCandidate(candidateId);
    }
    uint32 votePower = fame - 1000; // 1000 fame is the base vote power
    KingElection.updateVotesReceived(kingdomId, candidateIndex, kingElection.votesReceived[candidateIndex] + votePower);
    CharVote.set(characterId, candidateId, votePower, block.timestamp);
  }

  function setAlliance(uint256 characterId, uint8 otherKingdomId, bool value) public onlyAuthorizedWallet(characterId) {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);
    _validateKingdomId(otherKingdomId);
    if (charKingdomId == otherKingdomId) {
      return;
    }
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

  function setMarketFee(
    uint256 characterId,
    uint8[] calldata kingdomIds,
    uint8[] calldata fee
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);
    for (uint256 i = 0; i < kingdomIds.length; i++) {
      uint8 kingdomId = kingdomIds[i];
      uint8 fee = fee[i];
      _validateKingdomId(kingdomId);
      if (fee > 100) {
        revert Errors.KingSystem_InvalidMarketFee(fee);
      }
      MarketFee.set(charKingdomId, kingdomId, fee);
    }
  }

  function setPvPFamePenalty(uint256 characterId, uint8 penalty) public onlyAuthorizedWallet(characterId) {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);
    if (penalty > 100) {
      revert Errors.KingSystem_InvalidFamePenalty(penalty);
    }
    KingSetting.setPvpFamePenalty(charKingdomId, penalty);
  }

  function setCaptureTileFamePenalty(uint256 characterId, uint8 penalty) public onlyAuthorizedWallet(characterId) {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);
    if (penalty > 100) {
      revert Errors.KingSystem_InvalidFamePenalty(penalty);
    }
    KingSetting.setCaptureTilePenalty(charKingdomId, penalty);
  }

  function setNewCity(
    uint256 characterId,
    int32 x,
    int32 y,
    string memory name
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);
    if (TileInfo3.getKingdomId(x, y) != charKingdomId) {
      revert Errors.KingSystem_NotOwnTile(charKingdomId, x, y);
    }
    if (!MapUtils.isValidCityLocation(x, y)) {
      revert Errors.KingSystem_InvalidCityLocation(x, y);
    }
    if (bytes(name).length < 3 || bytes(name).length > 20) {
      revert Errors.KingSystem_InvalidCityName(name);
    }
    uint8 numCityToBuild = KingdomV2.getNumCityToBuild(charKingdomId);
    if (numCityToBuild == 0) {
      revert Errors.KingSystem_NoCityToBuild(charKingdomId);
    }
    KingdomV2.setNumCityToBuild(charKingdomId, numCityToBuild - 1);
    uint256 newCityId = CityCounter.get() + 1;
    CityCounter.set(newCityId);

    City.set(newCityId, x, y, false, charKingdomId, 0, name);
    RestrictLocation.set(x, y, true); // Mark the location as restricted for new cities
  }

  function setRole(uint256 characterId, uint256 citizenId, RoleType role) public onlyAuthorizedWallet(characterId) {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);
    if (CharInfo.getKingdomId(citizenId) != charKingdomId) {
      revert Errors.KingSystem_NotCitizenOfKingdom(citizenId, charKingdomId);
    }
    if (CharRole.get(characterId) == role) {
      return; // No change needed
    }
    if (role == RoleType.None) {
      CharRole.deleteRecord(citizenId);
      return;
    }
    if (role == RoleType.VaultKeeper || role == RoleType.KingGuard) {
      CharRole.set(citizenId, role);
    } else {
      revert Errors.KingSystem_InvalidRole(role); // Ensure only valid roles are set
    }
  }

  function _validateKingdomId(uint8 kingdomId) private view {
    if (kingdomId < 1 || kingdomId > 4) {
      revert Errors.KingSystem_InvalidKingdomId(kingdomId);
    }
  }

  function _checkElectionTime(uint8 kingdomId) private view {
    if (!_isInElectionTime(kingdomId, block.timestamp)) {
      revert Errors.KingSystem_NotInElectionTime();
    }
  }

  function _isInElectionTime(uint8 kingdomId, uint256 timeCheck) private view returns (bool) {
    uint256 electionTimestamp = KingElection.getTimestamp(kingdomId);
    return (timeCheck + OFFSET_DURATION) >= electionTimestamp && timeCheck <= electionTimestamp;
  }

  function _assignKing(uint8 kingdomId, uint256 oldKingId, uint256 candidateId) private {
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

  function _findTopCandidate(
    uint256[] memory candidateIds,
    uint32[] memory voteReceived
  )
    private
    view
    returns (uint256)
  {
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
}
