package onlineconfig

import (
	"bytes"
	"encoding/csv"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

const (
	toolCategory      = 0
	equipmentCategory = 1
	otherItemCategory = 2
)

// getMaterialList parses a raw recipe string and returns a slice of Ingredients.
func getMaterialList(rawRecord []string, rawS string, dataConfig *common.DataConfig) []common.Ingredient {
	l := zap.S().With("func", "getMaterialList", "raw record", rawRecord)
	if rawS == "" {
		return nil
	}
	arr := strings.Split(rawS, "\n")
	if len(arr) == 0 {
		panic("invalid recipe data enter")
	}
	result := make([]common.Ingredient, 0)
	for _, data := range arr {
		subArr := strings.Split(data, "-")
		if len(subArr) != 2 {
			l.Panic("invalid recipe data -")
		}
		rawItemName := subArr[0]
		rawAmount := subArr[1]
		itemName := removeRedundantText(rawItemName)
		var itemId int
		for _, item := range dataConfig.Items {
			if item.Type == 23 && item.Name == itemName {
				itemId = item.Id
				break
			}
		}
		if itemId == 0 {
			l.Panicw("invalid resource", "name", itemName)
		}
		amount := mustStringToInt(removeRedundantText(rawAmount), 0)
		result = append(result, common.Ingredient{
			ItemId: itemId,
			Amount: amount,
		})
	}
	return result
}

// removeRedundantText removes leading and trailing spaces and carriage return characters from the input string.
func removeRedundantText(s string) string {
	for i := 0; i < 3; i++ {
		s = strings.TrimSuffix(s, " ")
		s = strings.TrimSuffix(s, "\r")

		s = strings.TrimPrefix(s, " ")
		// s = strings.TrimPrefix(s, "\r")
	}
	return s
}

func mustStringToInt(s string, index int) int {
	if s == "" {
		return 0
	}
	num, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		fmt.Println("PARSE ERROR", s, index)
		panic(s + err.Error())
	}
	return int(num)
}

// getEnumType parses a string in the format "SOMETHING(#NUMBER)" and returns the NUMBER as an integer.
func getEnumType(s string, record []string) int {
	if s == "-" {
		return 0
	}
	arr := strings.Split(s, "#")
	if len(arr) != 2 {
		zap.S().Panicw("invalid # data", "data", s, "record", record)
	}
	numS := strings.TrimSuffix(arr[1], ")")
	num, err := strconv.ParseInt(numS, 10, 64)
	if err != nil {
		panic(err.Error())
	}
	return int(num)
}

func getRawCsvReader(url string) (*csv.Reader, error) {
	l := zap.S().With("func", "readCSV")
	resp, err := http.Get(url)
	if err != nil {
		l.Errorw("cannot get data", "err", err)
		return nil, err
	}
	body, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		l.Errorw("cannot read data", "err", err)
		return nil, err
	}
	reader := csv.NewReader(bytes.NewReader(body))
	reader.LazyQuotes = true
	return reader, nil
}

func getToolType(rawS string) int {
	splitS := strings.Split(rawS, "-")
	if len(splitS) != 2 {
		panic("invalid tool type")
	}
	toolType := removeRedundantText(splitS[1])
	switch strings.ToLower(toolType) {
	case "wood":
		return 0
	case "stone":
		return 1
	case "fish":
		return 2
	case "ore":
		return 3
	case "wheat":
		return 4
	case "berries":
		return 5
	default:
		panic("invalid tool type")
	}
}

func getResourceType(resourceType string) int {
	resourceTypes := map[string]int{
		"wood":    0,
		"stone":   1,
		"fish":    2,
		"ore":     3,
		"wheat":   4,
		"berries": 5,
	}

	key := strings.ToLower(resourceType)
	if val, ok := resourceTypes[key]; ok {
		return val
	}

	zap.S().Panicw("invalid skill type", "resourceType", resourceType)
	return -1
}

func getSkillEffectType(rawSkillType string) int {
	skillType := strings.ToLower(removeRedundantText(rawSkillType))

	skillTypes := map[string]int{
		"none":      0,
		"burn":      1,
		"poison":    2,
		"frostbite": 3,
		"stun":      4,
	}

	if val, ok := skillTypes[skillType]; ok {
		return val
	}

	zap.S().Panicw("invalid skill type", "rawSkillType", rawSkillType)
	return 0
}

func getItemType(dataConfig *common.DataConfig, rawTypeString string) int {
	key := strings.ToLower(rawTypeString)
	for k, v := range dataConfig.ItemTypes {
		if strings.EqualFold(string(k), key) {
			return v
		}
	}
	zap.S().Panicw("invalid item type", "rawTypeString", rawTypeString)
	return -1
}

func validateItemConfig(dataConfig common.DataConfig) {
	var (
		min, max int
	)
	for _, item := range dataConfig.Items {
		if min == 0 || item.Id < min {
			min = item.Id
		}
		if max < item.Id {
			max = item.Id
		}
	}
	zap.S().Infow("MIN MAX Item ID", "min", min, "max", max)
	for i := min; i <= max; i++ {
		if _, ok := dataConfig.Items[intToString(i)]; !ok {
			panic(fmt.Sprintf("lack id %d", i))
		}
	}
}

func findIndex(arr []string, element string) int {
	for index, e := range arr {
		e = removeRedundantText(e)
		if strings.EqualFold(e, element) {
			return index
		}
	}
	panic("cannot find index ~ header: " + element)
}

func getPerkItemTypes(dataConfig *common.DataConfig, rawText string) []int {
	var result []int
	splitText := strings.Split(rawText, ",")
	if len(splitText) == 1 {
		rawValue := removeRedundantText(splitText[0])
		result = append(result, int(getItemType(dataConfig, rawValue)))
		return result
	}
	for _, st := range splitText {
		rawValue := removeRedundantText(st)
		result = append(result, int(getItemType(dataConfig, rawValue)))
	}
	return result
}

func getPerkLevels(rawText string) []int {
	var result []int
	splitText := strings.Split(rawText, ",")
	if len(splitText) == 1 {
		rawValue := removeRedundantText(splitText[0])
		val := int(mustStringToInt(rawValue, 0))
		if val < 0 {
			zap.S().Panicw("invalid perk level", "value", val)
		}
		result = append(result, val)
		return result
	}
	for _, st := range splitText {
		rawValue := removeRedundantText(st)
		val := int(mustStringToInt(rawValue, 0))
		if val < 0 {
			zap.S().Panicw("invalid perk level", "value", val)
		}
		result = append(result, val)
	}
	return result
}

func getRarity(rawText string) int {
	switch strings.ToLower(rawText) {
	case "common":
		return 1
	case "uncommon":
		return 2
	case "rare":
		return 3
	case "epic":
		return 4
	case "legendary":
		return 5
	default:
		fmt.Println("rawText", rawText)
		zap.S().Panicw("invalid rarity", "rarity", rawText)
	}
	return -1
}

func findItemIDByName(name string, dataConfig *common.DataConfig) (int, error) {
	for _, item := range dataConfig.Items {
		if item.Name == name {
			return item.Id, nil
		}
	}
	return 0, fmt.Errorf("cannot find item by name: %s", name)
}

func intToString(i int) string {
	return strconv.FormatInt(int64(i), 10)
}
