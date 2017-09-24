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
	"github.com/GACHAIN/go-gachain-mvp/packages/lib"
	"github.com/GACHAIN/go-gachain-mvp/packages/smart"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

/**
 * Rollback of rb_time_ tables that has been modified by transactions
*/
/*
func (p *Parser) ParseDataRollbackFront(txcandidateBlock bool) error {

// In the beginning it is necessary to obtain the sizes of all the transactions in order to go through them in reverse order
	binForSize := p.BinaryData
	var sizesSlice []int64
	for {
		txSize := utils.DecodeLength(&binForSize)
		if txSize == 0 {
			break
		}
		sizesSlice = append(sizesSlice, txSize)
		// remove the transaction
		utils.BytesShift(&binForSize, txSize)
		if len(binForSize) == 0 {
			break
		}
	}
	sizesSlice = utils.SliceReverse(sizesSlice)
	for i := 0; i < len(sizesSlice); i++ {
		// Processing of the transactions may take a lot of time, you need to be marked
		p.UpdDaemonTime(p.GoroutineName)
		// Separate one transaction
		transactionBinaryData := utils.BytesShiftReverse(&p.BinaryData, sizesSlice[i])
		// We'll get know the quantity of bytes, which the size takes
		size_ := len(utils.EncodeLength(sizesSlice[i]))
		// remove the size
		utils.BytesShiftReverse(&p.BinaryData, size_)
		p.TxHash = string(utils.Md5(transactionBinaryData))

		// the information about previous block (the last added)
		err := p.GetInfoBlock()
		if err != nil {
			return p.ErrInfo(err)
		}
		if txcandidateBlock {
			utils.WriteSelectiveLog("UPDATE transactions SET verified = 0 WHERE hex(hash) = " + string(p.TxHash))
			affect, err := p.ExecSQLGetAffect("UPDATE transactions SET verified = 0 WHERE hex(hash) = ?", p.TxHash)
			if err != nil {
				utils.WriteSelectiveLog(err)
				return p.ErrInfo(err)
			}
			utils.WriteSelectiveLog("affect: " + utils.Int64ToStr(affect))
		}
		/*affected, err := p.ExecSQLGetAffect("DELETE FROM log_transactions WHERE hex(hash) = ?", p.TxHash)
		log.Debug("DELETE FROM log_transactions WHERE hex(hash) = %s / affected = %d", p.TxHash, affected)
		if err != nil {
			return p.ErrInfo(err)
		}*/
/*
		p.TxSlice, err = p.ParseTransaction(&transactionBinaryData)
		if err != nil {
			return p.ErrInfo(err)
		}
		p.dataType = utils.BytesToInt(p.TxSlice[1])
		//userId := p.TxSlice[3]
		MethodName := consts.TxTypes[p.dataType]
		err_ := utils.CallMethod(p, MethodName+"Init")
		if _, ok := err_.(error); ok {
			return p.ErrInfo(err_.(error))
		}
		err_ = utils.CallMethod(p, MethodName+"RollbackFront")
		if _, ok := err_.(error); ok {
			return p.ErrInfo(err_.(error))
		}
	}

	return nil
}
*/

/* 
Rollback of DB
*/

// ParseDataRollback rollbacks blocks
func (p *Parser) ParseDataRollback() error {

	p.dataPre()
	if p.dataType != 0 { // parse only blocks
		return utils.ErrInfo(fmt.Errorf("incorrect dataType"))
	}
	var err error

	err = p.ParseBlock()
	if err != nil {
		return utils.ErrInfo(err)
	}
	if len(p.BinaryData) > 0 {
		// In the beginning it is necessary to obtain the sizes of all the transactions in order to go through them in reverse order
		binForSize := p.BinaryData
		var sizesSlice []int64
		for {
			txSize := utils.DecodeLength(&binForSize)
			if txSize == 0 {
				break
			}
			sizesSlice = append(sizesSlice, txSize)
			// remove the transaction
			utils.BytesShift(&binForSize, txSize)
			if len(binForSize) == 0 {
				break
			}
		}
		sizesSlice = utils.SliceReverse(sizesSlice)
		for i := 0; i < len(sizesSlice); i++ {
			// processing of the transaction may take a lot of time, we need to be marked
			p.UpdDaemonTime(p.GoroutineName)
			// separate one transaction
			transactionBinaryData := utils.BytesShiftReverse(&p.BinaryData, sizesSlice[i])
			// we'll get know the quantaty of bytes which the size takes
			utils.BytesShiftReverse(&p.BinaryData, len(lib.EncodeLength(sizesSlice[i])))
			p.TxHash = string(utils.Md5(transactionBinaryData))

			utils.WriteSelectiveLog("UPDATE transactions SET used=0, verified = 0 WHERE hex(hash) = " + string(p.TxHash))
			affect, err := p.ExecSQLGetAffect("UPDATE transactions SET used=0, verified = 0 WHERE hex(hash) = ?", p.TxHash)
			if err != nil {
				utils.WriteSelectiveLog(err)
				return p.ErrInfo(err)
			}
			utils.WriteSelectiveLog("affect: " + utils.Int64ToStr(affect))
			affected, err := p.ExecSQLGetAffect("DELETE FROM log_transactions WHERE hex(hash) = ?", p.TxHash)
			log.Debug("DELETE FROM log_transactions WHERE hex(hash) = %s / affected = %d", p.TxHash, affected)
			if err != nil {
				return p.ErrInfo(err)
			}
			// let the user know that his transaction isn't in the block
			err = p.ExecSQL("UPDATE transactions_status SET block_id = 0 WHERE hex(hash) = ?", p.TxHash)
			log.Debug("UPDATE transactions_status SET block_id = 0 WHERE hex(hash) = %s", p.TxHash)
			if err != nil {
				return p.ErrInfo(err)
			}
			// put the transaction in the turn for checking, suddenly we will need it
			dataHex := utils.BinToHex(transactionBinaryData)
			log.Debug("DELETE FROM queue_tx WHERE hex(hash) = %s", p.TxHash)
			err = p.ExecSQL("DELETE FROM queue_tx  WHERE hex(hash) = ?", p.TxHash)
			if err != nil {
				return p.ErrInfo(err)
			}
			log.Debug("INSERT INTO queue_tx (hash, data) VALUES (%s, %s)", p.TxHash, dataHex)
			err = p.ExecSQL("INSERT INTO queue_tx (hash, data) VALUES ([hex], [hex])", p.TxHash, dataHex)
			if err != nil {
				return p.ErrInfo(err)
			}

			p.TxSlice, err = p.ParseTransaction(&transactionBinaryData)
			if err != nil {
				return p.ErrInfo(err)
			}
			if p.TxContract != nil {
				if err := p.CallContract(smart.CallInit | smart.CallRollback); err != nil {
					return utils.ErrInfo(err)
				}
				if err = p.autoRollback(); err != nil {
					return p.ErrInfo(err)
				}
			} else {
				p.dataType = utils.BytesToInt(p.TxSlice[1])
				MethodName := consts.TxTypes[p.dataType]
				result := utils.CallMethod(p, MethodName+"Init")
				if _, ok := result.(error); ok {
					return p.ErrInfo(result.(error))
				}
				result = utils.CallMethod(p, MethodName+"Rollback")
				if _, ok := result.(error); ok {
					return p.ErrInfo(result.(error))
				}
				/*err_ = utils.CallMethod(p, MethodName+"RollbackFront")
				if _, ok := err_.(error); ok {
					return p.ErrInfo(err_.(error))
				}*/
			}
		}
	}
	return nil
}
