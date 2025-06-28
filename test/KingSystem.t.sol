pragma solidity >=0.8.24;

import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";
import { console2 } from "forge-std/console2.sol";
import {
  KingElection,
  KingElectionData,
  CharStats,
  CharInfo,
  CharStats2,
  CharVote,
  CharVoteData,
  CandidatePromise,
  CharCurrentStats,
  CharCurrentStatsData,
  AllianceV2,
  AllianceV2Data,
  MarketFee
} from "@codegen/index.sol";

contract KingSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address candidate = makeAddr("candidate");
  uint256 candidateId;

  address voter = makeAddr("voter");
  uint256 voterId;

  address voter2 = makeAddr("voter2");
  uint256 voter2Id;

  uint32 constant KING_MIN_FAME_REQUIRE = 2000;
  uint32 constant VOTER_MIN_FAME_REQUIRE = 1050;
  uint32 constant TERM_DURATION = 1_209_600; // 14 days in seconds
  uint32 constant OFFSET_DURATION = 172_800; // 2 days in seconds
  uint256 constant KING_ACHIEVEMENT_ID = 10;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    candidateId = _createDefaultCharacter(candidate);
    _claimWelcomePackages(candidate, candidateId);

    voterId = _createCharacterWithName(voter, "abc");
    _claimWelcomePackages(voter, voterId);

    voter2Id = _createCharacterWithNameAndKingdomId(voter2, "123", 2);
    _claimWelcomePackages(voter2, voter2Id);
  }

  function test_KingSystem() external {
    vm.expectRevert(); // fame too low
    vm.startPrank(candidate);
    world.app__registerKing(candidateId, "hello world");
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharStats2.setFame(candidateId, 2000);
    vm.stopPrank();

    vm.startPrank(candidate);
    world.app__registerKing(candidateId, "Promise summary");
    vm.stopPrank();

    assertEq(CandidatePromise.getContent(candidateId), "Promise summary");

    uint8 candidateKingdomId = CharInfo.getKingdomId(candidateId);
    console2.log("candidateKingdomId", candidateKingdomId);

    KingElectionData memory k1Election = KingElection.get(candidateKingdomId);
    assertEq(k1Election.candidateIds[0], candidateId);
    assertEq(k1Election.votesReceived[0], 0);
    assertEq(k1Election.timestamp, 1 + OFFSET_DURATION);

    KingElectionData memory k2Election = KingElection.get(2);
    assertEq(k2Election.candidateIds.length, 0);
    assertEq(k2Election.timestamp, 0);

    vm.expectRevert(); // no one registered yet
    vm.startPrank(voter2);
    world.app__voteKing(voter2Id, 100);
    vm.stopPrank();

    vm.expectRevert(); // fame too low
    vm.startPrank(voter);
    world.app__voteKing(voterId, candidateId);
    vm.stopPrank();

    vm.expectRevert(); // vote for self
    vm.startPrank(voter);
    world.app__voteKing(voterId, voterId);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharStats2.setFame(voterId, 1050);
    vm.stopPrank();

    vm.expectRevert(); // invalid candidate id
    vm.startPrank(voter);
    world.app__voteKing(voterId, voter2Id);
    vm.stopPrank();

    vm.startPrank(voter);
    world.app__voteKing(voterId, candidateId);
    vm.stopPrank();
    k1Election = KingElection.get(candidateKingdomId);
    assertEq(k1Election.votesReceived[0], 1050);
    CharVoteData memory charVote = CharVote.get(voterId);
    assertEq(charVote.votePower, 1050);
    assertEq(charVote.candidateId, candidateId);
    uint256 currentElectionTimestamp = k1Election.timestamp;

    vm.expectRevert(); // already voted
    vm.startPrank(voter);
    world.app__voteKing(voterId, candidateId);
    vm.stopPrank();

    vm.warp(block.timestamp + OFFSET_DURATION);
    vm.startPrank(voter2);
    world.app__assignKing(candidateKingdomId);
    vm.stopPrank();

    k1Election = KingElection.get(candidateKingdomId);
    assertEq(k1Election.kingId, candidateId);
    assertEq(k1Election.timestamp, currentElectionTimestamp + TERM_DURATION);
    assertEq(k1Election.candidateIds.length, 0);
    assertEq(k1Election.votesReceived.length, 0);

    vm.expectRevert(); // not in election time
    vm.startPrank(candidate);
    world.app__registerKing(candidateId, "Promise summary");
    vm.stopPrank();
    // jump to next election time
    vm.warp(currentElectionTimestamp + TERM_DURATION - OFFSET_DURATION);
    vm.startPrank(candidate);
    world.app__registerKing(candidateId, "Promise summary");
    vm.stopPrank();
    vm.startPrank(worldDeployer);
    CharStats2.setFame(voterId, 2100);
    CharStats2.setFame(voter2Id, 2100);
    vm.stopPrank();
    vm.startPrank(voter);
    world.app__registerKing(voterId, "Promise summary");
    vm.stopPrank();

    vm.expectRevert(); // election time not over yet
    vm.startPrank(voter2);
    world.app__assignKing(candidateKingdomId);
    vm.stopPrank();

    CharCurrentStatsData memory candidateCurrentStats = CharCurrentStats.get(candidateId);

    vm.warp(block.timestamp + OFFSET_DURATION);
    vm.startPrank(voter2);
    world.app__assignKing(candidateKingdomId);
    vm.stopPrank();

    k1Election = KingElection.get(candidateKingdomId);
    assertEq(k1Election.kingId, voterId);
    assertEq(k1Election.timestamp, currentElectionTimestamp + TERM_DURATION + TERM_DURATION);

    assertEq(CharCurrentStats.getAtk(candidateId) + 15, candidateCurrentStats.atk);
    assertEq(CharCurrentStats.getDef(candidateId) + 15, candidateCurrentStats.def);
    assertEq(CharCurrentStats.getAgi(candidateId) + 15, candidateCurrentStats.agi);

    vm.startPrank(voter2);
    world.app__registerKing(voter2Id, "123");
    vm.stopPrank();

    CharCurrentStatsData memory voter2CurrentStats = CharCurrentStats.get(voter2Id);

    k2Election = KingElection.get(2);
    assertEq(k2Election.candidateIds.length, 1);
    assertEq(k2Election.candidateIds[0], voter2Id);
    assertEq(k2Election.votesReceived.length, 1);
    assertEq(k2Election.votesReceived[0], 0);
    assertEq(k2Election.timestamp, block.timestamp + OFFSET_DURATION);
    uint256 kingdom2ElectionTimestamp = k2Election.timestamp;
    vm.warp(block.timestamp + OFFSET_DURATION + 1);
    vm.startPrank(voter2);
    world.app__assignKing(2);
    vm.stopPrank();

    k2Election = KingElection.get(2);
    assertEq(k2Election.kingId, voter2Id);
    assertEq(k2Election.timestamp, kingdom2ElectionTimestamp + TERM_DURATION);

    // check achievements
    assertEq(CharCurrentStats.getAtk(voter2Id), voter2CurrentStats.atk + 15);
    assertEq(CharCurrentStats.getDef(voter2Id), voter2CurrentStats.def + 15);
    assertEq(CharCurrentStats.getAgi(voter2Id), voter2CurrentStats.agi + 15);

    // test alliance
    vm.startPrank(voter2);
    world.app__setAlliance(voter2Id, 1, true);
    vm.stopPrank();

    vm.startPrank(voter);
    world.app__setAlliance(voterId, 2, true);
    vm.stopPrank();
    AllianceV2Data memory alliance = AllianceV2.get(2, 1);
    assertTrue(alliance.isAlliance);
    assertTrue(alliance.isApproved);

    alliance = AllianceV2.get(1, 2);
    assertFalse(alliance.isAlliance);
    assertFalse(alliance.isApproved);

    vm.startPrank(voter2);
    world.app__setAlliance(voter2Id, 1, false);
    vm.stopPrank();
    alliance = AllianceV2.get(1, 2);
    assertFalse(alliance.isAlliance);
    assertFalse(alliance.isApproved);
    alliance = AllianceV2.get(2, 1);
    assertFalse(alliance.isAlliance);
    assertFalse(alliance.isApproved);

    vm.expectRevert(); // not king
    vm.startPrank(candidate);
    world.app__setMarketFee(candidateId, 2, 99);
    vm.stopPrank();

    vm.startPrank(voter);
    world.app__setMarketFee(voterId, 2, 99);
    vm.stopPrank();
    assertEq(MarketFee.get(1, 2), 99);
  }
}
