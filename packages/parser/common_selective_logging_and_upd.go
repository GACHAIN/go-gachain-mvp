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
	"encoding/json"
	"fmt"
	"strings"

	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

// selectiveLoggingAndUpd changes DB and writes all DB changes for rollbacks
// Do not use for comments
func (p *Parser) selectiveLoggingAndUpd(fields []string, ivalues []interface{}, table string, whereFields, whereValues []string, generalRollback bool) (string, error) {
	var (
		tableID  string
		isCustom bool
		err      error
	)

	if generalRollback && p.BlockData == nil {
		return ``, fmt.Errorf(`It is impossible to write to DB when Block is undefined`)
	}

	isBytea := getBytea(table)
	if isCustom, err = p.IsCustomTable(table); err != nil {
		return ``, err
	}

	for i, v := range ivalues {
		if len(fields) > i && isBytea[fields[i]] {
			var vlen int
			switch v.(type) {
			case []byte:
				vlen = len(v.([]byte))
			case string:
				if vbyte, err := hex.DecodeString(v.(string)); err == nil {
					ivalues[i] = vbyte
					vlen = len(vbyte)
				} else {
					vlen = len(v.(string))
				}
			}
			if isCustom && vlen > 128 {
				return ``, fmt.Errorf(`hash value cannot be larger than 128 bytes`)
			}
		}
	}

	values := utils.InterfaceSliceToStr(ivalues)

	addSQLFields := p.AllPkeys[table]
	if len(addSQLFields) > 0 {
		addSQLFields += `,`
	}
	log.Debug("addSQLFields %s", addSQLFields)
	for i, field := range fields {
		/*if p.AllPkeys[table] == field {
			continue
		}*/
		field = strings.TrimSpace(field)
		fields[i] = field
		if field[:1] == "+" || field[:1] == "-" {
			addSQLFields += field[1:len(field)] + ","
		} else if strings.HasPrefix(field, `timestamp `) {
			addSQLFields += field[len(`timestamp `):] + `,`
		} else {
			addSQLFields += field + ","
		}
	}
	log.Debug("addSQLFields %s", addSQLFields)

	addSQLWhere := ""
	if whereFields != nil && whereValues != nil {
		for i := 0; i < len(whereFields); i++ {
			addSQLWhere += whereFields[i] + "= '" + whereValues[i] + "' AND "
		}
	}
	if len(addSQLWhere) > 0 {
		addSQLWhere = " WHERE " + addSQLWhere[0:len(addSQLWhere)-5]
	}
	// If there is something to log
	logData, err := p.OneRow(`SELECT ` + addSQLFields + ` rb_id FROM "` + table + `" ` + addSQLWhere).String()
	if err != nil {
		return tableID, err
	}
	log.Debug(`SELECT ` + addSQLFields + ` rb_id FROM "` + table + `" ` + addSQLWhere)
	if whereFields != nil && len(logData) > 0 {
		/*if whereFields != nil {
			if len(logData) == 0 {
			return tableID, fmt.Errorf(`update of the unknown record`)
		}*/
		jsonMap := make(map[string]string)
		for k, v := range logData {
			if k == p.AllPkeys[table] {
				continue
			}
			if (isBytea[k] || utils.InSliceString(k, []string{"hash", "tx_hash", "public_key_0", "node_public_key"})) && v != "" {
				jsonMap[k] = string(utils.BinToHex([]byte(v)))
			} else {
				jsonMap[k] = v
			}
			if k == "rb_id" {
				k = "prev_rb_id"
			}
			if k[:1] == "+" || k[:1] == "-" {
				addSQLFields += k[1:len(k)] + ","
			} else if strings.HasPrefix(k, `timestamp `) {
				addSQLFields += k[len(`timestamp `):] + `,`
			} else {
				addSQLFields += k + ","
			}
		}
		jsonData, _ := json.Marshal(jsonMap)
		if err != nil {
			return tableID, err
		}
		rbID, err := p.ExecSQLGetLastInsertID("INSERT INTO rollback ( data, block_id ) VALUES ( ?, ? )", "rollback", string(jsonData), p.BlockData.BlockId)
		if err != nil {
			return tableID, err
		}
		log.Debug("string(jsonData) %s / rbID %d", string(jsonData), rbID)
		addSQLUpdate := ""
		for i := 0; i < len(fields); i++ {
			// utils.InSliceString(fields[i], []string{"hash", "tx_hash", "public_key", "public_key_0", "public_key_1", "public_key_2", "node_public_key"}
			if isBytea[fields[i]] && len(values[i]) != 0 {
				addSQLUpdate += fields[i] + `=decode('` + hex.EncodeToString([]byte(values[i])) + `','HEX'),`
			} else if fields[i][:1] == "+" {
				addSQLUpdate += fields[i][1:len(fields[i])] + `=` + fields[i][1:len(fields[i])] + `+` + values[i] + `,`
			} else if fields[i][:1] == "-" {
				addSQLUpdate += fields[i][1:len(fields[i])] + `=` + fields[i][1:len(fields[i])] + `-` + values[i] + `,`
			} else if values[i] == `NULL` {
				addSQLUpdate += fields[i] + `= NULL,`
			} else if strings.HasPrefix(fields[i], `timestamp `) {
				addSQLUpdate += fields[i][len(`timestamp `):] + `= to_timestamp('` + values[i] + `'),`
			} else if strings.HasPrefix(values[i], `timestamp `) {
				addSQLUpdate += fields[i] + `= timestamp '` + values[i][len(`timestamp `):] + `',`
			} else {
				addSQLUpdate += fields[i] + `='` + strings.Replace(values[i], `'`, `''`, -1) + `',`
			}
		}
		err = p.ExecSQL(`UPDATE "`+table+`" SET `+addSQLUpdate+` rb_id = ? `+addSQLWhere, rbID)
		log.Debug(`UPDATE "` + table + `" SET ` + addSQLUpdate + ` rb_id = ? ` + addSQLWhere)
		//log.Debug("logId", logId)
		if err != nil {
			return tableID, err
		}
		tableID = logData[p.AllPkeys[table]]
	} else {
		addSQLIns0 := ""
		addSQLIns1 := ""
		for i := 0; i < len(fields); i++ {
			if fields[i][:1] == "+" || fields[i][:1] == "-" {
				addSQLIns0 += fields[i][1:len(fields[i])] + `,`
			} else if strings.HasPrefix(fields[i], `timestamp `) {
				addSQLIns0 += fields[i][len(`timestamp `):] + `,`
			} else {
				addSQLIns0 += fields[i] + `,`
			}
			// || utils.InSliceString(fields[i], []string{"hash", "tx_hash", "public_key", "public_key_0", "node_public_key"}))
			if isBytea[fields[i]] && len(values[i]) != 0 {
				addSQLIns1 += `decode('` + hex.EncodeToString([]byte(values[i])) + `','HEX'),`
			} else if values[i] == `NULL` {
				addSQLIns1 += `NULL,`
			} else if strings.HasPrefix(fields[i], `timestamp `) {
				addSQLIns1 += `to_timestamp('` + values[i] + `'),`
			} else if strings.HasPrefix(values[i], `timestamp `) {
				addSQLIns1 += `timestamp '` + values[i][len(`timestamp `):] + `',`
			} else {
				addSQLIns1 += `'` + strings.Replace(values[i], `'`, `''`, -1) + `',`
			}
		}
		if whereFields != nil && whereValues != nil {
			for i := 0; i < len(whereFields); i++ {
				addSQLIns0 += `` + whereFields[i] + `,`
				addSQLIns1 += `'` + whereValues[i] + `',`
			}
		}
		addSQLIns0 = addSQLIns0[0 : len(addSQLIns0)-1]
		addSQLIns1 = addSQLIns1[0 : len(addSQLIns1)-1]
		//		fmt.Println(`Sel Log`, "INSERT INTO "+table+" ("+addSQLIns0+") VALUES ("+addSQLIns1+")")
		tableID, err = p.ExecSQLGetLastInsertID(`INSERT INTO "`+table+`" (`+addSQLIns0+`) VALUES (`+addSQLIns1+`)`, table)
		if err != nil {
			return tableID, err
		}
	}
	if generalRollback {
		err = p.ExecSQL("INSERT INTO rollback_tx ( block_id, tx_hash, table_name, table_id ) VALUES (?, [hex], ?, ?)", p.BlockData.BlockId, p.TxHash, table, tableID)
		if err != nil {
			return tableID, err
		}
	}
	return tableID, nil
}
