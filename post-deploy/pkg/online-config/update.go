package onlineconfig

import (
	"context"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
	"google.golang.org/api/option"
	sheets "google.golang.org/api/sheets/v4"
)

var (
	gSpreadSheetId string // global variable to store spreadsheet id
	gSrv           *sheets.Service
)

func UpdateDataConfig(
	dataConfig *common.DataConfig, basePath string,
	sheetAuthBytes []byte, sheetUrlConfig common.SheetUrlConfig) {
	l := zap.S().With("func", "UpdateDataConfig")

	// set global variable gSpreadSheetId before calling other functions to get update data
	gSpreadSheetId = sheetUrlConfig.SpreadsheetsId
	srv, err := sheets.NewService(context.Background(),
		option.WithAuthCredentialsJSON(option.ServiceAccount, sheetAuthBytes))
	if err != nil {
		l.Panicw("unable to retrieve Sheets client", "err", err)
	}
	gSrv = srv
	// done set global variable gSpreadSheetId and gSrv

	spreadSheetMetadata, err := gSrv.Spreadsheets.Get(gSpreadSheetId).Do()
	if err != nil {
		l.Panicw("unable to get spreadsheet", "err", err)
	}
	l.Infow("successfully connected to spreadsheet", "title", spreadSheetMetadata.Properties.Title)

	// update item data config
	updateItemDataConfig(dataConfig, basePath, sheetUrlConfig, spreadSheetMetadata)

	// update skill data config
	updateSkillDataConfig(dataConfig, basePath, sheetUrlConfig, spreadSheetMetadata)

	// update item exchange data config
	updateItemExchangeDataConfig(dataConfig, basePath, sheetUrlConfig, spreadSheetMetadata)

	// update pet component rate data config
	updatePetComponentRateDataConfig(dataConfig, basePath, sheetUrlConfig, spreadSheetMetadata)

	l.Infow("update data config completed")
}
