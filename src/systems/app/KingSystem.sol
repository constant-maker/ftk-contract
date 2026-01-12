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
  KingSetting2,
  TileInfo3,
  City,
  RestrictLocV2,
  CityCounter,
  Kingdom,
  CharRole,
  CharRoleCounter,
  KingdomCityCounter,
  VaultRestriction
} from "@codegen/index.sol";
import { CharAchievementUtils, MapUtils, CharacterRoleUtils, KingSystemUtils } from "@utils/index.sol";
import { Errors, Config } from "@common/index.sol";
import { ZoneType, RoleType } from "@codegen/common.sol";
import { VaultRestrictionParam } from "./KingSystem.sol";

struct VaultRestrictionParam {
  uint256 itemId;
  bool isRestricted;
}

contract KingSystem is CharacterAccessControl, System {
  uint32 constant KING_MIN_FAME_REQUIRE = 2000;
  uint32 constant VOTER_MIN_FAME_REQUIRE = 1020;

  function registerKing(uint256 characterId, string memory promiseSummary) public onlyAuthorizedWallet(characterId) {
    uint8 kingdomId = CharInfo.getKingdomId(characterId);
    KingElectionData memory kingElection = KingElection.get(kingdomId);
    if (kingElection.timestamp == 0) {
      kingElection.timestamp = block.timestamp + KingSystemUtils.OFFSET_DURATION;
      KingElection.setTimestamp(kingdomId, kingElection.timestamp);
    }
    uint32 fame = CharStats2.getFame(characterId);
    if (fame < KING_MIN_FAME_REQUIRE) {
      revert Errors.KingSystem_InsufficientFameForKingElection(characterId, fame);
    }
    KingSystemUtils.checkElectionTime(kingdomId);
    for (uint256 i = 0; i < kingElection.candidateIds.length; i++) {
      if (kingElection.candidateIds[i] == characterId) {
        revert Errors.KingSystem_AlreadyRegistered(characterId);
      }
    }
    KingElection.pushCandidateIds(kingdomId, characterId);
    uint32 initVote = (fame - Config.DEFAULT_FAME) / 2;
    KingElection.pushVotesReceived(kingdomId, initVote);
    CandidatePromise.set(characterId, block.timestamp, promiseSummary);
  }

  function assignKing(uint8 kingdomId) public {
    KingElectionData memory kingElection = KingElection.get(kingdomId);
    if (kingElection.timestamp > block.timestamp) {
      revert Errors.KingSystem_ElectionPeriodNotOverYet();
    }
    if (kingElection.candidateIds.length == 0) {
      uint256 nextElectionTimestamp = KingElection.getTimestamp(kingdomId) + KingSystemUtils.TERM_DURATION;
      KingElection.setTimestamp(kingdomId, nextElectionTimestamp);
      return;
    }

    uint256 topCandidateId = KingSystemUtils.findTopCandidate(kingElection.candidateIds, kingElection.votesReceived);
    // remove new king from previous role if any
    RoleType currentRole = CharRole.get(topCandidateId);
    if (currentRole != RoleType.None) {
      CharRole.deleteRecord(topCandidateId);
      CharacterRoleUtils.updateRoleAchievement(topCandidateId, currentRole, true);
      uint32 currentCount = CharRoleCounter.getCount(kingdomId, currentRole);
      if (currentCount > 0) {
        CharRoleCounter.setCount(kingdomId, currentRole, currentCount - 1);
      }
    }
    // assign new king
    KingSystemUtils.assignKing(kingdomId, kingElection.kingId, topCandidateId);
  }

  function voteKing(uint256 characterId, uint256 candidateId) public onlyAuthorizedWallet(characterId) {
    uint8 kingdomId = CharInfo.getKingdomId(characterId);
    KingSystemUtils.checkElectionTime(kingdomId);

    if (characterId == candidateId) {
      revert Errors.KingSystem_CannotVoteForSelf(characterId);
    }

    uint32 fame = CharStats2.getFame(characterId);
    if (fame < VOTER_MIN_FAME_REQUIRE) {
      revert Errors.KingSystem_InsufficientFameForVoting(characterId, fame);
    }

    if (
      KingSystemUtils.isInElectionTime(kingdomId, CharVote.getTimestamp(characterId))
        && CharVote.getCandidateId(characterId) != 0
    ) {
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
    uint32 votePower = fame - Config.DEFAULT_FAME;
    KingElection.updateVotesReceived(kingdomId, candidateIndex, kingElection.votesReceived[candidateIndex] + votePower);
    CharVote.set(characterId, candidateId, votePower, block.timestamp);
  }

  function setAlliance(uint256 characterId, uint8 otherKingdomId, bool value) public onlyAuthorizedWallet(characterId) {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);
    KingSystemUtils.validateKingdomId(otherKingdomId);
    if (charKingdomId == otherKingdomId) {
      return;
    }
    KingSystemUtils.setAlliance(charKingdomId, otherKingdomId, value);
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
      KingSystemUtils.validateKingdomId(kingdomId);
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
    uint256 currentCounter = KingdomCityCounter.getCounter(charKingdomId);
    // each 5 levels will gain 1 city
    if (currentCounter >= (City.getLevel(Kingdom.getCapitalId(charKingdomId)) / 5) + 1) {
      revert Errors.KingSystem_ExceedMaxNumCity(charKingdomId);
    }
    KingdomCityCounter.set(charKingdomId, currentCounter + 1);
    uint256 newCityId = CityCounter.get() + 1;
    CityCounter.set(newCityId);

    City.set(newCityId, x, y, false, charKingdomId, 0, name);
    RestrictLocV2.set(x, y, newCityId, true); // Mark the location as restricted for new cities
  }

  function moveCity(uint256 characterId, int32 x, int32 y, uint256 cityId) public onlyAuthorizedWallet(characterId) {
    KingSystemUtils.moveCity(characterId, x, y, cityId);
  }

  function setRole(uint256 characterId, uint256 citizenId, RoleType role) public onlyAuthorizedWallet(characterId) {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);

    if (CharInfo.getKingdomId(citizenId) != charKingdomId) {
      revert Errors.KingSystem_NotCitizenOfKingdom(citizenId, charKingdomId);
    }

    if (characterId == citizenId) {
      revert Errors.KingSystem_CannotSetRoleForKing();
    }

    RoleType currentRole = CharRole.get(citizenId);
    if (currentRole == role) return;

    if (currentRole != RoleType.None) {
      CharRole.deleteRecord(citizenId);
      CharacterRoleUtils.updateRoleAchievement(citizenId, currentRole, true);
      uint32 currentCount = CharRoleCounter.getCount(charKingdomId, currentRole);
      if (currentCount > 0) {
        CharRoleCounter.setCount(charKingdomId, currentRole, currentCount - 1);
      }
    }

    if (role == RoleType.None) return;

    if (role == RoleType.VaultKeeper || role == RoleType.KingGuard) {
      KingSystemUtils.checkAndUpdateRoleLimit(charKingdomId, role);
      KingSystemUtils.checkUserEligible(citizenId, role);
      CharRole.set(citizenId, role);
      CharacterRoleUtils.updateRoleAchievement(citizenId, role, false);
    } else {
      revert Errors.KingSystem_InvalidRole(role);
    }
  }

  function setWithdrawWeightLimit(uint256 characterId, uint32 weightLimit) public onlyAuthorizedWallet(characterId) {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);
    KingSetting2.setWithdrawWeightLimit(charKingdomId, weightLimit);
  }

  function setWithdrawRestriction(
    uint256 characterId,
    VaultRestrictionParam[] calldata data
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    CharacterRoleUtils.mustBeKing(charKingdomId, characterId);
    for (uint256 i = 0; i < data.length; i++) {
      uint256 itemId = data[i].itemId;
      if (!data[i].isRestricted) {
        VaultRestriction.deleteRecord(charKingdomId, itemId);
        continue;
      }
      VaultRestriction.setIsRestricted(charKingdomId, itemId, data[i].isRestricted);
    }
  }
}
