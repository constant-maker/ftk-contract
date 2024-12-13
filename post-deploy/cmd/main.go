package main

import (
	"bufio"
	"encoding/hex"
	"os"

	"github.com/ftk/post-deploy/pkg/common"
	"github.com/urfave/cli"
	"go.uber.org/zap"
)

const (
	testFlag        = "test"
	outFlag         = "out"
	out2Flag        = "out2"
	localFlag       = "local"
	dataPercentFlag = "data-percent"

	pathToTestFile = "../../post_deploy_test.txt"
)

func main() {
	// prepare better logger
	logger, err := zap.NewDevelopment()
	if err != nil {
		panic(err)
	}
	// we could init a Sugar Logger in other place just by zap.S()
	zap.ReplaceGlobals(logger)
	defer func() {
		_ = logger.Sync()
	}()

	// init app
	app := cli.NewApp()
	app.Name = "data builder"
	app.Usage = "build post-deploy data"
	app.Action = run

	app.Flags = append(app.Flags,
		cli.BoolFlag{
			Name:  testFlag,
			Usage: "to build test data",
		},
		cli.StringFlag{
			Name:  outFlag,
			Usage: "path to output data file",
			Value: "../../post_deploy.txt",
		},
		cli.StringFlag{
			Name:  out2Flag,
			Usage: "path to output reserve data file",
			Value: "../../post_deploy_reserve.txt",
		},
		cli.BoolFlag{
			Name:  localFlag,
			Usage: "build a small data for local",
		},
		cli.Int64Flag{
			Name:  dataPercentFlag,
			Usage: "percent of big data to be build",
			Value: 1,
		})
	if err := app.Run(os.Args); err != nil {
		logger.Sugar().Errorw("app error", "err", err)
	}
}

func run(c *cli.Context) error {
	var (
		l = zap.S().With("func", "run")
	)
	isTest := c.Bool(testFlag)
	dataConfig, err := getDataConfig(isTest)
	if err != nil {
		l.Errorw("cannot get data config", "err", err)
		return err
	}
	// l.Infow("data config", "value", dataConfig)
	// initMapEnums init map enum value in config
	common.InitMapEnums(dataConfig)

	// mapConfig for the distribution
	mapConfig, err := getMapConfig()
	if err != nil {
		l.Errorw("cannot get data config", "err", err)
		return err
	}
	// l.Infow("mapConfig", "value", mapConfig)

	// load data to process (from cache)
	var (
		cacheTileInfos        []common.TileInfo
		cacheMonsterLocations []common.MonsterLocation
	)
	if !isTest {
		if !c.Bool(localFlag) {
			cacheTileInfos, cacheMonsterLocations, err = getAllCachedDeployData(mapConfig)
			if err != nil {
				l.Errorw("cannot get full cached data", "err", err)
				return err
			}
			l.Infow("full data", "len tile infos", len(cacheTileInfos), "len monster location", len(cacheMonsterLocations))
		} else {
			cacheTileInfos, cacheMonsterLocations, err = splitDeployData(
				mapConfig, dataConfig, c.String(out2Flag), false, c.Int64(dataPercentFlag))
			if err != nil {
				l.Errorw("cannot get process data", "err", err)
				return err
			}
		}
		common.UpdateDataConfig(&dataConfig, "../..") // update config by online data
	}

	// buildCallData build post_deploy data
	rawCallDatas, err := buildCallData(dataConfig, mapConfig, cacheMonsterLocations,
		cacheTileInfos, isTest)
	if err != nil {
		// l.Errorw("cannot build call data", "err", err)
		return err
	}
	// write to file
	filePath := c.String(outFlag)
	if isTest {
		filePath = pathToTestFile
	}
	if err := writeLineToFile(filePath, rawCallDatas); err != nil {
		l.Errorw("cannot write call data to file", "err", err)
		return err
	}
	return nil
}

func writeLineToFile(filepath string, rawCallDatas [][]byte) error {
	callDatas := make([]string, 0)
	for _, callData := range rawCallDatas {
		callDatas = append(callDatas, hex.EncodeToString(callData))
	}
	f, err := os.Create(filepath)
	if err != nil {
		return err
	}
	defer f.Close()
	w := bufio.NewWriter(f)
	for _, line := range callDatas {
		if _, err := w.WriteString(line + "\n"); err != nil {
			return err
		}
	}
	return w.Flush()
}
