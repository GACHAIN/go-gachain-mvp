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
	"database/sql"
	"flag"
	"fmt"
	"os"
	"reflect"
	"strings"

	"github.com/GACHAIN/go-gachain-mvp/packages/consts"
	//	"github.com/GACHAIN/go-gachain-mvp/packages/lib"
	"github.com/GACHAIN/go-gachain-mvp/packages/script"
	"github.com/GACHAIN/go-gachain-mvp/packages/smart"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
	"github.com/op/go-logging"
	"github.com/shopspring/decimal"
)

var (
	log = logging.MustGetLogger("daemons")
)

func init() {
	flag.Parse()
}

type txMapsType struct {
	Int64   map[string]int64
	String  map[string]string
	Bytes   map[string][]byte
	Float64 map[string]float64
	Money   map[string]float64
	Decimal map[string]decimal.Decimal
}

// Parser is a structure for parsing transactions
type Parser struct {
	*utils.DCDB
	TxMaps           *txMapsType
	TxMap            map[string][]byte
	TxMapS           map[string]string
	TxIds            int // count of transactions
	TxMapArr         []map[string][]byte
	TxMapsArr        []*txMapsType
	BlockData        *utils.BlockData
	PrevBlock        *utils.BlockData
	BinaryData       []byte
	blockHashHex     []byte
	dataType         int
	blockHex         []byte
	CurrentBlockID   int64
	fullTxBinaryData []byte
	TxHash           string
	TxSlice          [][]byte
	MerkleRoot       []byte
	GoroutineName    string
	CurrentVersion   string
	MrklRoot         []byte
	PublicKeys       [][]byte
	TxUserID         int64
	TxCitizenID      int64
	TxWalletID       int64
	TxStateID        uint32
	TxStateIDStr     string
	TxTime           int64
	TxCost           int64           // Maximum cost of executing contract
	TxUsedCost       decimal.Decimal // Used cost of CPU resources
	nodePublicKey    []byte
	//	newPublicKeysHex [3][]byte
	TxPtr      interface{} // Pointer to the corresponding struct in consts/struct.go
	TxData     map[string]interface{}
	TxContract *smart.Contract
	TxVars     map[string]string
	AllPkeys   map[string]string
	States     map[int64]string
}

// ClearTmp deletes temporary files
func ClearTmp(blocks map[int64]string) {
	for _, tmpFileName := range blocks {
		os.Remove(tmpFileName)
	}
}

// GetBlockInfo returns BlockData structure
func (p *Parser) GetBlockInfo() *utils.BlockData {
	return &utils.BlockData{Hash: p.BlockData.Hash, Time: p.BlockData.Time, WalletId: p.BlockData.WalletId, StateID: p.BlockData.StateID, BlockId: p.BlockData.BlockId}
}

/*
func (p *Parser) limitRequest(vimit interface{}, txType string, vperiod interface{}) error {

	var limit int
	switch vimit.(type) {
	case string:
		limit = utils.StrToInt(vimit.(string))
	case int:
		limit = vimit.(int)
	case int64:
		limit = int(vimit.(int64))
	}

	var period int
	switch vperiod.(type) {
	case string:
		period = utils.StrToInt(vperiod.(string))
	case int:
		period = vperiod.(int)
	}

	time := utils.BytesToInt(p.TxMap["time"])
	num, err := p.Single("SELECT count(time) FROM rb_time_"+txType+" WHERE user_id = ? AND time > ?", p.TxUserID, (time - period)).Int()
	if err != nil {
		return err
	}
	if num >= limit {
		return utils.ErrInfo(fmt.Errorf("[limit_requests] rb_time_%v %v >= %v", txType, num, limit))
	} else {
		err := p.ExecSQL("INSERT INTO rb_time_"+txType+" (user_id, time) VALUES (?, ?)", p.TxUserID, time)
		if err != nil {
			return err
		}
	}
	return nil
}*/

func (p *Parser) dataPre() {
	p.blockHashHex = utils.DSha256(p.BinaryData)
	p.blockHex = utils.BinToHex(p.BinaryData)
	// define the data type
	p.dataType = int(utils.BinToDec(utils.BytesShift(&p.BinaryData, 1)))
	log.Debug("dataType", p.dataType)
}

