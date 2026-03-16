package onlineconfig

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

func getPetComponentRateUpdate(sheetName string) ([]common.PetCpnRate, error) {
	l := zap.S().With("func", "getPetComponentRateUpdate")
	rawData, err := getSheetRawData(sheetName, 11)
	if err != nil {
		l.Errorw("cannot csv reader", "err", err)
		return nil, err
	}
	result := make([]common.PetCpnRate, 0)
	var (
		// id	name	bag	eye	horn	mouth	tail	wing	body	head	weapon
		petItemIdIndex, bagIndex, eyeIndex, hornIndex, mouthIndex, tailIndex, wingIndex, bodyIndex, headIndex, weaponIndex int
		headerFound                                                                                                        bool
	)
	for i := range rawData {
		record := rawData[i]
		if len(record) == 0 {
			continue
		}
		if record[0] == "" { // empty row
			l.Warnw("invalid pet component rate format", "data", record)
			continue
		}
		if strings.EqualFold(record[0], "id") { // header
			petItemIdIndex = 0
			bagIndex = findIndex(record, "bag")
			eyeIndex = findIndex(record, "eye")
			hornIndex = findIndex(record, "horn")
			mouthIndex = findIndex(record, "mouth")
			tailIndex = findIndex(record, "tail")
			wingIndex = findIndex(record, "wing")
			bodyIndex = findIndex(record, "body")
			headIndex = findIndex(record, "head")
			weaponIndex = findIndex(record, "weapon")
			l.Infow(
				"list index",
				"petItemIdIndex", petItemIdIndex,
				"bagIndex", bagIndex,
				"eyeIndex", eyeIndex,
				"hornIndex", hornIndex,
				"mouthIndex", mouthIndex,
				"tailIndex", tailIndex,
				"wingIndex", wingIndex,
				"bodyIndex", bodyIndex,
				"headIndex", headIndex,
				"weaponIndex", weaponIndex,
			)
			headerFound = true
			continue
		}
		if !headerFound {
			l.Panicw("invalid pet component rate format, header must appear before data rows", "data", record)
		}

		if !isNumber(record[0]) {
			break // stop parsing when the first column is not a number, which means the data part is ended
		}

		petItemId := mustStringToInt(record[petItemIdIndex], petItemIdIndex)
		listCpnIndex := []int{bagIndex, eyeIndex, hornIndex, mouthIndex, tailIndex, wingIndex, bodyIndex, headIndex, weaponIndex}

		petComponents := make([]common.PetCpn, 0)
		for cpnType, recordIndex := range listCpnIndex {
			petCpn := common.PetCpn{
				CpnType: uint8(cpnType),
			}
			CpnValues := make([]uint16, 0)
			CpnRatios := make([]uint16, 0)
			if record[recordIndex] == "" {
				// no slot for this item, fill with default value
				CpnValues = append(CpnValues, 0)
				CpnRatios = append(CpnRatios, 10_000)
				petCpn.CpnValues = CpnValues
				petCpn.CpnRatios = CpnRatios
				petComponents = append(petComponents, petCpn)
				continue
			}
			// sample data MAX: 4
			//             RARITY: {0: 90} // 0 has 90% to appear
			// mean 90% to get 0, 10% to get 1, 2, 3, 4 (equal rate), total rate is 100%
			// split by \n first
			splitByLine := strings.Split(record[recordIndex], "\n")
			if len(splitByLine) == 0 || len(splitByLine) > 2 {
				l.Panicw("invalid pet component rate format", "data", record)
			}
			splitByComma := strings.Split(splitByLine[0], ":")
			if len(splitByComma) != 2 {
				l.Panicw("invalid pet component rate format, expected split by :", "data", record)
			}
			maxCpnValue := uint16(mustStringToInt(strings.TrimSpace(splitByComma[1]), 1)) // e.g 5 => 0, 1, 2, 3, 4, 5
			if len(splitByLine) == 1 {                                                    // e.g MAX: 4, so value from 1 -> 4 has equal rate, 0 has 0 rate
				splitByComma := strings.Split(splitByLine[0], ":")
				if len(splitByComma) != 2 {
					l.Panicw("invalid pet component rate format, expected split by :", "data", record)
				}
				rate := uint16(10_000 / maxCpnValue)        // not include 0
				offset := 10_000 - rate*uint16(maxCpnValue) // will add the offset to the last value to make sure the total ratio is 10_000
				for i := range maxCpnValue + 1 {            // 0 -> maxCpnValue
					if i == 0 {
						CpnValues = append(CpnValues, 0)
						CpnRatios = append(CpnRatios, 0)
					} else {
						CpnValues = append(CpnValues, uint16(i))
						CpnRatios = append(CpnRatios, rate)
					}
				}
				CpnRatios[len(CpnRatios)-1] += offset
			} else if len(splitByLine) == 2 {
				// handle the format like RARITY: {0: 90, 1: 5, 2: 3, 3: 1, 4: 1}
				rarityLine := strings.TrimSpace(splitByLine[1])
				startIndex := strings.Index(rarityLine, "{")
				endIndex := strings.LastIndex(rarityLine, "}")
				if startIndex == -1 || endIndex == -1 || startIndex > endIndex {
					l.Panicw("invalid pet component rate format, expected rarity object", "data", record, "rarityLine", rarityLine)
				}
				objString := rarityLine[startIndex : endIndex+1]
				rawRarityData, err := parseRarityDataObject(objString)
				if err != nil {
					l.Panicw("invalid pet component rate format", "objString", objString, "error", err)
				}
				rarityData := make(map[uint16]uint16)
				var totalCustomRate uint16 = 0
				for value, rate := range rawRarityData {
					if value > maxCpnValue {
						l.Panicw("invalid pet component rate format, rarity value out of range", "data", record, "value", value, "max", maxCpnValue)
					}
					rate16 := uint16(rate * 100) // convert to uint16, and make sure the total ratio is 10_000
					rarityData[value] = rate16
					totalCustomRate += rate16
				}
				if totalCustomRate > 10_000 {
					l.Panicw("invalid pet component rate format, total ratio should be 10_000", "data", record, "totalCustomRate", totalCustomRate)
				}
				theRestRatio := uint16(10_000 - totalCustomRate)
				theRestNumValue := int(maxCpnValue) + 1 - len(rawRarityData) // the rest values that not in the custom rate
				if theRestNumValue < 0 {
					l.Panicw("invalid pet component rate format, too many custom rarity values", "data", record, "max", maxCpnValue, "customCount", len(rawRarityData))
				}
				cpnRate := uint16(0)
				offset := uint16(0)
				if theRestNumValue == 0 {
					if theRestRatio != 0 {
						l.Panicw("invalid pet component rate format, total ratio should be 10_000 when all values are customized", "data", record, "theRestRatio", theRestRatio)
					}
				} else {
					restNumValue16 := uint16(theRestNumValue)
					cpnRate = theRestRatio / restNumValue16        // the rate for the rest values
					offset = theRestRatio - cpnRate*restNumValue16 // will add the offset to the last value to make sure the total ratio is 10_000
				}
				for i := range maxCpnValue + 1 {
					if rate, ok := rarityData[i]; ok {
						CpnValues = append(CpnValues, i)
						CpnRatios = append(CpnRatios, rate)
					} else {
						CpnValues = append(CpnValues, i)
						CpnRatios = append(CpnRatios, cpnRate)
					}
				}
				CpnRatios[len(CpnRatios)-1] += offset
			}
			petCpn.CpnValues = CpnValues
			petCpn.CpnRatios = CpnRatios
			petComponents = append(petComponents, petCpn)
		}
		pcr := common.PetCpnRate{
			PetItemId:  petItemId,
			Components: petComponents,
		}
		validatePetComponentRate(pcr)
		result = append(result, pcr)
	}
	return result, nil
}

