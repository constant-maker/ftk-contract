package common

type Achievement struct {
	Id    int              `json:"id"`
	Name  string           `json:"name"`
	Stats AchievementStats `json:"stats"`
}

type AchievementStats struct {
	Atk int `json:"atk"`
	Def int `json:"def"`
	Agi int `json:"agi"`
}

type Item struct {
	Id            int            `json:"id"`
	Type          int            `json:"type"`
	Category      int            `json:"category"`
	Tier          int            `json:"tier"`
	OldWeight     int            `json:"oldWeight,omitempty"`
	Weight        int            `json:"weight"`
	Name          string         `json:"name"`
	Desc          string         `json:"desc"`
	ResourceInfo  *ResourceInfo  `json:"resourceInfo,omitempty"`
	EquipmentInfo *EquipmentInfo `json:"equipmentInfo,omitempty"`
	HealingInfo   *HealingInfo   `json:"healingInfo,omitempty"`
	CardInfo      *CardInfo      `json:"cardInfo,omitempty"`
}

type CardInfo struct {
	Top    int `json:"top"`
	Bottom int `json:"bottom"`
	Left   int `json:"left"`
	Right  int `json:"right"`
}

type EquipmentInfo struct {
	SlotType      int  `json:"slotType"`
	AdvantageType int  `json:"advantageType"`
	TwoHanded     bool `json:"twoHanded"`
	Atk           int  `json:"atk"`
	Def           int  `json:"def"`
	Agi           int  `json:"agi"`
	Hp            int  `json:"hp"`
	Ms            int  `json:"ms"`
	BonusWeight   int  `json:"weight"`
	ShieldBarrier int  `json:"barrier"`
}

type HealingInfo struct {
	HpRestore uint16 `json:"hpRestore"`
}

type ResourceInfo struct {
	ResourceType int `json:"type"`
}

type WelcomeConfig struct {
	ItemIds []int `json:"itemIds"`
}

type CharacterQuestion struct {
	Question string            `json:"question"`
	Answers  []CharacterAnswer `json:"answers"`
}

type CharacterAnswer struct {
	Label string               `json:"label"`
	Value int                  `json:"value"`
	Bonus CharacterAnswerBonus `json:"bonus"`
}

type CharacterAnswerBonus struct {
	Atk int `json:"ATK"`
	Def int `json:"DEF"`
	Agi int `json:"AGI"`
}

type City struct {
	Id        int    `json:"id"`
	X         int32  `json:"x"`
	Y         int32  `json:"y"`
	KingdomId uint8  `json:"kingdomId"`
	Name      string `json:"name"`
	IsCapital bool   `json:"isCapital"`
	Level     uint8  `json:"level"`
}

type Kingdom struct {
	Id              uint8          `json:"id"`
	Name            string         `json:"name"`
	SubTitle        string         `json:"subTitle"`
	Desc            string         `json:"desc"`
	MainResources   []ResourceType `json:"mainResources"`
	Color           string         `json:"color"`
	CapitalId       int            `json:"capitalId"`
	CapitalName     string         `json:"capitalName"`
	CapitalPosition Location       `json:"capitalPosition"`
}

type Location struct {
	X int32 `json:"x"`
	Y int32 `json:"y"`
}

type ResourceLocation struct {
	Locations    []Location `json:"locations"`
	ResourceId   int        `json:"resourceId"`
	TotalAmount  int        `json:"totalAmount"`
	Participants int        `json:"participants"`
}

type Ingredient struct {
	ItemId int `json:"itemId"`
	Amount int `json:"amount"`
}

type ItemRecipe struct {
	ItemId             int          `json:"itemId"`
	PerkItemTypes      []int        `json:"perkTypes,omitempty"`
	RequiredPerkLevels []int        `json:"perkLevels,omitempty"`
	Ingredients        []Ingredient `json:"ingredients"`
	GoldCost           int          `json:"goldCost"`
}

type Npc struct {
	Id     int64     `json:"id"`
	CityId int64     `json:"cityId"`
	X      int32     `json:"x"`
	Y      int32     `json:"y"`
	Name   string    `json:"name"`
	Cards  []NpcCard `json:"cards"`
}

