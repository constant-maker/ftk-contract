pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharStats2, KingRegistration, KingRegistrationData, CandidatePromise } from "@codegen/index.sol";
import { Errors } from "@common/index.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";

contract KingSystem is CharacterAccessControl, System {
  uint32 constant KING_MIN_FAME_REQUIRE = 2000;
  uint32 constant TERM_DURATION = 1_209_600; // 14 days in seconds
  uint32 constant OFFSET_DURATION = 172_800; // 2 days in seconds

  function register(uint256 characterId, string memory promise) public onlyAuthorizedWallet(characterId) {
    KingRegistrationData memory kingRegistration = KingRegistration.get();
    if (kingRegistration.timestamp == 0) {
      kingRegistration.timestamp = block.timestamp + OFFSET_DURATION;
      KingRegistration.setTimestamp(kingRegistration.timestamp);
    }
    uint32 fame = CharStats2.getFame(characterId);
    if (fame < KING_MIN_FAME_REQUIRE) {
      revert Errors.KingSystem_InsufficientFameForKingRegistration(characterId, fame);
    }
    _checkElectionTime();
    for (uint256 i = 0; i < kingRegistration.candidateIds.length; i++) {
      if (kingRegistration.candidateIds[i] == characterId) {
        revert Errors.KingSystem_AlreadyRegistered(characterId);
      }
    }
    KingRegistration.pushCandidateIds(characterId);
    KingRegistration.pushVotesReceived(0);
    CandidatePromise.setContent(characterId, promise);
  }

  function unregister(uint256 characterId) public onlyAuthorizedWallet(characterId) {
    _checkElectionTime();
    KingRegistrationData memory kingRegistration = KingRegistration.get();
    bool found = false;
    uint256 indexToRemove;
    for (uint256 i = 0; i < kingRegistration.candidateIds.length; i++) {
      if (kingRegistration.candidateIds[i] == characterId) {
        found = true;
        indexToRemove = i;
        break;
      }
    }
    if (!found) {
      revert Errors.KingSystem_NotRegistered(characterId);
    }
    if (indexToRemove != kingRegistration.candidateIds.length - 1) {
      // If the candidate is not the last one, we need to swap it with the last one
      // to maintain the integrity of the arrays
      // We will replace the candidateId and votesReceived at indexToRemove with the last one
      // and then pop the last element from both arrays
      uint256 lastCandidateId = kingRegistration.candidateIds[kingRegistration.candidateIds.length - 1];
      uint256 lastVotesReceived = kingRegistration.votesReceived[kingRegistration.votesReceived.length - 1];
      KingRegistration.updateCandidateIds(indexToRemove, lastCandidateId);
      KingRegistration.updateVotesReceived(indexToRemove, lastVotesReceived);
    }
    KingRegistration.popCandidateIds();
    KingRegistration.popVotesReceived();
    CandidatePromise.deleteContent(characterId);
  }

  function assignKing() public {
    KingRegistrationData memory kingRegistration = KingRegistration.get();
    if (kingRegistration.timestamp < block.timestamp) {
      revert Errors.KingSystem_RegistrationPeriodNotOverYet();
    }
    uint32 maxVote;
    uint32 count;
    for (uint256 i = 0; i < kingRegistration.votesReceived.length; i++) {
      if (kingRegistration.votesReceived[i] > maxVote) {
        maxVote = kingRegistration.votesReceived[i];
        count = 1;
      } else if (kingRegistration.votesReceived[i] == maxVote) {
        count++;
      }
    }
  }

  function vote(uint256 characterId, uint256 candidateId) public onlyAuthorizedWallet(characterId) {}
  function revokeVote(uint256 characterId) public onlyAuthorizedWallet(characterId) {}

  function _checkElectionTime() private view {
    uint256 electionTimestamp = KingRegistration.getTimestamp();
    if (block.timestamp > electionTimestamp || (block.timestamp + OFFSET_DURATION) < electionTimestamp) {
      revert Errors.KingSystem_NotInElectionTime();
    }
  }
}
