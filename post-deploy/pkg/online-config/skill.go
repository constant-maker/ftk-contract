package onlineconfig

import (
	"io"
	"strconv"
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

const (
	listSkillUpdate = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=1359260272#gid=1359260272"
)

func getListSkillUpdate(dataConfig *common.DataConfig) ([]common.Skill, error) {
	l := zap.S().With("func", "getListSkillUpdate")
	reader, err := getRawCsvReader(listSkillUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	skills := make([]common.Skill, 0)
	var (
		idIndex, perkIndex, perkLevelIndex, typeIndex,
		nameIndex, mainDamageIndex, dmgPerTurnIndex, turnActiveIndex,
		spIndex, descIndex int
	)
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		} else if err != nil {
			l.Errorw("cannot read data", "err", err)
			return nil, err
		}
		if record[0] == "END" {
			break
		}
		if record[0] == "" && record[4] == "" { // empty row
			// l.Warnw("invalid skill data format", "data", record)
			continue
		}

		if strings.EqualFold(record[0], "Id") { // header
			if typeIndex != 0 && nameIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			idIndex = findIndex(record, "id")
			perkIndex = findIndex(record, "perk")
			perkLevelIndex = findIndex(record, "perk_lvl")
			typeIndex = findIndex(record, "type")
			nameIndex = findIndex(record, "name")
			mainDamageIndex = findIndex(record, "main_damage")
			dmgPerTurnIndex = findIndex(record, "damage_per_turn")
			turnActiveIndex = findIndex(record, "turns_active")
			spIndex = findIndex(record, "sp")
			descIndex = findIndex(record, "desc")
			continue
		}

		if _, err := strconv.Atoi(record[0]); err != nil {
			// this may be the note in docs
			continue
		}

		id := mustStringToInt(record[idIndex], idIndex)
		perkItemTypes := getPerkItemTypes(dataConfig, record[perkIndex])
		perkLevels := getPerkLevels(record[perkLevelIndex])
		skillEffectType := getSkillEffectType(record[typeIndex])
		mainDamage := mustStringToInt(record[mainDamageIndex], mainDamageIndex)
		dmgPerTurn := mustStringToInt(record[dmgPerTurnIndex], dmgPerTurnIndex)
		turnActive := mustStringToInt(record[turnActiveIndex], turnActiveIndex)
		sp := mustStringToInt(record[spIndex], spIndex)
		hasEffect := false
		if turnActive > 0 {
			hasEffect = true
		}
		skill := common.Skill{
			Id:                 id,
			Name:               removeRedundantText(record[nameIndex]),
			Desc:               removeRedundantText(record[descIndex]),
			Damage:             mainDamage,
			Sp:                 sp,
			PerkItemTypes:      perkItemTypes,
			RequiredPerkLevels: perkLevels,
			HasEffect:          hasEffect,
		}
		if hasEffect {
			skill.Effect = &common.SkillEffect{
				Damage:     dmgPerTurn,
				EffectType: uint8(skillEffectType),
				Turns:      turnActive,
			}
		}
		skills = append(skills, skill)
	}
	return skills, nil
}