// CheckLogTx checks if this transaction exists
// This is protection against dos, when one transaction could be sent a million times
// and it would have successfully passed a frontal test
func (p *Parser) CheckLogTx(txBinary []byte, transactions, txQueue bool) error {
	hash, err := p.Single(`SELECT hash FROM log_transactions WHERE hex(hash) = ?`, utils.Md5(txBinary)).String()
	log.Debug("SELECT hash FROM log_transactions WHERE hex(hash) = %s", utils.Md5(txBinary))
	if err != nil {
		log.Error("%s", utils.ErrInfo(err))
		return utils.ErrInfo(err)
	}
	log.Debug("hash %x", hash)
	if len(hash) > 0 {
		return utils.ErrInfo(fmt.Errorf("double tx in log_transactions %s", utils.Md5(txBinary)))
	}

	if transactions {
		// check whether we have such a transaction
		exists, err := p.Single("SELECT count(hash) FROM transactions WHERE hex(hash) = ? and verified = 1", utils.Md5(txBinary)).Int64()
		if err != nil {
			log.Error("%s", utils.ErrInfo(err))
			return utils.ErrInfo(err)
		}
		if exists > 0 {
			return utils.ErrInfo(fmt.Errorf("double tx in transactions %s", utils.Md5(txBinary)))
		}
	}

	if txQueue {
		// check whether we have such a transaction
		exists, err := p.Single("SELECT count(hash) FROM queue_tx WHERE hex(hash) = ?", utils.Md5(txBinary)).Int64()
		if err != nil {
			log.Error("%s", utils.ErrInfo(err))
			return utils.ErrInfo(err)
		}
		if exists > 0 {
			return utils.ErrInfo(fmt.Errorf("double tx in queue_tx %s", utils.Md5(txBinary)))
		}
	}

	return nil
}

// GetInfoBlock returns the latest block
func (p *Parser) GetInfoBlock() error {

	// the last successfully recorded block
	p.PrevBlock = new(utils.BlockData)
	q := "SELECT encode(hash, 'HEX')  as hash, block_id, time, wallet_id FROM info_block"
	err := p.QueryRow(q).Scan(&p.PrevBlock.Hash, &p.PrevBlock.BlockId, &p.PrevBlock.Time, &p.PrevBlock.WalletId)

	if err != nil && err != sql.ErrNoRows {
		return p.ErrInfo(err)
	}
	return nil
}

// InsertIntoBlockchain inserts a block into the blockchain
func (p *Parser) InsertIntoBlockchain() error {
	//var mutex = &sync.Mutex{}
	// for local tests
	if p.BlockData.BlockId == 1 {
		if *utils.StartBlockID != 0 {
			p.BlockData.BlockId = *utils.StartBlockID
		}
	}
	//mutex.Lock()
	// record into the block chain
	err := p.ExecSQL("DELETE FROM block_chain WHERE id = ?", p.BlockData.BlockId)
	if err != nil {
		return err
	}
	err = p.ExecSQL("INSERT INTO block_chain (id, hash, data, state_id, wallet_id, time, tx) VALUES (?, [hex], [hex], ?, ?, ?, ?)",
		p.BlockData.BlockId, p.BlockData.Hash, p.blockHex, p.BlockData.StateID, p.BlockData.WalletId, p.BlockData.Time, p.TxIds)
	if err != nil {
		fmt.Println(err)
		return err
	}
	//mutex.Unlock()
	return nil
}

// the old
/*func (p *Parser) GetTxMap(fields []string) (map[string][]byte, error) {
	if len(p.TxSlice) != len(fields)+4 {
		return nil, fmt.Errorf("bad transaction_array %d != %d (type=%d)", len(p.TxSlice), len(fields)+4, p.TxSlice[0])
	}
	TxMap := make(map[string][]byte)
	TxMap["hash"] = p.TxSlice[0]
	TxMap["type"] = p.TxSlice[1]
	TxMap["time"] = p.TxSlice[2]
	TxMap["user_id"] = p.TxSlice[3]
	for i, field := range fields {
		TxMap[field] = p.TxSlice[i+4]
	}
	p.TxUserID = utils.BytesToInt64(TxMap["user_id"])
	p.TxTime = utils.BytesToInt64(TxMap["time"])
	p.PublicKeys = nil
	//log.Debug("TxMap", TxMap)
	//log.Debug("TxMap[hash]", TxMap["hash"])
	//log.Debug("p.TxSlice[0]", p.TxSlice[0])
	return TxMap, nil
}*/

