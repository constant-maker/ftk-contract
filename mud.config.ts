import { defineWorld } from "@latticexyz/world";
import CHARACTER_TABLES from "./tables/characterTables";
import MAP_TABLES from "./tables/mapTables";
import CONFIG_TABLES from "./tables/configTables";
import INDEXING_TABLES from "./tables/indexingTables";
import ITEM_TABLES from "./tables/itemTables";
import WELCOME_PACKAGE_TABLES from "./tables/welcomePackageTables";
import CRAFT_TABLES from "./tables/craftTables";
import QUEST_TABLES from "./tables/questTables";
import SKILL_TABLES from "./tables/skillTables";
import BATTLE_TABLES from "./tables/battleTables";
import MONSTER_TABLES from "./tables/monsterTables";
import CONSUMABLE_INFO_TABLES from "./tables/consumableInfoTables";
import ACHIEVEMENT_TABLES from "./tables/achievementTables";
import SOCIAL_TABLES from "./tables/socialTables";
import MARKET_TABLES from "./tables/marketTables";
import KING_TABLES from "./tables/kingTables";

export default defineWorld({
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "app",
  enums: {
    CharacterStateType: ["Standby", "Farming", "Moving"],
    ResourceType: ["Wood", "Stone", "Fish", "Ore", "Wheat", "Berry", "MonsterLoot"],
    ItemType: [
      "WoodAxe", "StoneHammer", "FishingRod", "Pickaxe", "Sickle", "BerryShears",
      "Sword", "Axe", "Spear", "Bow", "Staff", "Dagger", "Shield",
      "ClothArmor", "ClothHeadgear", "ClothFootwear",
      "LeatherArmor", "LeatherHeadgear", "LeatherFootwear",
      "PlateArmor", "PlateHeadgear", "PlateFootwear",
      "Mount", "Resource", "MapSkillItem", "HealingItem", "StatModifierItem",
      "Card"
    ],
    ItemCategoryType: ["Tool", "Equipment", "Other"],
    CharacterType: ["Male", "Female"],
    StatType: ["ATK", "DEF", "AGI"],
    SlotType: [
      "Weapon", "SubWeapon", "Armor", "Headgear", "Footwear", "Mount"
    ],
    QuestType: ["Contribute", "Locate"],
    QuestStatusType: ["NotReceived", "InProgress", "Done"],
    SocialType: ["Twitter", "Telegram", "Discord"],
    ZoneType: ["Green, Orange, Red, Black"],
    TerrainType: ["GrassLand", "Forest", "Mountain"],
    AdvantageType: ["Red", "Green", "Blue", "Grey"],
    EntityType: ["Character", "Monster"],
    EffectType: ["None", "Burn", "Poison", "Frostbite", "Stun"],
  },
  tables: {
    Unmovable: {
      schema: {
        x: "int32",
        y: "int32",
        value: "bool",
      },
      key: ['x', 'y'],
    },
    ...CONFIG_TABLES,
    ...INDEXING_TABLES,
    ...MAP_TABLES,
    ...WELCOME_PACKAGE_TABLES,
    ...CHARACTER_TABLES,
    ...ITEM_TABLES,
    ...CONSUMABLE_INFO_TABLES,
    ...CRAFT_TABLES,
    ...QUEST_TABLES,
    ...SKILL_TABLES,
    ...BATTLE_TABLES,
    ...MONSTER_TABLES,
    ...ACHIEVEMENT_TABLES,
    ...SOCIAL_TABLES,
    ...MARKET_TABLES,
    ...KING_TABLES,
  },
  excludeSystems: ["SpawnSystem"],
});
