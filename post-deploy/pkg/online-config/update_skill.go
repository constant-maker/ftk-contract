package onlineconfig

import (
	"reflect"

	"github.com/ftk/post-deploy/pkg/common"
	"go.uber.org/zap"
)

func updateSkillDataConfig(dataConfig *common.DataConfig, basePath string) {
	l := zap.S().With("func", "updateSkillDataConfig")
	// update list skill
	shouldRewriteSkillFile := false
	l.Infow("GET LIST SKILL")
	listSkillUpdate, err := getListSkillUpdate(dataConfig)
	if err != nil {
		l.Errorw("cannot get list skill update", "err", err)
		panic(err)
	}
	for _, skill := range listSkillUpdate {
		currentSkill, ok := dataConfig.Skills[intToString(skill.Id)]
		if reflect.DeepEqual(skill, currentSkill) {
			l.Infow("skill data unchanged")
			continue
		}
		if !ok {
			l.Infow("detect new skill", "data", skill)
		} else {
			l.Infow("detect skill update", "data", skill)
		}
		shouldRewriteSkillFile = true
		dataConfig.Skills[intToString(skill.Id)] = skill // add or update
	}
	if shouldRewriteSkillFile {
		if err := common.WriteSortedJsonFile(basePath+"/data-config/skills.json", "skills", dataConfig.Skills); err != nil {
			l.Errorw("cannot update skill.json file", "err", err)
		} else {
			l.Infow("update skill.json successfully")
		}
	}
}
