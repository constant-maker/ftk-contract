pragma solidity >=0.8.24;

library Config {
  uint8 public constant DEFAULT_MOVEMENT_SPEED = 1;
  uint8 public constant MAX_MOVEMENT_SPEED = 20;
  uint8 public constant HP_GAIN_PER_LEVEL = 20;
  uint8 public constant DEFAULT_SKILL_POINT = 3;
  uint8 public constant MAX_PERK_LEVEL = 9; // Perk level starts from 0 ~ so max is 10 on UI
  uint8 public constant AMOUNT_RECEIVE_FROM_FARMING = 5;
  uint8 public constant DEFAULT_MARKET_FEE = 5; // 5%
  uint8 public constant MAX_CRYSTAL_FEE = 10; // 10%

  uint16 public constant DEFAULT_MOVEMENT_DURATION = 8; // Seconds
  uint16 public constant DEFAULT_PLAYER_ACTION_DURATION = 10; // Seconds
  uint16 public constant MAX_LEVEL = 99;
  uint16 public constant ONE_HAND_ADVANTAGE_TYPE_DAMAGE_MODIFIER = 8; // 8%
  uint16 public constant TWO_HAND_ADVANTAGE_TYPE_DAMAGE_MODIFIER = 15; // 15%
  uint16 public constant ATTACK_COOLDOWN = 2; // Seconds
  uint16 public constant PVE_ATTACK_COOLDOWN = 10; // Seconds
  uint16 public constant CHALLENGE_COOLDOWN = 10; // Seconds
  uint16 public constant PROTECTION_DURATION = 0; // Seconds
  uint16 public constant BASE_DMG = 20;
  uint32 public constant DEFAULT_HP = 100;
  uint32 public constant DEFAULT_WEIGHT = 200;
  uint32 public constant BONUS_ATTACK_AGI_DIFF = 10;
  uint32 public constant DEFAULT_FAME = 1000;

  uint32 public constant BASE_RESOURCE_PERK_EXP = 15;
  uint32 public constant UPGRADE_STORAGE_COST = 50; // Golds
  uint32 public constant INIT_STORAGE_MAX_WEIGHT = 300;
  uint32 public constant STORAGE_MAX_WEIGHT_INCREMENT = 100;
  uint32 public constant TILE_ITEM_AVAILABLE_DURATION = 3600; // 1 hour (Seconds)

  uint256 public constant NORMAL_ATTACK_SKILL_ID = 0;

  uint32 public constant MIN_PROTECT_FAME = 500; // Minimum fame to be protected in green zone
  uint32 public constant GREEN_ZONE_FAME_PENALTY = 50;
  uint32 public constant MIN_FAME = 1;
  uint32 public constant LOST_FAME_PENALTY = 20;
  uint32 public constant GAINED_FAME_REWARD = 10;
  uint32 public constant MIN_FAME_THRESHOLD = 1070;
  uint256 public constant LOW_FAME_DEBUFF_ID = 458;

  uint256 public constant TELEPORT_DURATION = 60; // Seconds

  uint256 public constant MIN_CRYSTALS_PER_PURCHASE = 100; // Minimum crystals per purchase
  uint256 public constant CREATE_CHARACTER_FEE = 0.0001 ether; // TODO: Adjust later on mainnet
  uint256 public constant CRYSTAL_UNIT_PRICE = 0.000005 ether;
  uint256 public constant MIN_SELL_CRYSTAL = 1000; // Minimum crystals to sell
  uint256 public constant MIN_PET_CRYSTAL_PRICE = 1000; // Minimum crystal price for pet item
  uint256 public constant SELL_CRYSTAL_PROCESSING_TIME = 3 days; // 3 days
  uint256 public constant PLATFORM_FEE_PERCENTAGE = 3; // platform fee (apply for crystal only)
  uint256 public constant FEE_PERCENT_SHARE_TO_BACKER = 50; // 50% of team-received amount goes to backer
  address public constant TEAM_ADDRESS = address(0x0);
}
