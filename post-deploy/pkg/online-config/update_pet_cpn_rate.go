package onlineconfig

import (
	"reflect"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
	sheets "google.golang.org/api/sheets/v4"
)

func updatePetComponentRateDataConfig(
	dataConfig *common.DataConfig, basePath string,
	sheetUrlConfig common.SheetUrlConfig, spreadSheetMetadata *sheets.Spreadsheet) {
	l := zap.S().With("func", "updatePetComponentRateDataConfig")
	// update pet component rate data config
	shouldRewritePetComponentRateFile := false
	l.Infow("GET PET COMPONENT RATE")
	sheetName := findSheetNameById(sheetUrlConfig.ListPetComponentRateUpdate, spreadSheetMetadata)
	petComponentRates, err := getPetComponentRateUpdate(sheetName)
	if err != nil {
		l.Errorw("cannot get pet component rate update", "err", err)
		panic(err)
	}
	for _, petCpnRate := range petComponentRates {
		currentPetCpnRate, ok := dataConfig.PetComponentRates[intToString(petCpnRate.PetItemId)]
		if reflect.DeepEqual(petCpnRate, currentPetCpnRate) {
			l.Infow("pet component rate data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new pet component rate", "data", petCpnRate)
		} else {
			l.Infow("detect pet component rate update", "data", petCpnRate)
		}
		shouldRewritePetComponentRateFile = true
		dataConfig.PetComponentRates[intToString(petCpnRate.PetItemId)] = petCpnRate // add or update
	}
	if shouldRewritePetComponentRateFile {
		if err := common.WriteSortedJsonFile(
			basePath+"/data-config/petComponentRates.json",
			"petComponentRates",
			dataConfig.PetComponentRates); err != nil {
			l.Errorw("cannot update petComponentRates.json file", "err", err)
		} else {
			l.Infow("update petComponentRates.json successfully")
		}
	}
}
