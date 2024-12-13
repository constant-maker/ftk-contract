pragma solidity >=0.8.24;

import { CharacterStateType, ResourceType, ItemType, SlotType, StatType, SocialType } from "../codegen/common.sol";

library Errors {
  // common errors
  error InvalidCityId(uint256 cityId);
  error MustInACity(uint256 cityId, int32 charX, int32 charY);

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
  error Character_MustInState(CharacterStateType characterState);
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
  error Tool_InsufficientDurability();
  error Tool_AlreadyHad(uint256 characterId, uint256 toolId);

  /* -------------------------------------------------------------------------- */
  /*                              Equipment                                     */
  /* -------------------------------------------------------------------------- */
  error Equipment_NotOwned(uint256 characterId, uint256 equipmentId);
  error Equipment_AlreadyHad(uint256 characterId, uint256 equipmentId);
  error Equipment_NotExisted(uint256 equipmentId);

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

  /* -------------------------------------------------------------------------- */
  /*                                    Quest2                                   */
  /* -------------------------------------------------------------------------- */
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

  /* -------------------------------------------------------------------------- */
  /*                                    PvP                                     */
  /* -------------------------------------------------------------------------- */
  error PvP_NotReadyToAttack(uint256 nextAttackTime);
  error PvP_NotReadyToBeAttacked(uint256 nextTimeToBeAttacked);
  error PvP_NotSamePosition(int32 attackerX, int32 attackerY, int32 defenderX, int32 defenderY);

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

  /* -------------------------------------------------------------------------- */
  /*                               ConsumeSystem                                */
  /* -------------------------------------------------------------------------- */
  error ConsumeSystem_ItemAmountIsZero(uint256 characterId, uint256 itemId);
  error ConsumeSystem_MustBeBerry(uint256 characterId, uint256 itemId);
  error ConsumeSystem_ItemIsNotConsumable(uint256 characterId, uint256 itemId);

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
  error NpcShopSystem_NotEnoughItem(uint256 cityId, uint256 itemId, uint32 currentAmount);
  error NpcShopSystem_OnlyAcceptOtherItem(uint256 itemId);

  /* -------------------------------------------------------------------------- */
  /*                               ChatSystem                                */
  /* -------------------------------------------------------------------------- */
  error ChatSystem_InvalidMessage();

  /* -------------------------------------------------------------------------- */
  /*                               TileSystem                                   */
  /* -------------------------------------------------------------------------- */
  error TileSystem_TileIsLocked(int32 x, int32 y, uint256 occupiedTime);
  error TileSystem_NoValidTileNearBy(int32 x, int32 y);
}
