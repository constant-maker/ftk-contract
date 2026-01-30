package onlineconfig

import (
	"reflect"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

func updateItemExchangeDataConfig(dataConfig *common.DataConfig, basePath string) {
	l := zap.S().With("func", "updateItemExchangeDataConfig")
	// update list item exchange
	shouldRewriteFile := false
	l.Infow("GET LIST ITEM EXCHANGE")
	listItemExUpdate, err := getItemExUpdate(dataConfig)
	if err != nil {
		l.Errorw("cannot get list item exchange update", "err", err)
		panic(err)
	}

	// reset shouldRewriteFile to check item exchange
	for _, itemEx := range listItemExUpdate {
		currentItemEx, ok := dataConfig.ItemExchanges[intToString(itemEx.ItemId)]
		if reflect.DeepEqual(itemEx, currentItemEx) {
			l.Infow("item exchange data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new item exchange", "data", itemEx)
		} else {
			l.Infow("detect item exchange update", "data", itemEx)
		}
		shouldRewriteFile = true
		dataConfig.ItemExchanges[intToString(itemEx.ItemId)] = itemEx // add
	}
	if shouldRewriteFile {
		if err := common.WriteSortedJsonFile(basePath+"/data-config/itemExchanges.json", "itemExchanges", dataConfig.ItemExchanges); err != nil {
			l.Errorw("cannot update itemExchanges.json file", "err", err)
		} else {
			l.Infow("update itemExchanges.json successfully")
		}
	}
}
