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
	"encoding/hex"
	"fmt"

	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

// NewAccountInit initializes NewAccount transaction
func (p *Parser) NewAccountInit() error {

	fields := []map[string]string{{"pub": "bytes"}, {"sign": "bytes"}}
	err := p.GetTxMaps(fields)
	if err != nil {
		return p.ErrInfo(err)
	}
	return nil
}

// NewAccountFront checks conditions of NewAccount transaction
func (p *Parser) NewAccountFront() error {
	p.PublicKeys = append(p.PublicKeys, p.TxMaps.Bytes["pub"])
	forSign := fmt.Sprintf("%s,%s,%d,%d,%s", p.TxMap["type"], p.TxMap["time"], p.TxCitizenID,
		p.TxStateID, hex.EncodeToString(p.TxMaps.Bytes["pub"]))
	CheckSignResult, err := utils.CheckSign(p.PublicKeys, forSign, p.TxMap["sign"], false)
	if err != nil {
		return p.ErrInfo(err)
	}
	if !CheckSignResult {
		return p.ErrInfo("incorrect sign")
	}

	return nil
}

// NewAccount proceeds NewAccount transaction
func (p *Parser) NewAccount() error {

	_, err := p.selectiveLoggingAndUpd([]string{"public_key_0"}, []interface{}{hex.EncodeToString(p.TxMaps.Bytes["pub"])},
		"dlt_wallets", []string{"wallet_id"}, []string{utils.Int64ToStr(p.TxCitizenID)}, true)
	if err != nil {
		return p.ErrInfo(err)
	}
	_, err = p.selectiveLoggingAndUpd([]string{"citizen_id", "amount"}, []interface{}{p.TxCitizenID, 0},
		p.TxStateIDStr+"_accounts", nil, nil, true)
	if err != nil {
		return p.ErrInfo(err)
	}
	return nil
}

// NewAccountRollback rollbacks NewAccount transaction
func (p *Parser) NewAccountRollback() error {
	return p.autoRollback()
}
