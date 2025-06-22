package transactor

import (
	"context"
	"math/big"
	"time"

	gblockchain "github.com/NNagato/common/blockchain"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	ethcommon "github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"go.uber.org/zap"
)

type Transactor struct {
	l               *zap.SugaredLogger
	eClient         *ethclient.Client
	contractAddress ethcommon.Address
	txOpts          *bind.TransactOpts
	chainID         *big.Int
}

func NewTransactor(rpcEndpoint string, contractAddress ethcommon.Address, pk string) *Transactor {
	l := zap.S()
	eClient, err := ethclient.Dial(rpcEndpoint)
	if err != nil {
		l.Panicw("cannot init eth client", "err", err, "rpcEndpoint", rpcEndpoint)
	}
	chainID, err := eClient.ChainID(context.Background())
	if err != nil {
		l.Panicw("cannot get chainID", "err", err)
	}
	codes, err := eClient.CodeAt(context.Background(), contractAddress, nil)
	if err != nil {
		l.Panicw("cannot get code", "err", err, "contractAddress", contractAddress.Hex())
	}
	if len(codes) == 0 {
		l.Panicw("invalid world address, it's not a contract")
	}
	txOpts, err := gblockchain.TransactOptsFromPK(pk, chainID)
	if err != nil {
		l.Panicw("cannot parse account", "err", err, "pk", pk)
	}
	l.Infow("acc", "address", txOpts.From.Hex())
	balance, err := eClient.BalanceAt(context.Background(), txOpts.From, nil)
	if err != nil {
		l.Panicw("cannot get acc balance", "err", err, "address", txOpts.From.Hex())
	}
	l.Infow("eth balance", "balance", balance)
	// if balance.Cmp(gblockchain.AmountToTokenWei(0.5, 18)) == -1 {
	// 	l.Panicw("low balance", "address", txOpts.From.Hex())
	// }
	t := &Transactor{
		l:               l,
		eClient:         eClient,
		contractAddress: contractAddress,
		txOpts:          txOpts,
		chainID:         chainID,
	}
	return t
}

func (t *Transactor) Execute(callData [][]byte, markIndex int) error {
	l := zap.S().With("func", "Transactor.Execute")
	if len(callData) == 0 {
		return nil
	}
	nonce, err := t.eClient.NonceAt(context.Background(), t.txOpts.From, nil)
	if err != nil {
		l.Errorw("cannot get nonce", "err", err)
		return err
	}
	l.Infow("running data", "nonce", nonce, "len calldata", len(callData))
	counter := 0
	callData = callData[markIndex:]
	for {
		if err := func() error {
			for index := markIndex; index < len(callData); index++ {
				l.Infow("markIndex", "value", markIndex)
				counter++
				rawTx := types.NewTx(&types.DynamicFeeTx{
					ChainID:   t.chainID,
					Nonce:     nonce,
					GasTipCap: gblockchain.GweiToWei(0.000000005),
					GasFeeCap: gblockchain.GweiToWei(0.00000001),
					Gas:       500_000,
					To:        &t.contractAddress,
					Value:     big.NewInt(0),
					Data:      callData[index],
				})
				signedTx, err := t.txOpts.Signer(t.txOpts.From, rawTx)
				if err != nil {
					l.Errorw("cannot sign tx", "err", err)
					return err
				}
				if err := t.eClient.SendTransaction(context.Background(), signedTx); err != nil {
					l.Errorw("cannot send transaction", "err", err)
					return err
				}
				l.Infow("send transaction successfully", "tx", signedTx.Hash().Hex())
				if index == len(callData)-1 {
					panic("DONE!")
				}
				markIndex++
				nonce++
				time.Sleep(time.Second)
				if counter%100 == 0 {
					l.Info("take a break")
					time.Sleep(10 * time.Second)
				}
			}
			return nil
		}(); err != nil {
			l.Errorw("cannot send transaction", "err", err)
			time.Sleep(5 * time.Second)
			nonce, err = t.eClient.NonceAt(context.Background(), t.txOpts.From, nil)
			if err != nil {
				l.Panicw("cannot get nonce", "err", err)
			}
			time.Sleep(time.Second)
		}
	}
}