type NpcCard struct {
	Id     int64 `json:"id"`
	Amount int64 `json:"amount"`
}

type QuestType string

const (
	QuestContribute QuestType = "Contribute"
	QuestLocate     QuestType = "Locate"
)

type Quest3 struct {
	Id                   int64              `json:"id"`
	QuestType            int                `json:"questType"`
	Name                 string             `json:"name"`
	Description          string             `json:"description"`
	FromNpcId            int64              `json:"fromNpcId"`
	ToNpcId              int64              `json:"toNpcId"`
	Exp                  uint32             `json:"exp"`
	Gold                 uint32             `json:"gold"`
	RequiredDoneQuestIds []int64            `json:"requiredDoneQuestIds"`
	ContributeDetails    []ContributeDetail `json:"contributeDetails"`
	LocateDetails        []Location         `json:"locateDetails"`
	AchievementId        int64              `json:"achievementId"`
	RewardItemIds        []int64            `json:"rewardItemIds"`
	RewardItemAmounts    []uint32           `json:"rewardItemAmounts"`
}

type ContributeDetail struct {
	ItemId int64  `json:"itemId"`
	Amount uint32 `json:"amount"`
}

type TileInfo struct {
	KingdomId       uint8   `json:"kingdomId"`
	X               int32   `json:"x"`
	Y               int32   `json:"y"`
	FarmSlot        uint8   `json:"farmSlot"`
	ZoneType        uint8   `json:"zoneType"`
	ResourceItemIds []int64 `json:"itemIds"`
}

type Skill struct {
	Id                 int          `json:"id"`
	Name               string       `json:"name"`
	Desc               string       `json:"desc"`
	Damage             int          `json:"damage"` // percent
	Sp                 int          `json:"sp"`
	PerkItemTypes      []int        `json:"perkItemTypes"`
	RequiredPerkLevels []int        `json:"requiredPerkLevels"`
	HasEffect          bool         `json:"hasEffect"`
	Effect             *SkillEffect `json:"effect,omitempty"`
}

type SkillEffect struct {
	Damage     int   `json:"damage"` // percent
	EffectType uint8 `json:"effectType"`
	Turns      int   `json:"turns"`
}

type Monster struct {
	Id          int          `json:"id"`
	Name        string       `json:"name"`
	Desc        string       `json:"desc"`
	Kingdom     int          `json:"kingdom"`
	Tier        int          `json:"tier"`
	IsBoss      bool         `json:"isBoss"`
	Levels      [2]int       `json:"levels"`
	Grow        int          `json:"grow"` // percent
	SkillIds    []int        `json:"skillIds"`
	ItemIds     []int        `json:"itemIds"`
	ItemAmounts []int        `json:"itemAmounts"`
	Exp         int          `json:"exp"`
	PerkExp     int          `json:"perkExp"`
	Stats       MonsterStats `json:"stats"`
	BossInfo    *BossInfo    `json:"bossInfo"`
}

type BossInfo struct {
	Barrier            int `json:"barrier"`
	Hp                 int `json:"hp"`
	Crystal            int `json:"crystal"`
	RespawnDuration    int `json:"respawnDuration"`
	BerserkHpThreshold int `json:"berserkHpThreshold"`
	BoostPercent       int `json:"boostPercent"`
	LastDefeatedTime   int `json:"lastDefeatedTime"`
}

type MonsterStats struct {
	Hp  int `json:"hp"`
	Atk int `json:"atk"`
	Def int `json:"def"`
	Agi int `json:"agi"`
	Sp  int `json:"sp"`
}

type MonsterLocation struct {
	Locations     []Location `json:"locations"`
	MonsterId     int        `json:"monsterId"`
	Level         int        `json:"level"`
	AdvantageType int        `json:"advantageType"`
}

type MonsterLocationDetail struct {
	MonsterId     int `json:"monsterId"`
	Level         int `json:"level"`
	AdvantageType int `json:"advantageType"`
}

