pragma solidity >=0.8.24;

library Config {
  uint8 public constant DEFAULT_MOVEMENT_SPEED = 1;
  uint8 public constant MAX_MOVEMENT_SPEED = 20;
  uint8 public constant HP_GAIN_PER_LEVEL = 20;
  uint8 public constant DEFAULT_SKILL_POINT = 3;
  uint8 public constant MAX_PERK_LEVEL = 9; // perk level starts from 0 ~ so max is 10 on UI
  uint8 public constant AMOUNT_RECEIVE_FROM_FARMING = 5;
  uint8 public constant DEFAULT_MARKET_FEE = 5; // 5%

  uint16 public constant DEFAULT_MOVEMENT_DURATION = 10;
  uint16 public constant DEFAULT_PLAYER_ACTION_DURATION = 10;
  uint16 public constant MAX_LEVEL = 99;
  uint16 public constant MAX_BASE_STAT = 130;
  uint16 public constant ADVANTAGE_TYPE_DAMAGE_MODIFIER = 15; // 15%
  uint16 public constant ATTACK_COOLDOWN = 3; // seconds
  uint16 public constant PVE_ATTACK_COOLDOWN = 10; // seconds
  uint16 public constant CHALLENGE_COOLDOWN = 10;
  uint16 public constant PROTECTION_DURATION = 0;
  uint16 public constant BASE_DMG = 20;
  uint32 public constant DEFAULT_HP = 100;
  uint32 public constant DEFAULT_WEIGHT = 200;
  uint32 public constant BONUS_ATTACK_AGI_DIFF = 10;

  uint32 public constant BASE_RESOURCE_PERK_EXP = 15;
  uint32 public constant UPGRADE_STORAGE_COST = 50; // golds
  uint32 public constant INIT_STORAGE_MAX_WEIGHT = 300;
  uint32 public constant STORAGE_MAX_WEIGHT_INCREMENT = 100;
  uint32 public constant TILE_ITEM_AVAILABLE_DURATION = 3600; // 1 hour (second)

  uint256 public constant NORMAL_ATTACK_SKILL_ID = 0;
  uint256 public constant MAX_EQUIPMENT_ID_TO_CHECK_CACHE_WEIGHT = 16_000;
}
