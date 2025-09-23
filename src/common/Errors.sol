pragma solidity >=0.8.24;

import {
  CharacterStateType, ResourceType, ItemType, SlotType, StatType, SocialType, RoleType
} from "../codegen/common.sol";

library Errors {
  // common errors
  error InvalidCityId(uint256 cityId);
  error MustInACity(uint256 cityId, int32 charX, int32 charY);
  error MustInACapital(uint256 capitalId, int32 charX, int32 charY);
  error MustBeCapitalCity(uint256 cityId);
  error CityBelongsToOtherKingdom(uint8 originalKingdomId, uint8 currentKingdomId);

  /* -------------------------------------------------------------------------- */
  /*                                Spawn system                                */
  /* -------------------------------------------------------------------------- */
  error SpawnSystem_CharacterNameExisted(string name);
  error SpawnSystem_InvalidCharacterName(string name);
  error SpawnSystem_InvalidKingdomId(uint8 kingdomId);
  error SpawnSystem_InvalidTraitStats(uint16 traitStats);

  /* -------------------------------------------------------------------------- */
  /*                                  Character                                 */
  /* -------------------------------------------------------------------------- */
  error Character_NotCharacterOwner(uint256 characterId, address wallet);
  error Character_LastActionNotFinished(CharacterStateType characterState, uint256 endTimestamp);
  error Character_InvalidCharacterMovementSpeed(uint16 characterMovementSpeed, uint16 baseDuration);
  error Character_NoActiveCharacter(address wallet);
  error Character_MustInState(
    CharacterStateType characterState, CharacterStateType requiredCharacterState, uint256 blockTime
  );
  error Character_NotAtCapital(int32 characterX, int32 characterY, int32 capitalX, int32 capitalY);
  error Character_WelcomePackagesClaimed(uint256 characterId);
  error Character_WeightsExceed(uint32 newWeight, uint32 maxWeight);
  error Character_PerkLevelTooLow(uint256 characterId, uint8 perksLevel, ItemType itemType, uint8 itemTier);

  /* -------------------------------------------------------------------------- */
  /*                                   Tool                                     */
  /* -------------------------------------------------------------------------- */
  error Tool_NotExisted(uint256 toolId);
  error Tool_NotOwned(uint256 characterId, uint256 toolId);
  error Tool_TierNotSatisfied(uint8 resourceTier, uint8 itemTier);
  error Tool_InvalidItemType(ResourceType resourceType, ItemType gotItemType);
  error Tool_InsufficientDurability(uint256 toolId);
  error Tool_AlreadyHad(uint256 characterId, uint256 toolId);

  /* -------------------------------------------------------------------------- */
  /*                              Equipment                                     */
  /* -------------------------------------------------------------------------- */
  error Equipment_NotOwned(uint256 characterId, uint256 equipmentId);
  error Equipment_AlreadyHad(uint256 characterId, uint256 equipmentId);
  error Equipment_NotExisted(uint256 equipmentId);
  error EquipmentSystem_CharacterLevelTooLow(uint256 characterId, uint16 level, uint8 itemTier);

  /* -------------------------------------------------------------------------- */
  /*                                 Move system                                */
  /* -------------------------------------------------------------------------- */
  error MoveSystem_CannotMove();
  error MoveSystem_CannotConfirmMove();
  error MoveSystem_NeedConfirmMove();
  error MoveSystem_MovePositionError(int32 x, int32 y, int32 newX, int32 newY);

  /* -------------------------------------------------------------------------- */
  /*                               Farming system                               */
  /* -------------------------------------------------------------------------- */
  error FarmingSystem_NoFarmSlot(int32 x, int32 y);
  error FarmingSystem_MustFarmAResource(uint256 resourceItemId);
  error FarmingSystem_NoResourceInCurrentTile(int32 x, int32 y, uint256 resourceItemId);
  error FarmingSystem_NoCurrentFarming(uint256 characterId);
  error FarmingSystem_ParticipantsExceed(uint32 participants, uint32 totalAmount);
  error FarmingSystem_MonsterLootResourceNeedHunting();
  error FarmingSystem_PerkLevelTooLow(uint8 perkLevel, uint8 resourceTier);
  error FarmingSystem_ExceedFarmingQuota(int32 x, int32 y, uint256 itemId);

  /* -------------------------------------------------------------------------- */
  /*                                    Item                                    */
  /* -------------------------------------------------------------------------- */
  error Item_AddItemExisted(uint256 itemId);
  error Item_NotExisted(uint256 itemId);

  /* -------------------------------------------------------------------------- */
  /*                                Equipment System                            */
  /* -------------------------------------------------------------------------- */
  error EquipmentSystem_InsufficientDurability(uint256 equipmentId, uint32 currentDurability, uint32 durabilityCost);
  error EquipmentSystem_UnmatchSlotType(SlotType equipmentSlotType, SlotType paramSlotType);
  error EquipmentSystem_InvalidSlotType(SlotType paramSlotType);
  error EquipmentSystem_EquipmentSnapshotStatsNotFound(uint256 characterId, uint256 itemId, SlotType slotType);
  error EquipmentSystem_UnmatchEquipmentId(uint256 targetEquipmentId, uint256 materialEquipmentId);
  error EquipmentSystem_ExceedMaxLevel(uint8 maxLevel);

  /* -------------------------------------------------------------------------- */
  /*                                    Quest3                                   */
  /* -------------------------------------------------------------------------- */
  error QuestSystem_QuestNotFound(uint256 questId);
  error QuestSystem_AlreadyReceived(uint256 characterId, uint256 questId);
  error QuestSystem_NotSamePositionWithNpc(int32 characterX, int32 characterY, int32 npcX, int32 npcY);
  error QuestSystem_ReceiveFromWrongNpc(uint256 npcId, uint256 questId);
  error QuestSystem_RequiredQuestsAreNotDone(uint256 characterId, uint256 undoneQuestId);
  error QuestSystem_InvalidContributeQuest(uint256 lenResourceIds, uint256 lenAmounts);
  error QuestSystem_FinishWithWrongNpc(uint256 npcId, uint256 questId);
  error QuestSystem_MustFinishInProgressQuest(uint256 characterId, uint256 questId);
  error QuestSystem_InvalidSocialTypeOrAlreadyClaimed(uint256 characterId, SocialType socialType);
  error QuestSystem_InvalidLocateQuest(uint256 lenXs, uint256 lenYs);
  error QuestSystem_WrongLocation(int32 questX, int32 questY, int32 characterX, int32 characterY);
  error QuestSystem_InvalidRewardItemLength(uint256 questId, uint256 lenRewardItemIds, uint256 lenRewardAmounts);

  /* -------------------------------------------------------------------------- */
  /*                                LevelSystem                                 */
  /* -------------------------------------------------------------------------- */
  error LevelSystem_InvalidLevelAmount(uint16 amount);
  error LevelSystem_ExceedMaxLevel(uint16 maxLevel, uint16 toLevel);
  error LevelSystem_InsufficientExp(uint16 currentLevel, uint16 toLevel, uint32 requiredExp, uint32 currentExp);
  error LevelSystem_InvalidPerkLevelAmount(ItemType itemType, uint16 amount);
  error LevelSystem_ExceedMaxPerkLevel(uint16 maxLevel, uint16 toLevel);
  error LevelSystem_InsufficientPerkExp(uint16 currentLevel, uint16 toLevel, uint32 requiredExp, uint32 currentExp);

  /* -------------------------------------------------------------------------- */
  /*                                    Stats                                   */
  /* -------------------------------------------------------------------------- */
  error Stats_InvalidAmount(uint16 amount);
  error Stats_NotEnoughPoint(StatType statType, uint16 currentBaseStat, uint16 toBaseStat, uint16 statPoint);
  error Stats_InvalidStatType(StatType statType);
  error Stats_ExceedMaxBaseStat(StatType statType, uint16 maxBaseStat, uint16 toStat);

  /* -------------------------------------------------------------------------- */
  /*                                    Skill                                   */
  /* -------------------------------------------------------------------------- */
  error Skill_DuplicateSkillId(uint256 skillId);
  error Skill_NotExist(uint256 skillId);
  error Skill_PerkLevelIsNotEnough(uint256 characterId, uint8 currentPerkLevel, uint8 skillPerkLevel);
  error Skill_InvalidSkillData(uint256 skillId);

  /* -------------------------------------------------------------------------- */
  /*                                    Monster                                 */
  /* -------------------------------------------------------------------------- */
  error Monster_InvalidResourceData(uint256 monsterId, uint256 lenResourceIds, uint256 lenResourceAmounts);

  /* -------------------------------------------------------------------------- */
  /*                                    PvE                                     */
  /* -------------------------------------------------------------------------- */
  error PvE_MonsterIsNotExist(int32 x, int32 y, uint256 monsterId);
  error PvE_NotReadyToBattle(uint256 nextBattleTimestamp);
  error PvE_BossIsNotRespawnedYet(uint256 monsterId, uint256 respawnTime);
  error PvE_AfkNotStarted(uint256 characterId);
  error PvE_AfkAlreadyStarted(uint256 characterId, uint256 monsterId);
  error PvE_SomeoneIsFightingThisMonster(int32 x, int32 y, uint256 monsterId);
  error PvE_CannotAFKWithBoss(uint256 monsterId);
  error PvE_NotCapableToAFK(
    uint256 characterId, uint256 monsterId, int32 characterX, int32 characterY, uint16 monsterLevel
  );

  /* -------------------------------------------------------------------------- */
  /*                                    PvP                                     */
  /* -------------------------------------------------------------------------- */
  error PvP_NotReadyToAttack(uint256 nextAttackTime);
  error PvP_NotReadyToBeAttacked(uint256 nextTimeToBeAttacked);
  error PvP_NotSamePosition(int32 attackerX, int32 attackerY, int32 defenderX, int32 defenderY);
  error PvP_CannotBattleInCapitalCity();
  error PvP_CannotBattleInCity();

  /* -------------------------------------------------------------------------- */
  /*                                DropSystem                                  */
  /* -------------------------------------------------------------------------- */
  error DropSystem_ExceedResourceBalance(uint256 resourceId, uint32 currentAmount, uint32 dropAmount);

  /* -------------------------------------------------------------------------- */
  /*                             DailyQuestSystem                               */
  /* -------------------------------------------------------------------------- */
  error DailyQuestSystem_CannotRefreshAtCurrentTime(uint256 nextTimeToRefresh);
  error DailyQuestSystem_InvalidQuestTime(uint256 currentTime, uint256 questStartTime);
  error DailyQuestSystem_TasksAreNotDone();

  /* -------------------------------------------------------------------------- */
  /*                               CharFund                                */
  /* -------------------------------------------------------------------------- */
  error CharacterFund_NotEnoughGold(uint32 balance, uint32 requireAmount);
  error CharacterFund_NotEnoughCrystal(uint32 balance, uint32 requireAmount);

  /* -------------------------------------------------------------------------- */
  /*                               CraftSystem                                  */
  /* -------------------------------------------------------------------------- */
  error CraftSystem_MustInACity(uint256 characterId);
  error CraftSystem_NoRecipeForItem(uint256 itemId);
  error CraftSystem_CraftAmountIsZero();
  error CraftSystem_InvalidRecipeData(uint256 itemId);
  error CraftSystem_PerkLevelIsNotEnough(uint256 characterId, uint256 itemId);

  /* -------------------------------------------------------------------------- */
  /*                               ConsumeSystem                                */
  /* -------------------------------------------------------------------------- */
  error ConsumeSystem_ItemAmountIsZero(uint256 characterId, uint256 itemId);
  error ConsumeSystem_MustBeBerry(uint256 characterId, uint256 itemId);
  error ConsumeSystem_ItemIsNotConsumable(uint256 itemId);
  error ConsumeSystem_Overflow(uint256 characterId, uint256 gainedHp);
  error ConsumeSystem_BuffItemAmountMustBeOne(uint256 characterId, uint256 itemId, uint32 amount);
  error ConsumeSystem_OutOfRange(int32 charX, int32 charY, int32 targetX, int32 targetY, uint256 itemId);
  error ConsumeSystem_ItemIsNotSkillItem(uint256 itemId);
  error ConsumeSystem_TargetNotInPosition(uint256 targetPlayer, int32 targetX, int32 targetY);
  error ConsumeSystem_TooManyTargets(uint256 numInput, uint8 allowedNumTarget);
  error ConsumeSystem_CannotTargetRestrictLocation();
  error ConsumeSystem_DuplicateTarget();

  /* -------------------------------------------------------------------------- */
  /*                               StorageSystem                                */
  /* -------------------------------------------------------------------------- */
  error StorageSystem_ExceedCharacterResourceBalance(uint256 resourceId, uint32 currentAmount, uint32 moveAmount);

  /* -------------------------------------------------------------------------- */
  /*                               Storage                                      */
  /* -------------------------------------------------------------------------- */
  error Storage_ExceedMaxWeight(uint32 maxWeight, uint32 currentWeight);
  error Storage_ExceedResourceBalance(
    uint256 characterId, uint256 cityId, uint256 resourceId, uint32 currentAmount, uint32 requireAmount
  );
  error Storage_ExceedItemBalance(
    uint256 characterId, uint256 cityId, uint256 itemId, uint32 currentAmount, uint32 requireAmount
  );

  /* -------------------------------------------------------------------------- */
  /*                               Inventory                                    */
  /* -------------------------------------------------------------------------- */
  error Inventory_ExceedItemBalance(uint256 characterId, uint256 itemId, uint32 currentAmount, uint32 requireAmount);

  /* -------------------------------------------------------------------------- */
  /*                               NpcShopSystem                                */
  /* -------------------------------------------------------------------------- */
  error NpcShopSystem_OnlySellTierOneTool(uint256 itemId);
  error NpcShopSystem_NotEnoughGold(uint256 cityId, uint32 npcBalance, uint32 cost);
  error NpcShopSystem_ItemTierTooLow(uint256 cityId, uint256 itemId, uint32 npcBalance);
  error NpcShopSystem_ExceedItemBalanceCap(uint256 cityId, uint256 itemId, uint32 npcItemBalance, uint32 sellAmount);
  error NpcShopSystem_NotEnoughItem(uint256 cityId, uint256 itemId, uint32 currentAmount);
  error NpcShopSystem_OnlyAcceptOtherItem(uint256 itemId);
  error NpcShopSystem_CardDataMismatch(uint256 cityId);
  error NpcShopSystem_CardIndexOutOfBounds(uint256 cityId, uint256 cardIndex);
  error NpcShopSystem_ExceedCardAmount(uint256 cityId, uint256 cardId, uint8 amount);

  /* -------------------------------------------------------------------------- */
  /*                               ChatSystem                                */
  /* -------------------------------------------------------------------------- */
  error ChatSystem_InvalidMessage();

  /* -------------------------------------------------------------------------- */
  /*                               TileSystem                                   */
  /* -------------------------------------------------------------------------- */
  error TileSystem_TileIsLocked(int32 x, int32 y, uint256 occupiedTime);
  error TileSystem_NoValidTileNearBy(int32 x, int32 y);
  error TileSystem_ItemNotFound(int32 x, int32 y, uint256 itemIndex);
  error TileSystem_EquipmentNotFound(int32 x, int32 y, uint256 equipmentIndex);
  error TileSystem_ExceedItemBalance(int32 x, int32 y, uint256 itemId, uint32 currentAmount, uint32 requireAmount);
  error TileSystem_NoItemInThisTile(int32 x, int32 y, uint256 lastDropTime);
  error TileSystem_TileAlreadyOccupied(int32 x, int32 y);
  error TileSystem_TileIsNotReadyToOccupy(int32 x, int32 y, uint256 arrivalTime);
  error TileSystem_CannotOccupyThisTile(int32 x, int32 y);

  /* -------------------------------------------------------------------------- */
  /*                               RebornSystem                                 */
  /* -------------------------------------------------------------------------- */
  error RebornSystem_MustBeMaxLevel(uint256 characterId);

  /* -------------------------------------------------------------------------- */
  /*                               MarketSystem                                 */
  /* -------------------------------------------------------------------------- */
  error MarketSystem_FameTooLow(uint256 characterId, uint32 fame);
  error MarketSystem_ZeroPrice();
  error MarketSystem_ZeroAmount();
  error MarketSystem_TakerOrderZeroAmount();
  error MarketSystem_ZeroItemId();
  error MarketSystem_ExceedMaxWeight(uint256 characterId, uint256 cityId, uint32 totalWeight, uint32 maxWeight);
  error MarketSystem_InsufficientGold(uint256 characterId, uint32 charGold, uint32 requiredGold);
  error MarketSystem_InsufficientItem(uint256 characterId, uint256 itemId, uint32 requiredAmount);
  error MarketSystem_SellEquipmentOrderAmount(uint32 amount);
  error MarketSystem_CharacterNotOwner(uint256 characterId, uint256 orderId);
  error MarketSystem_CityNotMatch(uint256 existingOrderCityId, uint256 orderId);
  error MarketSystem_ExceedMaxPrice(uint32 orderPrice);
  error MarketSystem_OrderAlreadyDone(uint256 orderId);
  error MarketSystem_InvalidTakerOrderEquipmentData(uint256 orderId, uint32 amount, uint256 lenEquipmentIds);
  error MarketSystem_InvalidOfferEquipment(uint256 orderId, uint256 itemId, uint256 offerEquipmentId);
  error MarketSystem_InvalidTakerAmount(uint256 orderId, uint32 maxAmount, uint32 takeAmount);
  error MarketSystem_InvalidItemType(uint256 itemId);
  error MarketSystem_OrderIsNotExist(uint256 orderId);

  /* -------------------------------------------------------------------------- */
  /*                               KingSystem                                   */
  /* -------------------------------------------------------------------------- */
  error KingSystem_InsufficientFameForKingElection(uint256 characterId, uint32 fame);
  error KingSystem_NotInElectionTime();
  error KingSystem_AlreadyRegistered(uint256 characterId);
  error KingSystem_NotRegistered(uint256 characterId);
  error KingSystem_CannotVoteForSelf(uint256 characterId);
  error KingSystem_ElectionPeriodNotOverYet();
  error KingSystem_InsufficientFameForVoting(uint256 characterId, uint32 fame);
  error KingSystem_AlreadyVoted(uint256 characterId);
  error KingSystem_InvalidCandidate(uint256 candidateId);
  error KingSystem_NotKing(uint256 characterId);
  error KingSystem_InvalidKingdomId(uint8 kingdomId);
  error KingSystem_InvalidMarketFee(uint8 fee);
  error KingSystem_InvalidFamePenalty(uint8 famePenalty);
  error KingSystem_NotOwnTile(uint8 kingdomId, int32 x, int32 y);
  error KingSystem_InvalidCityLocation(int32 x, int32 y);
  error KingSystem_InvalidCityName(string name);
  error KingSystem_ExceedMaxNumCity(uint8 kingdomId);
  error KingSystem_NotCitizenOfKingdom(uint256 citizenId, uint8 kingdomId);
  error KingSystem_InvalidRole(RoleType roleType);
  error KingSystem_RoleLimitReached(RoleType roleType, uint32 maxLimit);
  error KingSystem_CannotSetRoleForKing();
  error KingSystem_InsufficientLevelForRole(uint256 characterId, uint16 level, RoleType roleType);
  error KingSystem_CannotMoveCapitalCity();
  error KingSystem_CityNotInYourKingdom(uint256 cityId, uint8 kingdomId);
  error KingSystem_CityMoveOnCooldown(uint256 cityId);
  error KingSystem_InsufficientCityGold(uint256 cityId, uint32 requiredGold);

  /* -------------------------------------------------------------------------- */
  /*                               VaultSystem                                  */
  /* -------------------------------------------------------------------------- */
  error VaultSystem_MustBeVaultKeeper(uint256 characterId);
  error VaultSystem_CharacterNotInSameKingdom(uint256 characterId, uint256 cityId);
  error VaultSystem_InvalidParamsLen(uint256 lenItemId, uint256 lenAmount);
  error VaultSystem_InvalidParamsValue(uint256 itemId, uint32 amount);
  error VaultSystem_FameTooLow(uint256 characterId, uint32 fame);
  error VaultSystem_InsufficientVaultAmount(
    uint256 cityId, uint256 itemId, uint32 currentVaultAmount, uint32 withdrawAmount
  );

  /* -------------------------------------------------------------------------- */
  /*                               CitySystem                                   */
  /* -------------------------------------------------------------------------- */
  error CitySystem_AlreadyMaxLevel(uint256 cityId);
  error CitySystem_CityIsNotYourKingdom(uint8 charKingdomId, uint8 cityKingdomId);
  error CitySystem_InvalidResourceRequire(uint256 lenResourceIds, uint256 lenAmounts);
  error CitySystem_InsufficientVaultAmount(
    uint256 cityId, uint256 itemId, uint32 currentVaultAmount, uint32 withdrawAmount
  );
  error CitySystem_InsufficientVaultGold(uint256 cityId, uint32 currentGold, uint32 vaultGold);
  error CitySystem_CityLevelTooLow(uint256 cityId, uint8 cityLevel);
}
