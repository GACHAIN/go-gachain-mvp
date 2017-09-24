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

package controllers

import (
	"fmt"

	"github.com/GACHAIN/go-gachain-mvp/packages/lib"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

const aHistory = `ajax_history`

// HistoryJSON is a structure for the answer of ajax_history ajax request
type HistoryJSON struct {
	Draw     int                 `json:"draw"`
	Total    int                 `json:"recordsTotal"`
	Filtered int                 `json:"recordsFiltered"`
	Data     []map[string]string `json:"data"`
	Error    string              `json:"error"`
}

func init() {
	newPage(aHistory, `json`)
}

// AjaxHistory is a controller of ajax_history request
func (c *Controller) AjaxHistory() interface{} {
	var (
		history []map[string]string
		err     error
	)
	walletID := c.SessWalletID
	result := HistoryJSON{Draw: utils.StrToInt(c.r.FormValue("draw"))}
	length := utils.StrToInt(c.r.FormValue("length"))
	if length == -1 {
		length = 20
	}
	log.Debug("a/h walletId %s / c.SessAddress %s", walletID, c.SessAddress)
	limit := fmt.Sprintf(`LIMIT %d OFFSET %d`, length, utils.StrToInt(c.r.FormValue("start")))
	if walletID != 0 {
		total, _ := c.Single(`SELECT count(id) FROM dlt_transactions where sender_wallet_id = ? OR
		                       recipient_wallet_id = ? OR recipient_wallet_address = ?`, walletID, walletID, c.SessAddress).Int64()
		result.Total = int(total)
		result.Filtered = int(total)
		if length != 0 {
			history, err = c.GetAll(`SELECT d.*, w.wallet_id as sw, wr.wallet_id as rw FROM dlt_transactions as d
		        left join dlt_wallets as w on w.wallet_id=d.sender_wallet_id
		        left join dlt_wallets as wr on wr.wallet_id=d.recipient_wallet_id
				where sender_wallet_id=? OR 
		        recipient_wallet_id=?  OR
		        recipient_wallet_address=? order by d.id desc  `+limit, -1, walletID, walletID, c.SessAddress)
			if err != nil {
				log.Error("%s", err)
			}
			for ind := range history {
				max, _ := c.Single(`select max(id) from block_chain`).Int64()
				history[ind][`confirm`] = utils.Int64ToStr(max - utils.StrToInt64(history[ind][`block_id`]))
				history[ind][`sender_address`] = lib.AddressToString(utils.StrToInt64(history[ind][`sw`]))
				recipient := history[ind][`rw`]
				if len(recipient) < 10 {
					recipient = history[ind][`recipient_wallet_address`]
				}
				history[ind][`recipient_address`] = lib.AddressToString(lib.StringToAddress(recipient))
			}
		}
	}
	if err != nil {
		result.Error = err.Error()
	} else {
		if history == nil {
			history = []map[string]string{}
		}
		result.Data = history
	}
	return result
}
