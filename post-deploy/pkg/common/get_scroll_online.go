package common

import (
	"io"
	"strings"

	"go.uber.org/zap"
)

const (
	listScrollUpdate = "https://docs.google.com/spreadsheets/d/1re4m7CvzE2UYzBCgIgM4mTCNzWE0Yf1g66IfzbSk-xY/export?format=csv&gid=54253469#gid=54253469"
)

func getListScrollUpdate(dataConfig DataConfig) ([]Item, []ItemRecipe, error) {
	l := zap.S().With("func", "getListScrollUpdate")
	reader, err := getRawCsvReader(listScrollUpdate)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, nil, err
	}
	scrolls := make([]Item, 0)
	recipes := make([]ItemRecipe, 0)
	var (
		idIndex, nameIndex, tierIndex, scrollTypeIndex, rangeIndex, durationIndex, numTargetIndex, isBuffIndex, selfCastOnlyIndex, atkPercentIndex,
		defPercentIndex, agiPercentIndex, msIndex, spIndex, farmingPerkAmpIndex, pveExpAmpIndex, // pvePerkAmpIndex,
		dmgIndex, isAbsDmgIndex, goldCostIndex, weightIndex, recipeIndex, descIndex int
	)
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		} else if err != nil {
			l.Errorw("cannot read data", "err", err)
			return nil, nil, err
		}
		if record[0] == "" || record[1] == "" || record[2] == "" { // empty row
			l.Warnw("invalid equipment data format", "data", record)
			continue
		}
		// l.Infow("record", "value", record)
		if strings.EqualFold(record[0], "id") { // header
			if tierIndex != 0 && nameIndex != 0 {
				l.Panicw("detect header more than one time", "value", record)
			}
			idIndex = findIndex(record, "id")
			nameIndex = findIndex(record, "name")
			tierIndex = findIndex(record, "tier")
			scrollTypeIndex = findIndex(record, "type")
			rangeIndex = findIndex(record, "range")
			durationIndex = findIndex(record, "duration")
			numTargetIndex = findIndex(record, "numTarget")
			isBuffIndex = findIndex(record, "isBuff")
			selfCastOnlyIndex = findIndex(record, "selfCastOnly")
			atkPercentIndex = findIndex(record, "atkPercent")
			defPercentIndex = findIndex(record, "defPercent")
			agiPercentIndex = findIndex(record, "agiPercent")
			msIndex = findIndex(record, "ms")
			spIndex = findIndex(record, "sp")
			farmingPerkAmpIndex = findIndex(record, "farmingPerkAmp")
			pveExpAmpIndex = findIndex(record, "pveExpAmp")
			// pvePerkAmpIndex = findIndex(record, "pvePerkAmp")
			dmgIndex = findIndex(record, "dmg")
			isAbsDmgIndex = findIndex(record, "isAbsDmg")
			goldCostIndex = findIndex(record, "goldCost")
			weightIndex = findIndex(record, "weight")
			recipeIndex = findIndex(record, "recipe")
			descIndex = findIndex(record, "desc")

			l.Infow(
				"list index",
				"idIndex", idIndex,
				"nameIndex", nameIndex,
				"tierIndex", tierIndex,
				"scrollTypeIndex", scrollTypeIndex,
				"rangeIndex", rangeIndex,
				"durationIndex", durationIndex,
				"numTargetIndex", numTargetIndex,
				"isBuffIndex", isBuffIndex,
				"selfCastOnlyIndex", selfCastOnlyIndex,
				"atkPercentIndex", atkPercentIndex,
				"defPercentIndex", defPercentIndex,
				"agiPercentIndex", agiPercentIndex,
				"msIndex", msIndex,
				"spIndex", spIndex,
				"farmingPerkAmpIndex", farmingPerkAmpIndex,
				"pveExpAmpIndex", pveExpAmpIndex,
				// "pvePerkAmpIndex", pvePerkAmpIndex,
				"dmgIndex", dmgIndex,
				"isAbsDmgIndex", isAbsDmgIndex,
				"goldCostIndex", goldCostIndex,
				"weightIndex", weightIndex,
				"recipeIndex", recipeIndex,
				"descIndex", descIndex,
			)
			continue
		}

		id := mustStringToInt(record[idIndex], idIndex)
		tier := mustStringToInt(record[tierIndex], tierIndex)
		scrollType := mustStringToInt(record[scrollTypeIndex], scrollTypeIndex)
		weight := mustStringToInt(record[weightIndex], weightIndex)
		scrollRange := mustStringToInt(record[rangeIndex], rangeIndex)
		numTarget := mustStringToInt(record[numTargetIndex], numTargetIndex)
		duration := mustStringToInt(record[durationIndex], durationIndex)
		isBuff := false
		if strings.EqualFold(record[isBuffIndex], "true") {
			isBuff = true
		}
		selfCastOnly := false
		if strings.EqualFold(record[selfCastOnlyIndex], "true") {
			selfCastOnly = true
		}
		atkPercent := int16(mustStringToInt(record[atkPercentIndex], atkPercentIndex))
		defPercent := int16(mustStringToInt(record[defPercentIndex], defPercentIndex))
		agiPercent := int16(mustStringToInt(record[agiPercentIndex], agiPercentIndex))
		ms := int8(mustStringToInt(record[msIndex], msIndex))
		sp := int8(mustStringToInt(record[spIndex], spIndex))
		farmingPerkAmp := mustStringToInt(record[farmingPerkAmpIndex], farmingPerkAmpIndex)
		pveExpAmp := mustStringToInt(record[pveExpAmpIndex], pveExpAmpIndex)
		pvePerkAmp := pveExpAmp // same value now
		dmg := mustStringToInt(record[dmgIndex], dmgIndex)
		isAbsDmg := false
		if strings.EqualFold(record[isAbsDmgIndex], "true") {
			isAbsDmg = true
		}
		untradable := false
		perkItemTypes := make([]int, 0)
		requiredPerkLevels := make([]int, 0)

		item := Item{
			Id:         id,
			Type:       28, // BuffItem
			Category:   2,  // Other item
			Tier:       tier,
			Weight:     weight,
			Name:       removeRedundantText(record[nameIndex]),
			Untradable: untradable,
			Desc:       removeRedundantText(record[descIndex]),
		}
		item.BuffInfo = &BuffItemInfo{
			Type:         scrollType,
			Range:        uint(scrollRange),
			Duration:     duration,
			SelfCastOnly: selfCastOnly,
			NumTarget:    int(numTarget),
			IsBuff:       isBuff,
		}
		switch scrollType {
		case 1: // StatsModify
			item.StatsModify = &StatsModify{
				AtkPercent: atkPercent,
				DefPercent: defPercent,
				AgiPercent: agiPercent,
				Ms:         ms,
				Sp:         sp,
				Dmg:        0, // now no data
				IsAbsDmg:   false,
			}
		case 2: // ExpAmplify
			item.ExpAmplify = &ExpAmplify{
				FarmingPerkAmp: farmingPerkAmp,
				PveExpAmp:      pveExpAmp,
				PvePerkAmp:     pvePerkAmp,
			}
		case 3: // InstantDamage
			item.InstantDamage = &InstantDamage{
				Dmg:      dmg,
				IsAbsDmg: isAbsDmg,
			}
		}
		scrolls = append(scrolls, item)
		scrollRecipe := ItemRecipe{
			ItemId:      id,
			Ingredients: getMaterialList(record, record[recipeIndex], dataConfig),
			GoldCost:    mustStringToInt(record[goldCostIndex], goldCostIndex),
			// FameCost:    mustStringToInt(record[fameCostIndex], fameCostIndex),
		}
		if len(perkItemTypes) > 0 {
			scrollRecipe.PerkItemTypes = perkItemTypes
			scrollRecipe.RequiredPerkLevels = requiredPerkLevels
		}
		if len(scrollRecipe.Ingredients) > 0 {
			recipes = append(recipes, scrollRecipe)
		}
	}
	return scrolls, recipes, nil
}
