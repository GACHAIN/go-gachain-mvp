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
	"time"

	"github.com/GACHAIN/go-gachain-mvp/packages/consts"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

// CheckBlockHeader checks the block header
func (p *Parser) CheckBlockHeader() error {
	var err error
	// information about previous block (the last added)
	// is determined outside in в GetBlocks p.PrevBlock, that's why here is important not to rewrite data from block_chain
	if p.PrevBlock == nil || p.PrevBlock.BlockId != p.BlockData.BlockId-1 {
		p.PrevBlock, err = p.GetBlockDataFromBlockChain(p.BlockData.BlockId - 1)
		log.Debug("PrevBlock 0", p.PrevBlock)
		if err != nil {
			return utils.ErrInfo(err)
		}
	}
	log.Debug("PrevBlock.BlockId: %v / PrevBlock.Time: %v / PrevBlock.WalletId: %v / PrevBlock.StateID: %v / PrevBlock.Sign: %v", p.PrevBlock.BlockId, p.PrevBlock.Time, p.PrevBlock.WalletId, p.PrevBlock.StateID, p.PrevBlock.Sign)

	log.Debug("p.PrevBlock.BlockId", p.PrevBlock.BlockId)
	// for the local tests
	if p.PrevBlock.BlockId == 1 {
		if *utils.StartBlockID != 0 {
			p.PrevBlock.BlockId = *utils.StartBlockID
		}
	}

	var first bool
	if p.BlockData.BlockId == 1 {
		first = true
	} else {
		first = false
	}
	log.Debug("%v", first)

	// MrklRoot is needed to check the signatures of block, as well as to check limits MAX_TX_SIZE и MAX_TX_COUN
	//log.Debug("p.Variables: %v", p.Variables)
	p.MrklRoot, err = utils.GetMrklroot(p.BinaryData, first)
	log.Debug("p.MrklRoot: %s", p.MrklRoot)
	if err != nil {
		return utils.ErrInfo(err)
	}

	// check the time
	if !utils.CheckInputData(p.BlockData.Time, "int") {
		log.Debug("p.BlockData.Time", p.BlockData.Time)
		return utils.ErrInfo(fmt.Errorf("incorrect time"))
	}

	// is this block too early? Allowable error = error_time
	if !first {

		sleepTime, err := p.GetSleepTime(p.BlockData.WalletId, p.BlockData.StateID, p.PrevBlock.StateID, p.PrevBlock.WalletId)
		if err != nil {
			return utils.ErrInfo(err)
		}

		log.Debug("p.PrevBlock.Time %v + sleepTime %v - p.BlockData.Time %v > consts.ERROR_TIME %v", p.PrevBlock.Time, sleepTime, p.BlockData.Time, consts.ERROR_TIME)
		if p.PrevBlock.Time+sleepTime-p.BlockData.Time > consts.ERROR_TIME {
			return utils.ErrInfo(fmt.Errorf("incorrect block time %d + %d - %d > %d", p.PrevBlock.Time, sleepTime, p.BlockData.Time, consts.ERROR_TIME))
		}
	}
	// exclude those, who generated block with the running clocks
	if p.BlockData.Time > time.Now().Unix() {
		utils.ErrInfo(fmt.Errorf("incorrect block time"))
	}

	// check the block ID
	if !utils.CheckInputData(p.BlockData.BlockId, "int") {
		return utils.ErrInfo(fmt.Errorf("incorrect block_id"))
	}

	// check if the ID of block is correct
	if !first {
		if p.BlockData.BlockId != p.PrevBlock.BlockId+1 {
			return utils.ErrInfo(fmt.Errorf("incorrect block_id %d != %d +1", p.BlockData.BlockId, p.PrevBlock.BlockId))
		}
	}
	// check if this miner exists and at the same time will receive public_key
	nodePublicKey, err := p.GetNodePublicKeyWalletOrCB(p.BlockData.WalletId, p.BlockData.StateID)
	if err != nil {
		return utils.ErrInfo(err)
	}
	if !first {
		if len(nodePublicKey) == 0 {
			return utils.ErrInfo(fmt.Errorf("empty nodePublicKey"))
		}
		// SIGN from 128 bites to 512 bites. Signature from TYPE, BLOCK_ID, PREV_BLOCK_HASH, TIME, USER_ID, LEVEL, MRKL_ROOT
		forSign := fmt.Sprintf("0,%d,%s,%d,%d,%d,%s", p.BlockData.BlockId, p.PrevBlock.Hash, p.BlockData.Time, p.BlockData.WalletId, p.BlockData.StateID, p.MrklRoot)
		log.Debug(forSign)
		// check the signature
		resultCheckSign, err := utils.CheckSign([][]byte{nodePublicKey}, forSign, p.BlockData.Sign, true)
		if err != nil {
			return utils.ErrInfo(fmt.Errorf("err: %v / p.PrevBlock.BlockId: %d", err, p.PrevBlock.BlockId))
		}
		if !resultCheckSign {
			return utils.ErrInfo(fmt.Errorf("incorrect signature / p.PrevBlock.BlockId: %d", p.PrevBlock.BlockId))
		}
	}
	return nil
}
