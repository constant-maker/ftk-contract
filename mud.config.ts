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
import CITY_TABLES from "./tables/cityTables";
import ROLE_TABLES from "./tables/roleTables";
import STATUS_TABLES from "./tables/statusTables";
import GUILD_TABLES from "./tables/guildTables";
import GACHA_TABLES from "./tables/gachaTables";

export default defineWorld({
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "app",
  enums: {
    CharacterStateType: ["Standby", "Farming", "Moving", "Hunting"],
    ResourceType: ["Wood", "Stone", "Fish", "Ore", "Wheat", "Berry", "MonsterLoot"],
    ItemType: [
      "WoodAxe", "StoneHammer", "FishingRod", "Pickaxe", "Sickle", "BerryShears",
      "Sword", "Axe", "Spear", "Bow", "Staff", "Dagger", "Shield",
      "ClothArmor", "ClothHeadgear", "ClothFootwear",
      "LeatherArmor", "LeatherHeadgear", "LeatherFootwear",
      "PlateArmor", "PlateHeadgear", "PlateFootwear",
      "Mount", "Resource", "SkillItem", "HealingItem", "StatModifierItem",
      "Card", "BuffItem", "Pet"
    ],
    ItemCategoryType: ["Tool", "Equipment", "Other"],
    CharacterType: ["Male", "Female"],
    StatType: ["ATK", "DEF", "AGI"],
    SlotType: [
      "Weapon", "SubWeapon", "Armor", "Headgear", "Footwear", "Mount", "Pet"
    ],
    SkinSlotType: [
      "Weapon", "SubWeapon", "Armor", "Headgear", "Footwear", "Mount", "Pet", "Aura", "Ring"
    ],
    QuestType: ["Contribute", "Locate"],
    QuestStatusType: ["NotReceived", "InProgress", "Done"],
    SocialType: ["Twitter", "Telegram", "Discord"],
    ZoneType: ["Green", "Orange", "Red", "Black"],
    TerrainType: ["GrassLand", "Forest", "Mountain"],
    AdvantageType: ["Red", "Green", "Blue", "Grey"],
    EntityType: ["Character", "Monster"],
    EffectType: ["None", "Burn", "Poison", "Frostbite", "Stun"],
    RoleType: ["None", "VaultKeeper", "KingGuard"],
    // Note: Healing potion represents for ItemType HealingItem
    // To save gas, limit contract size purpose only
    BuffType: ["None", "StatsModify", "ExpAmplify", "InstantDamage", "InstantHeal", "HealingPotion"],
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
    ...CITY_TABLES,
    ...ROLE_TABLES,
    ...STATUS_TABLES,
    ...GUILD_TABLES,
    ...GACHA_TABLES,
  },
  excludeSystems: ["SpawnSystem", "GachaSystem"], // registered as root systems
});
