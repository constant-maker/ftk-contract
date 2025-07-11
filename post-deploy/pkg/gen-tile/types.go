package gentile

import "github.com/ftk/post-deploy/pkg/common"

type Distribution struct {
	Total        int64              `json:"total"`
	Type         string             `json:"type"` // no use
	RawResources map[string]float64 `json:"resources"`
	Resources    map[int]float64    `json:"_"`
}

type Zone struct {
	Type          common.ZoneType    `json:"type"`
	Locations     [4]common.Location `json:"locations"` // top left, top right, bottom right, bottom left
	MonsterIds    []int              `json:"monsterIds"`
	Distributions []Distribution     `json:"resourceDistributions"`
}

type KingdomMap struct {
	Name       string                 `json:"name"` // no use
	ID         int                    `json:"id"`
	Zones      [][4]common.Location   `json:"zones"`
	Resources  [6]common.ResourceType `json:"resources"`
	MonsterIds []int                  `json:"monsterIds"`
}
