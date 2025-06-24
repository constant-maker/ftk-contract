const VOTE_TABLES: any = {
  KingRegistration: {
    schema: {
      kingId: 'uint256', // character id that is elected as king
      timestamp: 'uint256',
      candidateIds: 'uint256[]',
      votesReceived: 'uint32[]'
    },
    key: [],
  },
  CandidatePromise: {
    schema: {
      candidateId: 'uint256',
      content: 'string',
    },
    key: ['candidateId'],
  },
  CharVote: {
    schema: {
      characterId: 'uint256',
      candidateId: 'uint256',
      voteCount: 'uint32',
      timestamp: 'uint256',
    },
    key: ['characterId'],
  },
}

export default VOTE_TABLES;