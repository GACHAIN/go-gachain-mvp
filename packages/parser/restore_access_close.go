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

	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

// RestoreAccessCloseInit initializes RestoreAccessClose transaction
func (p *Parser) RestoreAccessCloseInit() error {

	fields := []map[string]string{{"sign": "bytes"}}
	err := p.GetTxMaps(fields)
	if err != nil {
		return p.ErrInfo(err)
	}
	return nil
}

// RestoreAccessCloseFront checks conditions of RestoreAccessClose transaction
func (p *Parser) RestoreAccessCloseFront() error {
	err := p.generalCheck(`system_restore_access_close`)
	if err != nil {
		return p.ErrInfo(err)
	}

	// check whether or not already close
	close, err := p.Single("SELECT close FROM system_restore_access WHERE user_id  =  ? AND state_id = ?", p.TxUserID, p.TxUserID).Int64()
	if err != nil {
		return p.ErrInfo(err)
	}
	if close > 0 {
		return p.ErrInfo("close=1")
	}

	forSign := fmt.Sprintf("%s,%s,%d,%d", p.TxMap["type"], p.TxMap["time"], p.TxCitizenID, p.TxStateID)
	CheckSignResult, err := utils.CheckSign(p.PublicKeys, forSign, p.TxMap["sign"], false)
	if err != nil {
		return p.ErrInfo(err)
	}
	if !CheckSignResult {
		return p.ErrInfo("incorrect sign")
	}
	if err = p.AccessRights(`restore_access_condition`, false); err != nil {
		return p.ErrInfo(err)
	}
	return nil
}

// RestoreAccessClose proceeds RestoreAccessClose transaction
func (p *Parser) RestoreAccessClose() error {
	_, err := p.selectiveLoggingAndUpd([]string{"close"}, []interface{}{"1"}, "system_restore_access", []string{"state_id"}, []string{utils.UInt32ToStr(p.TxStateID)}, true)
	if err != nil {
		return p.ErrInfo(err)
	}
	return nil
}

// RestoreAccessCloseRollback rollbacks RestoreAccessClose transaction
func (p *Parser) RestoreAccessCloseRollback() error {
	return p.autoRollback()
}
