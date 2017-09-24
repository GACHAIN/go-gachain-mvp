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
	"github.com/GACHAIN/go-gachain-mvp/packages/lib"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

// Roll back the ID to the number of affected rows
func (p *Parser) rollbackAI(table string, num int64) error {

	if num == 0 {
		return nil
	}

	AiID, err := p.GetAiID(table)
	if err != nil {
		return utils.ErrInfo(err)
	}
	tblname := lib.EscapeName(table)
	log.Debug("AiID: %s", AiID)
	// If the table was cleaned up, then 0 appears, that's why we can not clean the tables to zero
	current, err := p.Single("SELECT " + AiID + " FROM " + tblname + " ORDER BY " + AiID + " DESC LIMIT 1").Int64()
	if err != nil {
		return utils.ErrInfo(err)
	}
	NewAi := current + num
	log.Debug("NewAi: %d", NewAi)

	if p.ConfigIni["db_type"] == "postgresql" {
		pgSerialSeq, err := p.Single("SELECT pg_get_serial_sequence('" + table + "', '" + AiID + "')").String()
		if err != nil {
			return utils.ErrInfo(err)
		}
		err = p.ExecSQL("ALTER SEQUENCE " + pgSerialSeq + " RESTART WITH " + utils.Int64ToStr(NewAi))
		if err != nil {
			return utils.ErrInfo(err)
		}
	} else if p.ConfigIni["db_type"] == "mysql" {
		err := p.ExecSQL("ALTER TABLE " + tblname + " AUTO_INCREMENT = " + utils.Int64ToStr(NewAi))
		if err != nil {
			return utils.ErrInfo(err)
		}
	} else if p.ConfigIni["db_type"] == "sqlite" {
		NewAi--
		err := p.ExecSQL("UPDATE SQLITE_SEQUENCE SET seq = ? WHERE name = ?", NewAi, table)
		if err != nil {
			return utils.ErrInfo(err)
		}
	}
	return nil
}