// CheckInputData checks the each item of data
func (p *Parser) CheckInputData(data map[string]string) error {

	for k, v := range data {
		fmt.Println("v==", v, p.TxMap[k])
		if !utils.CheckInputData(p.TxMap[k], v) {
			return fmt.Errorf("incorrect " + k + "(" + string(p.TxMap[k]) + " : " + v + ")")
		}
	}
	return nil
}

/*
func (p *Parser) limitRequestsRollback(txType string) error {
	time := p.TxMap["time"]
	if p.ConfigIni["db_type"] == "mysql" {
		return p.ExecSQL("DELETE FROM rb_time_"+txType+" WHERE user_id = ? AND time = ? LIMIT 1", p.TxUserID, time)
	} else if p.ConfigIni["db_type"] == "postgresql" {
		return p.ExecSQL("DELETE FROM rb_time_"+txType+" WHERE ctid IN (SELECT ctid FROM rb_time_"+txType+" WHERE  user_id = ? AND time = ? LIMIT 1)", p.TxUserID, time)
	}
	return p.ExecSQL("DELETE FROM rb_time_"+txType+" WHERE id IN (SELECT id FROM rb_time_"+txType+" WHERE  user_id = ? AND time = ? LIMIT 1)", p.TxUserID, time)
}

func arrayIntersect(arr1, arr2 map[int]int) bool {
	for _, v := range arr1 {
		for _, v2 := range arr2 {
			if v == v2 {
				return true
			}
		}
	}
	return false
}*/

// FormatBlockData returns formated block data
func (p *Parser) FormatBlockData() string {
	result := ""
	if p.BlockData != nil {
		v := reflect.ValueOf(*p.BlockData)
		typeOfT := v.Type()
		if typeOfT.Kind() == reflect.Ptr {
			typeOfT = typeOfT.Elem()
		}
		for i := 0; i < v.NumField(); i++ {
			name := typeOfT.Field(i).Name
			switch name {
			case "BlockId", "Time", "UserId", "Level":
				result += "[" + name + "] = " + fmt.Sprintf("%d\n", v.Field(i).Interface())
			case "Sign", "Hash", "HeadHash":
				result += "[" + name + "] = " + fmt.Sprintf("%x\n", v.Field(i).Interface())
			default:
				result += "[" + name + "] = " + fmt.Sprintf("%s\n", v.Field(i).Interface())
			}
		}
	}
	return result
}

// FormatTxMap returns the formated TxMap
func (p *Parser) FormatTxMap() string {
	result := ""
	for k, v := range p.TxMap {
		switch k {
		case "sign":
			result += "[" + k + "] = " + fmt.Sprintf("%x\n", v)
		default:
			result += "[" + k + "] = " + fmt.Sprintf("%s\n", v)
		}
	}
	return result
}

// ErrInfo returns the more detailed error
func (p *Parser) ErrInfo(verr interface{}) error {
	var err error
	switch verr.(type) {
	case error:
		err = verr.(error)
	case string:
		err = fmt.Errorf(verr.(string))
	}
	return fmt.Errorf("[ERROR] %s (%s)\n%s\n%s", err, utils.Caller(1), p.FormatBlockData(), p.FormatTxMap())
}

/*
func (p *Parser) limitRequestsMoneyOrdersRollback() error {
	err := p.ExecSQL("DELETE FROM rb_time_money_orders WHERE hex(tx_hash) = ?", p.TxHash)
	if err != nil {
		return p.ErrInfo(err)
	}
	return nil
}

func (p *Parser) getMyNodeCommission(currencyId, userId int64, amount float64) (float64, error) {
	return consts.COMMISSION, nil

}
*/
func (p *Parser) checkSenderDLT(amount, commission decimal.Decimal) error {
	wallet := p.TxWalletID
	if wallet == 0 {
		wallet = p.TxCitizenID
	}
	// recieve the amount on the user's wallet
	strAmount, err := p.Single(`SELECT amount FROM dlt_wallets WHERE wallet_id = ?`, wallet).String()
	if err != nil {
		return err
	}
	totalAmount, _ := decimal.NewFromString(strAmount)

	amountAndCommission := amount
	amountAndCommission.Add(commission)
	if totalAmount.Cmp(amountAndCommission) < 0 {
		return fmt.Errorf("%v < %v)", totalAmount, amountAndCommission)
	}
	return nil
}

