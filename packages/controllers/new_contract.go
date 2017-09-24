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
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

// NewContract is a handle function for creating contracts
func (c *Controller) NewContract() (string, error) {

	txType := "NewContract"
	global := c.r.FormValue("global")
	if global == "" || global == "0" {
		global = "0"
	}

	TemplateStr, err := makeTemplate("edit_contract", "editContract", &editContractPage{
		Alert:     c.Alert,
		Lang:      c.Lang,
		WalletID:  c.SessWalletID,
		CitizenID: c.SessCitizenID,
		TxType:    txType,
		TxTypeID:  utils.TypeInt(txType),
		Global:    global,
		Data:      map[string]string{`conditions`: "ContractConditions(`MainCondition`)"},
		StateID:   c.SessStateID})
	if err != nil {
		return "", utils.ErrInfo(err)
	}
	return TemplateStr, nil
}
