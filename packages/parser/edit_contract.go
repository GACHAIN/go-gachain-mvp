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
	"github.com/GACHAIN/go-gachain-mvp/packages/script"
	"github.com/GACHAIN/go-gachain-mvp/packages/smart"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

// EditContractInit initializes EditContract transaction
func (p *Parser) EditContractInit() error {

	fields := []map[string]string{{"global": "int64"}, {"id": "string"}, {"value": "string"}, {"conditions": "string"}, {"sign": "bytes"}}
	err := p.GetTxMaps(fields)
	if err != nil {
		return p.ErrInfo(err)
	}
	return nil
}

// EditContractFront checks conditions of EditContract transaction
func (p *Parser) EditContractFront() error {

	err := p.generalCheck(`edit_contract`)
	if err != nil {
		return p.ErrInfo(err)
	}

	// Check the system limits. You can not send more than X time a day this TX
	// ...

	// Check InputData
	verifyData := map[string]string{}
	err = p.CheckInputData(verifyData)
	if err != nil {
		return p.ErrInfo(err)
	}

	// must be supplemented
	forSign := fmt.Sprintf("%s,%s,%d,%d,%s,%s,%s,%s", p.TxMap["type"], p.TxMap["time"], p.TxCitizenID, p.TxStateID, p.TxMap["global"], p.TxMap["id"], p.TxMap["value"], p.TxMap["conditions"])
	CheckSignResult, err := utils.CheckSign(p.PublicKeys, forSign, p.TxMap["sign"], false)
	if err != nil {
		return p.ErrInfo(err)
	}
	if !CheckSignResult {
		return p.ErrInfo("incorrect sign")
	}
	prefix := `global`
	if p.TxMaps.Int64["global"] == 0 {
		prefix = p.TxStateIDStr
	}
	//	prefix := utils.Int64ToStr(int64(p.TxStateID))
	if len(p.TxMap["conditions"]) > 0 {
		if err := smart.CompileEval(string(p.TxMap["conditions"]), uint32(p.TxStateID)); err != nil {
			return p.ErrInfo(err)
		}
	}
	conditions, err := p.Single(`SELECT conditions FROM "`+prefix+`_smart_contracts" WHERE id = ?`, p.TxMaps.String["id"]).String()
	if err != nil {
		return p.ErrInfo(err)
	}
	if len(conditions) > 0 {
		ret, err := p.EvalIf(conditions)
		if err != nil {
			return err
		}
		if !ret {
			if err = p.AccessRights(`changing_smart_contracts`, false); err != nil {
				return err
			}
		}
	}

	return nil
}

// EditContract proceeds EditContract transaction
func (p *Parser) EditContract() error {

	prefix := `global`
	if p.TxMaps.Int64["global"] == 0 {
		prefix = p.TxStateIDStr
	}
	item, err := p.OneRow(`SELECT id, active FROM "`+prefix+`_smart_contracts" WHERE id = ?`, p.TxMaps.String["id"]).String()
	if err != nil {
		return p.ErrInfo(err)
	}
	tblid := utils.StrToInt64(item[`id`])
	active := item[`active`] == `1`
	root, err := smart.CompileBlock(p.TxMaps.String["value"], prefix, false, utils.StrToInt64(p.TxMaps.String["id"]))
	if err != nil {
		return p.ErrInfo(err)
	}

	_, err = p.selectiveLoggingAndUpd([]string{"value", "conditions"}, []interface{}{p.TxMaps.String["value"], p.TxMaps.String["conditions"]}, prefix+"_smart_contracts", []string{"id"}, []string{p.TxMaps.String["id"]}, true)
	if err != nil {
		return p.ErrInfo(err)
	}
	for i, item := range root.Children {
		if item.Type == script.ObjContract {
			root.Children[i].Info.(*script.ContractInfo).TableID = tblid
			root.Children[i].Info.(*script.ContractInfo).Active = active
		}
	}
	smart.FlushBlock(root)
	return nil
}

// EditContractRollback rollbacks EditContract transaction
func (p *Parser) EditContractRollback() error {
	return p.autoRollback()
}
