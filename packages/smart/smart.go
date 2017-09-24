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

package smart

import (
	"encoding/hex"
	"fmt"
	"strconv"
	"strings"

	"github.com/GACHAIN/go-gachain-mvp/packages/script"
)

// Contract contains the information about the contract.
type Contract struct {
	Name          string
	Called        uint32
	FreeRequest   bool
	TxPrice       int64   // custom price for citizens
	TxGovAccount  int64   // state wallet
	EGSRate       float64 // money/EGS rate
	TableAccounts string
	StackCont     []string // Stack of called contracts
	Extend        *map[string]interface{}
	Block         *script.Block
}

const (
	// CallInit is a flag for calling init function of the contract
	CallInit = 0x01
	// CallCondition is a flag for calling condition function of the contract
	CallCondition = 0x02
	// CallAction is a flag for calling action function of the contract
	CallAction = 0x04
	// CallRollback is a flag for calling rollback function of the contract
	CallRollback = 0x08
)

var (
	smartVM *script.VM
)

func init() {
	smartVM = script.NewVM()
	smartVM.Extern = true
	smartVM.Extend(&script.ExtendData{Objects: map[string]interface{}{
		"Println": fmt.Println,
		"Sprintf": fmt.Sprintf,
		"TxJson":  TxJSON,
		"Float":   Float,
		"Money":   script.ValueToDecimal,
	}, AutoPars: map[string]string{
		`*smart.Contract`: `contract`,
	}})
}

func pref2state(prefix string) (state uint32) {
	if prefix != `global` {
		if val, err := strconv.ParseUint(prefix, 10, 32); err == nil {
			state = uint32(val)
		}
	}
	return
}

// ExternOff switches off the extern compiling mode in smartVM
func ExternOff() {
	smartVM.FlushExtern()
}

// Compile compiles contract source code in smartVM
func Compile(src, prefix string, active bool, tblid int64) error {
	return smartVM.Compile([]rune(src), pref2state(prefix), active, tblid)
}

// CompileBlock calls CompileBlock for smartVM
func CompileBlock(src, prefix string, active bool, tblid int64) (*script.Block, error) {
	return smartVM.CompileBlock([]rune(src), pref2state(prefix), active, tblid)
}

// CompileEval calls CompileEval for smartVM
func CompileEval(src string, prefix uint32) error {
	return smartVM.CompileEval(src, prefix)
}

// EvalIf calls EvalIf for smartVM
func EvalIf(src, prefix string, extend *map[string]interface{}) (bool, error) {
	return smartVM.EvalIf(src, pref2state(prefix), extend)
}

// FlushBlock calls FlushBlock for smartVM
func FlushBlock(root *script.Block) {
	smartVM.FlushBlock(root)
}

// ExtendCost sets the cost of calling extended obj in smartVM
func ExtendCost(ext func(string) int64) {
	smartVM.ExtCost = ext
}

// Extend set extendeds variable and functions in smartVM
func Extend(ext *script.ExtendData) {
	smartVM.Extend(ext)
}

// Run executes Block in smartVM
func Run(block *script.Block, params []interface{}, extend *map[string]interface{}) (ret []interface{}, err error) {
	var extcost int64
	cost := script.CostDefault
	if ecost, ok := (*extend)[`txcost`]; ok {
		cost = ecost.(int64)
	}
	rt := smartVM.RunInit(cost)
	ret, err = rt.Run(block, params, extend)
	if ecost, ok := (*extend)[`txcost`]; ok && cost > ecost.(int64) {
		extcost = cost - ecost.(int64)
	}
	(*extend)[`txcost`] = rt.Cost() - extcost
	return
}

// ActivateContract sets Active status of the contract in smartVM
func ActivateContract(tblid int64, prefix string, active bool) {
	if prefix == `global` {
		prefix = `0`
	}
	for i, item := range smartVM.Block.Children {
		if item != nil && item.Type == script.ObjContract {
			cinfo := item.Info.(*script.ContractInfo)
			if cinfo.TableID == tblid && strings.HasPrefix(cinfo.Name, `@`+prefix) &&
				(len(cinfo.Name) > len(prefix)+1 && cinfo.Name[len(prefix)+1] > '9') {
				smartVM.Children[i].Info.(*script.ContractInfo).Active = active
			}
		}
	}
}

// GetContract returns true if the contract exists in smartVM
func GetContract(name string, state uint32) *Contract {
	name = script.StateName(state, name)
	obj, ok := smartVM.Objects[name]
	if ok && obj.Type == script.ObjContract {
		return &Contract{Name: name, Block: obj.Value.(*script.Block)}
	}
	return nil
}

// GetUsedContracts returns the list of contracts which are called from the specified contract
func GetUsedContracts(name string, state uint32, full bool) []string {
	contract := GetContract(name, state)
	if contract == nil || contract.Block.Info.(*script.ContractInfo).Used == nil {
		return nil
	}
	ret := make([]string, 0)
	used := make(map[string]bool)
	for key := range contract.Block.Info.(*script.ContractInfo).Used {
		ret = append(ret, key)
		used[key] = true
		if full {
			sub := GetUsedContracts(key, state, full)
			for _, item := range sub {
				if _, ok := used[item]; !ok {
					ret = append(ret, item)
					used[item] = true
				}
			}
		}
	}
	return ret
}

// GetContractByID returns true if the contract exists
func GetContractByID(id int32) *Contract {
	idcont := id // - CNTOFF
	if len(smartVM.Children) <= int(idcont) || smartVM.Children[idcont].Type != script.ObjContract {
		return nil
	}
	return &Contract{Name: smartVM.Children[idcont].Info.(*script.ContractInfo).Name,
		Block: smartVM.Children[idcont]}
}

// GetFunc returns the block of the specified function in the contract
func (contract *Contract) GetFunc(name string) *script.Block {
	if block, ok := (*contract).Block.Objects[name]; ok && block.Type == script.ObjFunc {
		return block.Value.(*script.Block)
	}
	return nil
}

// TxJSON returns JSON data which has been generated from Tx data and extended variables
func TxJSON(contract *Contract) string {
	lines := make([]string, 0)
	for _, fitem := range *(*contract).Block.Info.(*script.ContractInfo).Tx {
		switch fitem.Type.String() {
		case `string`:
			lines = append(lines, fmt.Sprintf(`"%s": "%s"`, fitem.Name, (*(*contract).Extend)[fitem.Name]))
		case `int64`:
			lines = append(lines, fmt.Sprintf(`"%s": %d`, fitem.Name, (*(*contract).Extend)[fitem.Name]))
		case `[]uint8`:
			lines = append(lines, fmt.Sprintf(`"%s": "%s"`, fitem.Name,
				hex.EncodeToString((*(*contract).Extend)[fitem.Name].([]byte))))
		}
	}
	return `{` + strings.Join(lines, ",\r\n") + `}`
}

// Float converts int64, string to float64
func Float(v interface{}) (ret float64) {
	switch value := v.(type) {
	case int64:
		ret = float64(value)
	case string:
		if val, err := strconv.ParseFloat(value, 64); err == nil {
			ret = val
		}
	}
	return
}