/*
func (p *Parser) MyTable(table, id_column string, id int64, ret_column string) (int64, error) {
	if utils.CheckInputData(table, "string") || utils.CheckInputData(ret_column, "string") {
		return 0, fmt.Errorf("!string")
	}
	return p.Single(`SELECT `+ret_column+` FROM `+table+` WHERE `+id_column+` = ?`, id).Int64()
}

func (p *Parser) MyTableChecking(table, id_column string, id int64, ret_column string) (bool, error) {
	if utils.CheckInputData(table, "string") || utils.CheckInputData(ret_column, "string") {
		return false, fmt.Errorf("!string")
	}

	if ok, err := p.CheckTableExists(table); !ok {
		return true, err
	}
	return false, nil
}
*/

// CheckTableExists checks if the table exists
func (p *Parser) CheckTableExists(table string) (bool, error) {
	var q string
	switch p.ConfigIni["db_type"] {
	case "sqlite":
		q = `SELECT name FROM sqlite_master WHERE type='table' AND name='` + table + `';`
	case "postgresql":
		q = `SELECT relname FROM pg_class WHERE relname = '` + table + `';`
	case "mysql":
		q = `SHOW TABLES LIKE '` + table + `'`
	}
	exists, err := p.Single(q).Int64()
	if err != nil {
		return false, err
	}
	if exists > 0 {
		return true, nil
	}

	return false, nil
}

// BlockError writes the error of the transaction in the transactions_status table
func (p *Parser) BlockError(err error) {
	if len(p.TxHash) == 0 {
		return
	}
	errText := err.Error()
	if len(errText) > 255 {
		errText = errText[:255]
	}
	p.DeleteQueueTx([]byte(p.TxHash))
	log.Debug("UPDATE transactions_status SET error = %s WHERE hex(hash) = %x", errText, p.TxHash)
	p.ExecSQL("UPDATE transactions_status SET error = ? WHERE hex(hash) = ?", errText, p.TxHash)
}

// AccessRights checks the access right by executing the condition value
func (p *Parser) AccessRights(condition string, iscondition bool) error {
	param := `value`
	if iscondition {
		param = `conditions`
	}
	conditions, err := p.Single(`SELECT `+param+` FROM "`+utils.Int64ToStr(int64(p.TxStateID))+`_state_parameters" WHERE name = ?`,
		condition).String()
	if err != nil {
		return err
	}
	if len(conditions) > 0 {
		ret, err := p.EvalIf(conditions)
		if err != nil {
			return err
		}
		if !ret {
			return fmt.Errorf(`Access denied`)
		}
	} else {
		return fmt.Errorf(`There is not %s in state_parameters`, condition)
	}
	return nil
}

// AccessTable checks the access right to the table
func (p *Parser) AccessTable(table, action string) error {

	//	prefix := utils.Int64ToStr(int64(p.TxStateID))
	govAccount, _ := utils.StateParam(int64(p.TxStateID), `gov_account`)
	if table == `dlt_wallets` && p.TxContract != nil && p.TxCitizenID == utils.StrToInt64(govAccount) {
		return nil
	}

	if isCustom, err := p.IsCustomTable(table); err != nil {
		return err // table != ... is left for compatibility temporarily. Remove new_state after rebuilding.
	} else if !isCustom && !strings.HasSuffix(table, `_citizenship_requests`) {
		return fmt.Errorf(table + ` is not a custom table`)
	}
	prefix := table[:strings.IndexByte(table, '_')]

	/*	if p.TxStateID == 0 {
		return nil
	}*/

	tablePermission, err := p.GetMap(`SELECT data.* FROM "`+prefix+`_tables", jsonb_each_text(columns_and_permissions) as data WHERE name = ?`, "key", "value", table)
	if err != nil {
		return err
	}
	if len(tablePermission[action]) > 0 {
		ret, err := p.EvalIf(tablePermission[action])
		if err != nil {
			return err
		}
		if !ret {
			return fmt.Errorf(`Access denied`)
		}
	}
	return nil
}

// AccessColumns checks access rights to the columns
func (p *Parser) AccessColumns(table string, columns []string) error {

	//prefix := utils.Int64ToStr(int64(p.TxStateID))

	if isCustom, err := p.IsCustomTable(table); err != nil {
		return err // table != ... is left for compatibility temporarily. Remove new_state after rebuilding
	} else if !isCustom && !strings.HasSuffix(table, `_citizenship_requests`) {
		return fmt.Errorf(table + ` is not a custom table`)
	}
	prefix := table[:strings.IndexByte(table, '_')]
	/*	if p.TxStateID == 0 {
		return nil
	}*/

	columnsAndPermissions, err := p.GetMap(`SELECT data.* FROM "`+prefix+`_tables", jsonb_each_text(columns_and_permissions->'update') as data WHERE name = ?`,
		"key", "value", table)
	if err != nil {
		return err
	}
	for _, col := range columns {
		if cond, ok := columnsAndPermissions[col]; ok && len(cond) > 0 {
			ret, err := p.EvalIf(cond)
			if err != nil {
				return err
			}
			if !ret {
				return fmt.Errorf(`Access denied`)
			}
		}
	}
	return nil
}

