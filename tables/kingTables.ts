const KING_TABLES: any = {
  KingElection: {
    schema: {
      kingdomId: 'uint8', // kingdom id
      kingId: 'uint256', // character id that is elected as king
      timestamp: 'uint256',
      candidateIds: 'uint256[]',
      votesReceived: 'uint32[]'
    },
    key: ['kingdomId'],
  },
  CandidatePromise: {
    schema: {
      candidateId: 'uint256',
      timestamp: 'uint256', // timestamp when the promise was made
      content: 'string',
    },
    key: ['candidateId'],
  },
  CharVote: {
    schema: {
      characterId: 'uint256',
      candidateId: 'uint256',
      votePower: 'uint32',
      timestamp: 'uint256', // timestamp when the vote was cast
    },
    key: ['characterId'],
  },
  KingSetting: {
    schema: {
      kingdomId: 'uint8',
      pvpFamePenalty: 'uint16', // penalty for killing ally
      captureTilePenalty: 'uint16', // penalty for capturing tile of ally kingdom
    },
    key: ['kingdomId'],
  },
}

export default KING_TABLES;