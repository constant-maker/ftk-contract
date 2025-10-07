import { start } from "repl";

const BATTLE_TABLES: any = {
  CharBattle: {
    schema: {
      characterId: "uint256",
      lastPvpId: "uint256",
      pvpLastAtkTime: "uint256",
      pvpLastDefTime: "uint256",
      pveLastAtkTime: "uint256",
    },
    key: ['characterId'],
  },
  PvPChallengeV2: {
    schema: {
      attackerId: "uint256",
      defenderId: "uint256",
      firstAttackerId: "uint256",
      timestamp: "uint256",
      skillIds: "uint256[11]",
      damages: "uint32[11]",
      hps: "uint32[2]",
      barriers: "uint32[2]",
    },
    key: ['attackerId'],
  },
  PvP: {
    schema: {
      id: "uint256",
      attackerId: "uint256",
      defenderId: "uint256",
      firstAttackerId: "uint256",
      timestamp: "uint256",
      prevPvpIds: "uint256[2]",
      skillIds: "uint256[11]",
      damages: "uint32[11]",
      hps: "uint32[2]",
    },
    key: ['id'],
  },
  PvPExtraV3: {
    schema: {
      pvpId: "uint256",
      characterLevels: "uint16[2]",
      characterSps: "uint8[2]",
      barriers: "uint32[2]",
      fames: "int32[2]",
      equipmentIds: "uint256[12]",
    },
    key: ['pvpId'],
  },
  PvPExtra2V2: {
    schema: {
      pvpId: "uint256",
      x: "int32",
      y: "int32",
      attackerStats: "uint16[3]", // attacker atk, def, agi
      defenderStats: "uint16[3]", // defender atk, def, agi
    },
    key: ['pvpId'],
  },
  PvPBattleCounter: {
    schema: {
      counter: "uint256",
    },
    key: [],
  },
  PvPEnemyCounter: {
    schema: {
      characterId: "uint256",
      counter: "uint256",
    },
    key: ['characterId'],
  },
  PvE: {
    schema: {
      characterId: "uint256",
      monsterId: "uint256",
      x: "int32",
      y: "int32",
      firstAttacker: "EntityType",
      counter: "uint256",
      timestamp: "uint256",
      characterSkillIds: "uint256[5]",
      damages: "uint32[11]",
      hps: "uint32[2]",
    },
    key: ['characterId'],
  },
  PvEExtraV2: {
    schema: {
      characterId: "uint256",
      itemId: "uint256", // reward
      itemAmount: "uint32",
      characterBarrier: "uint32",
    },
    key: ['characterId'],
  },
  DropResource: { // List resources will be dropped in red zone
    schema: {
      resourceIds: "uint256[]",
    },
    key: [],
  },
  PvEAfk: {
    schema: {
      characterId: "uint256",
      monsterId: "uint256",
      startTime: "uint256",
      expPerTick: "uint32",
      perkExpPerTick: "uint32",
      maxTick: "uint32",
    },
    key: ['characterId'],
  },
  PvEAfkLoc: {
    schema: {
      x: "int32",
      y: "int32",
      monsterId: "uint256",
    },
    key: ['x', 'y'],
  },
};

export default BATTLE_TABLES;
