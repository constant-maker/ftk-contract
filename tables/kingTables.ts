const KING_TABLES: any = {
  KingElection: {
    schema: {
      kingdomId: 'uint8',
      kingId: 'uint256', // Character id that is elected as king
      timestamp: 'uint256',
      candidateIds: 'uint256[]',
      votesReceived: 'uint32[]'
    },
    key: ['kingdomId'],
  },
  CandidatePromise: {
    schema: {
      candidateId: 'uint256',
      timestamp: 'uint256', // Timestamp when the promise was made
      content: 'string',
    },
    key: ['candidateId'],
  },
  CharVote: {
    schema: {
      characterId: 'uint256',
      candidateId: 'uint256',
      votePower: 'uint32',
      timestamp: 'uint256', // Timestamp when the vote was cast
    },
    key: ['characterId'],
  },
  KingSetting: {
    schema: {
      kingdomId: 'uint8',
      pvpFamePenalty: 'uint16', // Penalty for killing ally
      captureTilePenalty: 'uint16', // Penalty for capturing tile of ally kingdom
      withdrawWeightLimit: 'uint32', // Daily weight limit for withdrawing resources from kingdom treasury
    },
    key: ['kingdomId'],
  },
  Alliance: {
    schema: {
      kingdomA: "uint8",
      kingdomB: "uint8",
      isAlliance: "bool",
      isApproved: "bool",
    },
    key: ['kingdomA', 'kingdomB'],
  },
}

export default KING_TABLES;