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
	//"encoding/json"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/GACHAIN/go-gachain-mvp/packages/lib"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

// EditColumnInit initializes EditColumn transaction
func (p *Parser) EditColumnInit() error {

	fields := []map[string]string{{"table_name": "string"}, {"column_name": "string"}, {"permissions": "string"}, {"sign": "bytes"}}
	err := p.GetTxMaps(fields)
	if err != nil {
		return p.ErrInfo(err)
	}
	return nil
}

// EditColumnFront checks conditions of EditColumn transaction
func (p *Parser) EditColumnFront() error {
	err := p.generalCheck(`edit_column`)
	if err != nil {
		fmt.Printf("&&& generalCheck %s\n", err)
		//return p.ErrInfo(err)
	}

	// Check InputData
	/*verifyData := map[string]string{"table_name": "string", "column_name": "word", "permissions": "string"}
	err = p.CheckInputData(verifyData)
	if err != nil {
		return p.ErrInfo(err)
	}*/

	table := p.TxStateIDStr + `_tables`
	if strings.HasPrefix(p.TxMaps.String["table_name"], `global`) {
		table = `global_tables`
	}
	exists, err := p.Single(`select count(*) from "`+table+`" where (columns_and_permissions->'update'-> ? ) is not null AND name = ?`, p.TxMaps.String["column_name"], p.TxMaps.String["table_name"]).Int64()
	if err != nil {
		fmt.Printf("&&& Single %s\n", err)
		//return p.ErrInfo(err)
	}
	if exists == 0 {
		fmt.Printf("&&& exists %s\n", err)
		//return p.ErrInfo(`column not exists`)
	}

	forSign := fmt.Sprintf("%s,%s,%d,%d,%s,%s,%s", p.TxMap["type"], p.TxMap["time"], p.TxCitizenID, p.TxStateID, p.TxMap["table_name"], p.TxMap["column_name"], p.TxMap["permissions"])
	CheckSignResult, err := utils.CheckSign(p.PublicKeys, forSign, p.TxMap["sign"], false)
	if err != nil {
		fmt.Printf("&&& CheckSign %s\n", err)
		//return p.ErrInfo(err)
	}
	if !CheckSignResult {
		fmt.Printf("&&& CheckSignResult %s\n", err)
		//return p.ErrInfo("incorrect sign")
	}
	if err = p.AccessTable(p.TxMaps.String["table_name"], `general_update`); err != nil {
		fmt.Printf("&&& AccessTable %s\n", err)
		//return err
	}

	return nil
}

// EditColumn proceeds EditColumn transaction
func (p *Parser) EditColumn() error {

	table := p.TxStateIDStr + `_tables`
	if strings.HasPrefix(p.TxMaps.String["table_name"], `global`) {
		table = `global_tables`
	}
	logData, err := p.OneRow(`SELECT columns_and_permissions, rb_id FROM "`+table+`" where (columns_and_permissions->'update'-> ? ) is not null AND name = ?`,
		p.TxMaps.String["column_name"], p.TxMaps.String["table_name"]).String()
	if err != nil {
		return err
	}

	jsonMap := make(map[string]string)
	for k, v := range logData {
		if k == p.AllPkeys[table] {
			continue
		}
		jsonMap[k] = v
		if k == "rb_id" {
			k = "prev_rb_id"
		}
	}
	jsonData, _ := json.Marshal(jsonMap)
	if err != nil {
		return err
	}
	rbID, err := p.ExecSQLGetLastInsertID("INSERT INTO rollback ( data, block_id ) VALUES ( ?, ? )", "rollback", string(jsonData), p.BlockData.BlockId)
	if err != nil {
		return err
	}
	err = p.ExecSQL(`UPDATE "`+table+`" SET columns_and_permissions = jsonb_set(columns_and_permissions, '{update, `+p.TxMaps.String["column_name"]+`}', ?, true), rb_id = ? WHERE name = ?`,
		`"`+lib.EscapeForJSON(p.TxMaps.String["permissions"])+`"`, rbID, p.TxMaps.String["table_name"])
	if err != nil {
		return p.ErrInfo(err)
	}

	err = p.ExecSQL("INSERT INTO rollback_tx ( block_id, tx_hash, table_name, table_id ) VALUES (?, [hex], ?, ?)", p.BlockData.BlockId, p.TxHash, table, p.TxMaps.String["table_name"])
	if err != nil {
		return err
	}

	return nil
}

// EditColumnRollback rollbacks EditColumn transaction
func (p *Parser) EditColumnRollback() error {
	err := p.autoRollback()
	if err != nil {
		return err
	}
	return nil
}

/*func (p *Parser) EditColumnRollbackFront() error {

	return nil
}
*/