type ResourceType string
type ItemType string
type EquipmentSlotType string
type CharacterStateType string
type ItemCategoryType string

const (
	ItemCategoryTool       ItemCategoryType = "Tool"
	ItemCategoryEquipment  ItemCategoryType = "Equipment"
	ItemCategoryConsumable ItemCategoryType = "Consumable"
)

type ZoneType string

const (
	ZoneTypeGreen  = "Green"
	ZoneTypeOrange = "Orange"
	ZoneTypeRed    = "Red"
	ZoneTypeBlack  = "Black"
)

type TerrainType string
type AdvantageType string

type DailyQuestConfig struct {
	MoveNum    uint8  `json:"moveNum"`
	FarmNum    uint8  `json:"farmNum"`
	PvpNum     uint8  `json:"pvpNum"`
	PveNum     uint8  `json:"pveNum"`
	RewardExp  uint32 `json:"rewardExp"`
	RewardGold uint32 `json:"rewardGold"`
}

type RarityType string

type DataConfig struct {
	Achievements             map[string]Achievement `json:"achievements"` // map id => Achievement
	Items                    map[string]Item        `json:"items"`        // map itemId => Item
	WelcomeConfig            WelcomeConfig          `json:"welcomeConfig"`
	CharacterQuestions       []CharacterQuestion    `json:"characterQuestions"`
	Cities                   map[string]City        `json:"cities"`
	Kingdoms                 map[string]Kingdom     `json:"kingdoms"`
	Npcs                     map[string]Npc         `json:"npcs"`
	TileInfos                []TileInfo             `json:"tileInfos"`
	ItemRecipes              map[string]ItemRecipe  `json:"itemRecipes"`
	DailyQuestConfig         DailyQuestConfig       `json:"dailyQuestConfig"`
	Quests                   map[string]Quest3      `json:"quests"`
	Skills                   map[string]Skill       `json:"skills"`
	Monsters                 map[string]Monster     `json:"monsters"`
	MonsterLocationsCache    []MonsterLocation      `json:"monsterLocationsCache"`
	MonsterLocationsOverride []MonsterLocation      `json:"monsterLocationsOverride"`
	MonsterLocationsBoss     []MonsterLocation      `json:"monsterLocationsBoss"`

	// enum type
	ResourceTypes      map[ResourceType]int       `json:"resourceTypes"`      // enums
	ItemTypes          map[ItemType]int           `json:"itemTypes"`          // enums
	ItemCategoryTypes  map[ItemCategoryType]int   `json:"itemCategoryTypes"`  // enums
	EquipmentSlotTypes map[EquipmentSlotType]int  `json:"equipmentSlotTypes"` // enums
	CharacterStates    map[CharacterStateType]int `json:"characterStates"`    // enums
	QuestTypes         map[QuestType]int          `json:"questTypes"`         // enums
	ZoneTypes          map[ZoneType]int           `json:"zoneTypes"`          // enums
	TerrainTypes       map[TerrainType]int        `json:"terrainTypes"`       // enums
	AdvantageTypes     map[AdvantageType]int      `json:"advantageType"`      // enums
	RarityTypes        map[RarityType]int         `json:"rarityType"`         // enums
}

var (
	MapResourceTypes       = make(map[int]ResourceType)
	MapItemTypes           = make(map[int]ItemType)
	MapEquipmentSlotTypes  = make(map[int]EquipmentSlotType)
	MapCharacterStateTypes = make(map[int]CharacterStateType)
	MapItemCategoryTypes   = make(map[int]ItemCategoryType)
	MapCharacterStates     = make(map[int]CharacterStateType)
	MapQuestTypes          = make(map[int]QuestType)
	MapZoneTypes           = make(map[int]ZoneType)
	MapTerrainTypes        = make(map[int]TerrainType)
	MapAdvantageTypes      = make(map[int]AdvantageType)
	MapRarityTypes         = make(map[int]RarityType)
)

type MapColor struct {
	FullMap [4]Location            `json:"full_map"`
	Black   [4]Location            `json:"black"`
	Greens  map[string][4]Location `json:"greens"`
}