// AccessChange checks rights of changing the table
func (p *Parser) AccessChange(table, name string) error {
	/*	if p.TxStateID == 0 {
		return nil
	}*/
	prefix := `global`
	if p.TxMaps.Int64["global"] == 0 {
		prefix = p.TxStateIDStr
	}
	//	prefix := utils.Int64ToStr(int64(p.TxStateID))
	conditions, err := p.Single(`SELECT conditions FROM "`+prefix+`_`+table+`" WHERE name = ?`, name).String()
	if err != nil {
		return err
	}

	if len(conditions) > 0 {
		ret, err := p.EvalIf(conditions)
		if err != nil {
			return err
		}
		if !ret {
			return fmt.Errorf(`Access denied`)
		}
	} else {
		return fmt.Errorf(`There is not conditions in %s`, prefix+`_`+table)
	}
	return nil
}

func (p *Parser) getEGSPrice(name string) (decimal.Decimal, error) {
	fPrice, err := p.Single(`SELECT value->'`+name+`' FROM system_parameters WHERE name = ?`, "op_price").String()
	if err != nil {
		return decimal.New(0, 0), p.ErrInfo(err)
	}
	p.TxCost = 0
	p.TxUsedCost, _ = decimal.NewFromString(fPrice)
	fuelRate := p.GetFuel()
	if fuelRate.Cmp(decimal.New(0, 0)) <= 0 {
		return decimal.New(0, 0), fmt.Errorf(`fuel rate must be greater than 0`)
	}
	return p.TxUsedCost.Mul(fuelRate), nil
}

func (p *Parser) checkPrice(name string) error {
	EGSPrice, err := p.getEGSPrice(name)
	if err != nil {
		return err
	}
	// Is there a correct amount on the wallet?
	err = p.checkSenderDLT(EGSPrice, decimal.New(0, 0))
	if err != nil {
		return err
	}
	return nil
}

// GetContractLimit returns the default maximal cost of contract
func (p *Parser) GetContractLimit() (ret int64) {
	//	fuel := p.GetFuel()
	/*	if p.TxStateID > 0 && p.TxCitizenID > 0 {

		}
		TxCitizenID      int64
		TxWalletID       int64
		TxStateID */
	/*	if ret == 0 {
		ret = script.CostDefault
	}*/
	// default maximum cost of F
	p.TxCost = script.CostDefault // ret * fuel
	return p.TxCost
}

/*func (p *Parser) CheckContractLimit(price int64) bool {
	return true
	var balance decimal.Decimal
	fuel := p.GetFuel()
	if fuel <= 0 {
		return false
	}
	need := p.TxCost * fuel // need qEGS = F*fuel
	//	wallet := p.TxWalletID
	if p.TxStateID > 0 && p.TxCitizenID != 0 {
		var needuser int64
		rate, _ := utils.EGSRate(int64(p.TxStateID)) // money/egs
		tableAccounts, _ := utils.StateParam(int64(p.TxStateID), `table_accounts`)
		tableAccounts = lib.Escape(tableAccounts)
		if len(tableAccounts) == 0 {
			tableAccounts = `accounts`
		}
		if rate == 0 {
			rate = 1.0
		}
		p.TxContract.EGSRate = rate
		p.TxContract.TableAccounts = tableAccounts

		if price >= 0 {
			needuser = int64(float64(price) * rate)
		} else {
			needuser = int64(float64(need) * rate)
		}
		p.TxContract.TxGovAccount = utils.StrToInt64(StateVal(p, `gov_account`))
		if needuser > 0 {
			if money, _ := p.Single(fmt.Sprintf(`select amount from "%d_%s" where citizen_id=?`, p.TxStateID, tableAccounts),
				p.TxCitizenID).Int64(); money < needuser {
				return false
			}
		}
		// Check if government has enough money
		balance, _ = utils.Balance(p.TxContract.TxGovAccount)
		//wallet = p.TxCitizenID
	} else {
		//if balance.Cmp(decimal.New(0, 0)) == 0 {
		balance, _ = utils.Balance(p.TxWalletID)
	}
	/*		TxCitizenID      int64
			TxWalletID       int64
			TxStateID
	return balance.Cmp(decimal.New(need, 0)) > 0
}*/

