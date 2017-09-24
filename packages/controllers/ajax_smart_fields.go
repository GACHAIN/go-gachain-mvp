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
	"strings"

	"github.com/GACHAIN/go-gachain-mvp/packages/script"
	"github.com/GACHAIN/go-gachain-mvp/packages/smart"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

const aSmartFields = `ajax_smart_fields`

// SmartFieldsJSON is a structure for the answer of ajax_smart_fields ajax request
type SmartFieldsJSON struct {
	Fields   string `json:"fields"`
	Price    int64  `json:"price"`
	Valid    bool   `json:"valid"`
	Approved int64  `json:"approved"`
	Error    string `json:"error"`
}

func init() {
	newPage(aSmartFields, `json`)
}

// AjaxSmartFields is a controller of ajax_smart_fields request
func (c *Controller) AjaxSmartFields() interface{} {
	var (
		result SmartFieldsJSON
		err    error
		amount int64
		req    map[string]int64
	)
	stateID := utils.StrToInt64(c.r.FormValue(`state_id`))
	stateStr := utils.Int64ToStr(stateID)
	if !c.IsTable(stateStr+`_citizens`) || !c.IsTable(stateStr+`_citizenship_requests`) {
		result.Error = `Basic app is not installed`
		return result
	}
	//	_, err = c.GetStateName(stateID)
	//	if err == nil {
	if exist, err := c.Single(`select id from "`+stateStr+`_citizens" where id=?`, c.SessWalletID).Int64(); err != nil {
		result.Error = err.Error()
		return result
	} else if exist > 0 {
		result.Approved = 2
		return result
	}

	if req, err = c.OneRow(`select id, approved from "`+stateStr+`_citizenship_requests" where dlt_wallet_id=? order by id desc`,
		c.SessWalletID).Int64(); err == nil {
		if len(req) > 0 && req[`id`] > 0 {
			result.Approved = req[`approved`]
		} else {
			cntname := c.r.FormValue(`contract_name`)
			contract := smart.GetContract(cntname, uint32(stateID))
			if contract == nil || contract.Block.Info.(*script.ContractInfo).Tx == nil {
				err = fmt.Errorf(`there is not %s contract`, cntname)
			} else {
				fields := make([]string, 0)
			main:
				for _, fitem := range *(*contract).Block.Info.(*script.ContractInfo).Tx {
					if strings.Index(fitem.Tags, `hidden`) >= 0 {
						continue
					}
					for _, tag := range []string{`date`, `polymap`, `map`, `image`} {
						if strings.Index(fitem.Tags, tag) >= 0 {
							fields = append(fields, fmt.Sprintf(`{"name":"%s", "htmlType":"%s", "txType":"%s", "title":"%s"}`,
								fitem.Name, tag, fitem.Type.String(), fitem.Name))
							continue main
						}
					}
					if fitem.Type.String() == `string` || fitem.Type.String() == `int64` || fitem.Type.String() == script.Decimal {
						fields = append(fields, fmt.Sprintf(`{"name":"%s", "htmlType":"textinput", "txType":"%s", "title":"%s"}`,
							fitem.Name, fitem.Type.String(), fitem.Name))
					}
					/*					if fitem.Type.String() == `string` || fitem.Type.String() == `int64` || fitem.Type.String() == script.Decimal {
										fields = append(fields, fmt.Sprintf(`{"name":"%s", "htmlType":"textinput", "txType":"%s", "title":"%s"}`,
											fitem.Name, fitem.Type.String(), fitem.Name))
									}*/
				}
				result.Fields = fmt.Sprintf(`[%s]`, strings.Join(fields, `,`))

				if err == nil {
					result.Price, err = c.Single(`SELECT value FROM "` + utils.Int64ToStr(stateID) + `_state_parameters" where name='citizenship_price'`).Int64()
					if err == nil {
						amount, err = c.Single("select amount from dlt_wallets where wallet_id=?", c.SessWalletID).Int64()
						result.Valid = (err == nil && amount >= result.Price)
					}
				}

			}
		}
	}
	//	}
	if err != nil {
		result.Error = err.Error()
	}
	return result
}
