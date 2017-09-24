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
	//	"fmt"

	"github.com/GACHAIN/go-gachain-mvp/packages/consts"
	"github.com/GACHAIN/go-gachain-mvp/packages/lib"
	"github.com/GACHAIN/go-gachain-mvp/packages/smart"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

// RollbackTo rollbacks proceeded transactions
// If the error appears during the checking of transactions, call the rollback of all transactions
func (p *Parser) RollbackTo(binaryData []byte, skipCurrent bool) error {
	var err error
	if len(binaryData) > 0 {
		// In the beggining it's neccessary to obtain the sizes of all transactions in order to go through them in reverse order
		binForSize := binaryData
		var sizesSlice []int64
		for {
			txSize := utils.DecodeLength(&binForSize)
			if txSize == 0 {
				break
			}
			sizesSlice = append(sizesSlice, txSize)
			// Remove the transaction
			log.Debug("txSize", txSize)
			//log.Debug("binForSize", binForSize)
			utils.BytesShift(&binForSize, txSize)
			if len(binForSize) == 0 {
				break
			}
		}
		sizesSlice = utils.SliceReverse(sizesSlice)
		for i := 0; i < len(sizesSlice); i++ {
			// Processing of transaction may take a lot off time, we have to be marked
			p.UpdDaemonTime(p.GoroutineName)
			// Separate one transaction
			transactionBinaryData := utils.BytesShiftReverse(&binaryData, sizesSlice[i])
			binaryData := transactionBinaryData
			// Get know the quantity of bytes, which the size takes and remove it
			utils.BytesShiftReverse(&binaryData, len(lib.EncodeLength(sizesSlice[i])))
			p.TxHash = string(utils.Md5(transactionBinaryData))
			p.TxSlice, err = p.ParseTransaction(&transactionBinaryData)
			if err != nil {
				return utils.ErrInfo(err)
			}
			var (
				MethodName string
				verr       interface{}
			)
			if p.TxContract == nil {
				MethodName = consts.TxTypes[utils.BytesToInt(p.TxSlice[1])]
				p.TxMap = map[string][]byte{}
				verr = utils.CallMethod(p, MethodName+"Init")
				if _, ok := verr.(error); ok {
					return utils.ErrInfo(verr.(error))
				}
			}
			// if we get to the transaction, which caused the error, then we roll back only the frontal check
			/*if i == 0 {
						/*if skipCurrent { // Transaction that caused the error was finished before frontal check, then there is nothing to rall back
							continue
						}*/
			/*// If we reached only half of the frontal function
						MethodNameRollbackFront := MethodName + "RollbackFront"
						// roll back only frontal check
						verr = utils.CallMethod(p, MethodNameRollbackFront)
						if _, ok := verr.(error); ok {
							return utils.ErrInfo(verr.(error))
						}*/
			/*} else if onlyFront {*/
			/*verr = utils.CallMethod(p, MethodName+"RollbackFront")
			if _, ok := verr.(error); ok {
				return utils.ErrInfo(verr.(error))
			}*/
			/*} else {*/
			/*verr = utils.CallMethod(p, MethodName+"RollbackFront")
			if _, ok := verr.(error); ok {
				return utils.ErrInfo(verr.(error))
			}*/
			if (i == 0 && !skipCurrent) || i > 0 {
				log.Debug(MethodName + "Rollback")
				if p.TxContract != nil {
					if err := p.CallContract(smart.CallInit | smart.CallRollback); err != nil {
						return utils.ErrInfo(err)
					}
					if err = p.autoRollback(); err != nil {
						return p.ErrInfo(err)
					}
				} else {
					verr = utils.CallMethod(p, MethodName+"Rollback")
					if _, ok := verr.(error); ok {
						return utils.ErrInfo(verr.(error))
					}
				}
				err = p.DelLogTx(binaryData)
				if err != nil {
					log.Error("error: %v", err)
				}
				affect, err := p.ExecSQLGetAffect("DELETE FROM transactions WHERE hex(hash) = ?", p.TxHash)
				if err != nil {
					utils.WriteSelectiveLog(err)
					return utils.ErrInfo(err)
				}
				utils.WriteSelectiveLog("affect: " + utils.Int64ToStr(affect))
			}

			utils.WriteSelectiveLog("UPDATE transactions SET used = 0, verified = 0 WHERE hex(hash) = " + string(p.TxHash))
			affect, err := p.ExecSQLGetAffect("UPDATE transactions SET used = 0, verified = 0 WHERE hex(hash) = ?", p.TxHash)
			if err != nil {
				utils.WriteSelectiveLog(err)
				return utils.ErrInfo(err)
			}
			utils.WriteSelectiveLog("affect: " + utils.Int64ToStr(affect))

		}
	}
	return err
}