func (p *Parser) payFPrice() error {
	var (
		fromID int64
		err    error
	)
	//return nil
	toID := p.BlockData.WalletId // account of node
	fuel := p.GetFuel()
	if fuel.Cmp(decimal.New(0, 0)) <= 0 {
		return fmt.Errorf(`fuel rate must be greater than 0`)
	}

	if p.TxCost == 0 { // embedded transaction
		fromID = p.TxWalletID
		if fromID == 0 {
			fromID = p.TxCitizenID
		}
	} else { // contract
		if p.TxStateID > 0 && p.TxCitizenID != 0 && p.TxContract != nil {
			//fromID = p.TxContract.TxGovAccount
			fromID = utils.StrToInt64(StateVal(p, `gov_account`))
		} else {
			// write directly from dlt_wallets of user
			fromID = p.TxWalletID
		}
	}
	egs := p.TxUsedCost.Mul(fuel)
	fmt.Printf("Pay fuel=%v fromID=%d toID=%d cost=%v egs=%v", fuel, fromID, toID, p.TxUsedCost, egs)
	if egs.Cmp(decimal.New(0, 0)) == 0 { // Is it possible to pay nothing?
		return nil
	}
	var amount string
	if amount, err = p.Single(`select amount from dlt_wallets where wallet_id=?`, fromID).String(); err != nil {
		return err
	}
	damount, err := decimal.NewFromString(amount)
	if err != nil {
		return err
	}
	if damount.Cmp(egs) < 0 {
		egs = damount
	}
	commission := egs.Mul(decimal.New(3, 0)).Div(decimal.New(100, 0)).Floor()
	//	fmt.Printf("Commission %v %v \r\n", commission, egs)
	/*	query := fmt.Sprintf(`begin;
		update dlt_wallets set amount = amount - least(amount, '%d') where wallet_id='%d';
		update dlt_wallets set amount = amount + '%d' where wallet_id='%d';
		update dlt_wallets set amount = amount + '%d' where wallet_id='%d';
		commit;`, egs, fromID, egs-commission, toID, commission, consts.COMMISSION_WALLET)
		if err := p.ExecSQL(query); err != nil {
			return err
		}*/
	if _, err := p.selectiveLoggingAndUpd([]string{`-amount`}, []interface{}{egs}, `dlt_wallets`, []string{`wallet_id`},
		[]string{utils.Int64ToStr(fromID)}, true); err != nil {
		return err
	}
	if _, err := p.selectiveLoggingAndUpd([]string{`+amount`}, []interface{}{egs.Sub(commission)}, `dlt_wallets`, []string{`wallet_id`},
		[]string{utils.Int64ToStr(toID)}, true); err != nil {
		return err
	}
	if _, err := p.selectiveLoggingAndUpd([]string{`+amount`}, []interface{}{commission}, `dlt_wallets`, []string{`wallet_id`},
		[]string{utils.Int64ToStr(consts.COMMISSION_WALLET)}, true); err != nil {
		return err
	}
	fmt.Printf(" Paid commission %v\r\n", commission)
	return nil
	/*	if p.TxStateID > 0 && p.TxCitizenID != 0 && p.TxContract != nil {
			// All these will be removed, state will withdraw money from citizens within contracts
			table := fmt.Sprintf(`"%d_%s"`, p.TxStateID, p.TxContract.TableAccounts)
			amount, err := p.Single(`select amount from `+table+` where citizen_id=?`, p.TxCitizenID).Int64()
			money := int64(float64(egs) * p.TxContract.EGSRate)
			if p.TxContract.TxPrice >= 0 {
				money = int64(float64(p.TxContract.TxPrice) * p.TxContract.EGSRate)
			}
			if amount < money {
				money = amount
			}
			if money > 0 {
				if err = p.ExecSQL(`update `+table+` set amount = amount - ? where citizen_id=?`, money, p.TxCitizenID); err != nil {
					return err
				}
				if err = p.ExecSQL(`update `+table+` set amount = amount + ? where citizen_id=?`, money, p.TxContract.TxGovAccount); err != nil {
					// refund payment
					p.ExecSQL(`update `+table+` set amount = amount + ? where citizen_id=?`, money, p.TxCitizenID)
					return err
				}
			}
		}
		return nil*/
}
