package onlineconfig

import (
	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

func UpdateDataConfig(dataConfig *common.DataConfig, basePath string) {
	l := zap.S().With("func", "UpdateDataConfig")

	// update item data config
	updateItemDataConfig(dataConfig, basePath)

	// update skill data config
	updateSkillDataConfig(dataConfig, basePath)

	// update item exchange data config
	updateItemExchangeDataConfig(dataConfig, basePath)

	l.Infow("update data config completed")
}