func validatePetComponentRate(pcr common.PetCpnRate) error {
	for _, cpn := range pcr.Components {
		if len(cpn.CpnValues) != len(cpn.CpnRatios) {
			return fmt.Errorf("invalid pet component rate format, cpn values and ratios length mismatch for pet item id %d, cpn type %d", pcr.PetItemId, cpn.CpnType)
		}
		var totalRatio uint16 = 0
		for index, ratio := range cpn.CpnRatios {
			if index != int(cpn.CpnValues[index]) {
				return fmt.Errorf("invalid pet component rate format, cpn values and ratios index mismatch for pet item id %d, cpn type %d, index: %d, value: %d", pcr.PetItemId, cpn.CpnType, index, cpn.CpnValues[index])
			}
			totalRatio += ratio
		}
		if totalRatio != 10_000 {
			return fmt.Errorf("invalid pet component rate format, total ratio should be 10_000 for pet item id %d, cpn type %d, totalRatio: %d", pcr.PetItemId, cpn.CpnType, totalRatio)
		}
	}
	return nil
}

func parseRarityDataObject(raw string) (map[uint16]float64, error) {
	raw = strings.TrimSpace(raw)
	if len(raw) < 2 || raw[0] != '{' || raw[len(raw)-1] != '}' {
		return nil, fmt.Errorf("invalid rarity object: %s", raw)
	}
	body := strings.TrimSpace(raw[1 : len(raw)-1])
	if body == "" {
		return map[uint16]float64{}, nil
	}

	result := make(map[uint16]float64)
	entries := strings.SplitSeq(body, ",")
	for entry := range entries {
		pair := strings.Split(entry, ":")
		if len(pair) != 2 {
			return nil, fmt.Errorf("invalid rarity entry: %s", entry)
		}

		keyText := strings.Trim(strings.TrimSpace(pair[0]), "\"'")
		valueText := strings.TrimSpace(pair[1])

		keyInt := mustStringToInt(keyText, 0)
		if keyInt < 0 {
			return nil, fmt.Errorf("invalid rarity key: %s", keyText)
		}
		value, err := strconv.ParseFloat(valueText, 64)
		if err != nil {
			return nil, fmt.Errorf("invalid rarity value %q: %w", valueText, err)
		}

		result[uint16(keyInt)] = value
	}

	return result, nil
}
