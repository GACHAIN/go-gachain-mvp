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

	"github.com/GACHAIN/go-gachain-mvp/packages/smart"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

/*
Adding state tables should be spelled out in state settings
*/

// NewStateParametersInit initializes NewStateParameters transaction
func (p *Parser) NewStateParametersInit() error {

	fields := []map[string]string{{"name": "string"}, {"value": "string"}, {"conditions": "string"}, {"sign": "bytes"}}
	err := p.GetTxMaps(fields)
	if err != nil {
		return p.ErrInfo(err)
	}
	return nil
}

// NewStateParametersFront checks conditions of NewStateParameters transaction
func (p *Parser) NewStateParametersFront() error {
	err := p.generalCheck(`new_state_parameters`)
	if err != nil {
		fmt.Printf("--- CheckSign %s\n", err)
		//return p.ErrInfo(err)
	}

	// Check the system limits. You can not send more than X time a day this TX
	// ...

	/*
		// Check InputData
		verifyData := map[string]string{}
		err = p.CheckInputData(verifyData)
		if err != nil {
			return p.ErrInfo(err)
		}
	*/

	/*// Check the condition that must be met to complete this transaction
	conditions, err := p.Single(`SELECT change FROM `+utils.Int64ToStr(p.TxMaps.Int64["state_id"])+`_state_parameters WHERE parameter = ?`, p.TxMaps.String["parameter"]).String()
	if err != nil {
		return p.ErrInfo(err)
	}

	vars := map[string]interface{}{
		`citizenId`: 	p.TxCitizenID,
		`walletId`: 	p.TxWalletID,
		`Table`:     	p.MyTable,
	}
	out, err := script.EvalIf(conditions, &vars)
	if err != nil {
		return p.ErrInfo(err)
	}
	if !out {
		return p.ErrInfo("conditions false")
	}

	// Checking new condition
	vars = map[string]interface{}{
		`citizenId`: 	p.TxCitizenID,
		`walletId`: 	p.TxWalletID,
		`Table`:     	p.MyTableChecking,
	}
	out, err = script.EvalIf(p.TxMaps.String["conditions"], &vars)
	if err != nil {
		return p.ErrInfo(err)
	}
	if !out {
		return p.ErrInfo("conditions false")
	}
	*/
	if len(p.TxMap["conditions"]) > 0 {
		if err := smart.CompileEval(string(p.TxMap["conditions"]), uint32(p.TxStateID)); err != nil {
			fmt.Printf("--- CompileEval %s\n", err)
			//return p.ErrInfo(err)
		}
	}
	// must be supplemented
	forSign := fmt.Sprintf("%s,%s,%d,%d,%s,%s,%s", p.TxMap["type"], p.TxMap["time"], p.TxCitizenID, p.TxStateID, p.TxMap["name"], p.TxMap["value"], p.TxMap["conditions"])
	CheckSignResult, err := utils.CheckSign(p.PublicKeys, forSign, p.TxMap["sign"], false)
	if err != nil {
		fmt.Printf("--- CheckSign %s\n", err)
		//return p.ErrInfo(err)
	}
	if !CheckSignResult {
		fmt.Printf("--- CheckSignResult %s\n", err)
		//return p.ErrInfo("incorrect sign")
	}

	return nil
}

// NewStateParameters proceeds NewStateParameters transaction
func (p *Parser) NewStateParameters() error {

	_, err := p.selectiveLoggingAndUpd([]string{"name", "value", "conditions"}, []interface{}{p.TxMaps.String["name"], p.TxMaps.String["value"], p.TxMaps.String["conditions"]}, p.TxStateIDStr+"_state_parameters", nil, nil, true)
	if err != nil {
		return p.ErrInfo(err)
	}
	return nil
}

// NewStateParametersRollback rollbacks NewStateParameters transaction
func (p *Parser) NewStateParametersRollback() error {
	return p.autoRollback()
}


