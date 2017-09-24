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

package schema

import (
	"github.com/GACHAIN/go-gachain-mvp/packages/consts"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
	"github.com/op/go-logging"
)
var (
	log = logging.MustGetLogger("daemons")
)
func Migration() {
	oldDbVersion, err := utils.DB.Single(`SELECT version FROM migration_history ORDER BY id DESC LIMIT 1`).String()
	if err != nil {
		log.Error("%v", utils.ErrInfo(err))
	}
	if len(*utils.OldVersion) == 0 && consts.VERSION != oldDbVersion {
		*utils.OldVersion = oldDbVersion
	}

	log.Debug("*utils.OldVersion %v", *utils.OldVersion)
	if len(*utils.OldVersion) > 0 {

		err = utils.DB.ExecSQL(`INSERT INTO migration_history (version, date_applied) VALUES (?, ?)`, consts.VERSION, utils.Time())
		if err != nil {
			log.Error("%v", utils.ErrInfo(err))
		}
	}
}

