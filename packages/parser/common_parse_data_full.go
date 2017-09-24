// Copyright 2016 The go-daylight Authors
// This file is part of the go-daylight library.
//
// The go-daylight library is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// The go-daylight library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with the go-daylight library. If not, see <http://www.gnu.org/licenses/>.

package parser

import (
	"fmt"

	"github.com/GACHAIN/go-gachain-mvp/packages/consts"
	"github.com/GACHAIN/go-gachain-mvp/packages/smart"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
	"github.com/shopspring/decimal"
)

/*
Frontal check + adding the data from the block to a table and info_block
*/

// ParseDataFull checks the condiitions and proceeds of transactions
// Frontal check + adding the data from the block to a table and info_block
func (p *Parser) ParseDataFull(blockGenerator bool) error {

	p.dataPre()
	if p.dataType != 0 { // Parse only blocks
		return utils.ErrInfo(fmt.Errorf("incorrect dataType"))
	}
	var err error

	//if len(p.BinaryData) > 500000 {
	//	ioutil.WriteFile("block-"+string(utils.DSha256(p.BinaryData)), p.BinaryData, 0644)
	//}

	if blockGenerator {
		err = p.GetInfoBlock()
		if err != nil {
			return p.ErrInfo(err)
		}
	}

	err = p.ParseBlock()
	if err != nil {
		return utils.ErrInfo(err)
	}

	// Check data pointed in the head of block
	err = p.CheckBlockHeader()
	if err != nil {
		return utils.ErrInfo(err)
	}

	utils.WriteSelectiveLog("DELETE FROM transactions WHERE used = 1")
	afect, err := p.ExecSQLGetAffect("DELETE FROM transactions WHERE used = 1")
	if err != nil {
		utils.WriteSelectiveLog(err)
		return utils.ErrInfo(err)
	}
	utils.WriteSelectiveLog("afect: " + utils.Int64ToStr(afect))

	txCounter := make(map[int64]int64)
	p.fullTxBinaryData = p.BinaryData
	var txForRollbackTo []byte
	if len(p.BinaryData) > 0 {
		for {
			// Transactions processing can take a lot of time, you need to be marked
			p.UpdDaemonTime(p.GoroutineName)
			log.Debug("&p.BinaryData", p.BinaryData)
			transactionSize := utils.DecodeLength(&p.BinaryData)
			if len(p.BinaryData) == 0 {
				return utils.ErrInfo(fmt.Errorf("empty BinaryData"))
			}

			// Separate one transaction from the list of transactions
			//log.Debug("++p.BinaryData=%x\n", p.BinaryData)
			//log.Debug("transactionSize", transactionSize)
			transactionBinaryData := utils.BytesShift(&p.BinaryData, transactionSize)
			transactionBinaryDataFull := transactionBinaryData
			//ioutil.WriteFile("/tmp/dctx", transactionBinaryDataFull, 0644)
			//ioutil.WriteFile("/tmp/dctxhash", utils.Md5(transactionBinaryDataFull), 0644)
			// Add the the transaction in a set of transactions for RollbackTo where we will go in reverse order
			txForRollbackTo = append(txForRollbackTo, utils.EncodeLengthPlusData(transactionBinaryData)...)
			//log.Debug("transactionBinaryData: %x\n", transactionBinaryData)
			//log.Debug("txForRollbackTo: %x\n", txForRollbackTo)

			err = p.CheckLogTx(transactionBinaryDataFull, false, false)
			if err != nil {
				err0 := p.RollbackTo(txForRollbackTo, true)
				if err0 != nil {
					log.Error("error: %v", err0)
				}
				return utils.ErrInfo(err)
			}

			utils.WriteSelectiveLog("UPDATE transactions SET used=1 WHERE hex(hash) = " + string(utils.Md5(transactionBinaryDataFull)))
			affect, err := p.ExecSQLGetAffect("UPDATE transactions SET used=1 WHERE hex(hash) = ?", utils.Md5(transactionBinaryDataFull))
			if err != nil {
				utils.WriteSelectiveLog(err)
				utils.WriteSelectiveLog("RollbackTo")
				err0 := p.RollbackTo(txForRollbackTo, true)
				if err0 != nil {
					log.Error("error: %v", err0)
				}
				return utils.ErrInfo(err)
			}
			utils.WriteSelectiveLog("affect: " + utils.Int64ToStr(affect))
			//log.Debug("transactionBinaryData", transactionBinaryData)
			p.TxHash = string(utils.Md5(transactionBinaryData))
			log.Debug("p.TxHash %s", p.TxHash)
			p.TxSlice, err = p.ParseTransaction(&transactionBinaryData)
			log.Debug("p.TxSlice %v", p.TxSlice)
			if err != nil {
				err0 := p.RollbackTo(txForRollbackTo, true)
				if err0 != nil {
					log.Error("error: %v", err0)
				}
				return err
			}

			if p.BlockData.BlockId > 1 && p.TxContract == nil {
				var userID int64
				// txSlice[3] could be sliped the empty one
				if len(p.TxSlice) > 3 {
					if !utils.CheckInputData(p.TxSlice[3], "int64") {
						return utils.ErrInfo(fmt.Errorf("empty user_id"))
					}
					userID = utils.BytesToInt64(p.TxSlice[3])
				} else {
					return utils.ErrInfo(fmt.Errorf("empty user_id"))
				}

				// Count for each user how many transactions from him are in the block
				txCounter[userID]++

				// To prevent the possibility when 1 user can send a 10-gigabyte dos-block which will fill with his own transactions
				if txCounter[userID] > consts.MAX_BLOCK_USER_TXS {
					err0 := p.RollbackTo(txForRollbackTo, true)
					if err0 != nil {
						log.Error("error: %v", err0)
					}
					return utils.ErrInfo(fmt.Errorf("max_block_user_transactions"))
				}
			}
			if p.TxContract == nil {
				// Time in the transaction cannot be more than MAX_TX_FORW seconds of block time
				// and time in transaction cannot be less than -24 of block time
				if utils.BytesToInt64(p.TxSlice[2])-consts.MAX_TX_FORW > p.BlockData.Time || utils.BytesToInt64(p.TxSlice[2]) < p.BlockData.Time-consts.MAX_TX_BACK {
					err0 := p.RollbackTo(txForRollbackTo, true)
					if err0 != nil {
						log.Error("error: %v", err0)
					}
					return utils.ErrInfo(fmt.Errorf("incorrect transaction time"))
				}

				// Check if such type of transaction exists
				_, ok := consts.TxTypes[utils.BytesToInt(p.TxSlice[1])]
				if !ok {
					return utils.ErrInfo(fmt.Errorf("nonexistent type"))
				}
			} else {
				if int64(p.TxPtr.(*consts.TXHeader).Time)-consts.MAX_TX_FORW > p.BlockData.Time || int64(p.TxPtr.(*consts.TXHeader).Time) < p.BlockData.Time-consts.MAX_TX_BACK {
					return utils.ErrInfo(fmt.Errorf("incorrect transaction time"))
				}

			}
			p.TxMap = map[string][]byte{}

			p.TxIds++
			p.TxUsedCost = decimal.New(0, 0)
			p.TxCost = 0
			if p.TxContract != nil {
				// Check that there are enough money in CallContract
				err := p.CallContract(smart.CallInit | smart.CallCondition | smart.CallAction)
				// Pay for CPU resources
				p.payFPrice()
				if err != nil {
					if p.TxContract.Called == smart.CallCondition || p.TxContract.Called == smart.CallAction {
						err0 := p.RollbackTo(txForRollbackTo, false)
						if err0 != nil {
							log.Error("error: %v", err0)
						}
					}
					return utils.ErrInfo(err)
				}
			} else {
				MethodName := consts.TxTypes[utils.BytesToInt(p.TxSlice[1])]
				log.Debug("MethodName", MethodName+"Init")
				err := utils.CallMethod(p, MethodName+"Init")
				if _, ok := err.(error); ok {
					log.Error("error: %v", err)
					return utils.ErrInfo(err.(error))
				}

				log.Debug("MethodName", MethodName+"Front")
				err = utils.CallMethod(p, MethodName+"Front")
				if _, ok := err.(error); ok {
					log.Error("error: %v", err)
					err0 := p.RollbackTo(txForRollbackTo, true)
					if err0 != nil {
						log.Error("error: %v", err0)
					}
					return utils.ErrInfo(err.(error))
				}

				log.Debug("MethodName", MethodName)
				err = utils.CallMethod(p, MethodName)
				// Pay for CPU resources
				p.payFPrice()
				if _, ok := err.(error); ok {
					log.Error("error: %v", err)
					err0 := p.RollbackTo(txForRollbackTo, false)
					if err0 != nil {
						log.Error("error: %v", err0)
					}
					return utils.ErrInfo(err.(error))
				}
			}
			// Let user know that his transaction  is added in the block
			p.ExecSQL("UPDATE transactions_status SET block_id = ? WHERE hex(hash) = ?", p.BlockData.BlockId, utils.Md5(transactionBinaryDataFull))
			log.Debug("UPDATE transactions_status SET block_id = %d WHERE hex(hash) = %s", p.BlockData.BlockId, utils.Md5(transactionBinaryDataFull))

			// Here was a time(). That means if blocks with the same hashes of transactions were in the chain of blocks, ParseDataFull would return the error
			err = p.InsertInLogTx(transactionBinaryDataFull, utils.BytesToInt64(p.TxMap["time"]))
			if err != nil {
				return utils.ErrInfo(err)
			}

			if len(p.BinaryData) == 0 {
				break
			}
		}
	}
	if blockGenerator {
		p.UpdBlockInfo()
		p.InsertIntoBlockchain()
	} else {
		p.UpdBlockInfo()

	}
	return nil
}
