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

	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

var (
	isGlobal bool
)

/*
Adding state tables should be spelled out in state settings
*/

// NewStateInit initializes NewState transaction
func (p *Parser) NewStateInit() error {

	fields := []map[string]string{{"state_name": "string"}, {"currency_name": "string"}, {"public_key": "bytes"}, {"sign": "bytes"}}
	err := p.GetTxMaps(fields)
	if err != nil {
		return p.ErrInfo(err)
	}
	return nil
}

// NewStateGlobal checks if the state or the currency exists
func (p *Parser) NewStateGlobal(country, currency string) error {
	if !isGlobal {
		list, err := utils.DB.GetAllTables()
		if err != nil {
			return err
		}
		isGlobal = utils.InSliceString(`global_currencies_list`, list) && utils.InSliceString(`global_states_list`, list)
	}
	if isGlobal {
		if id, err := utils.DB.Single(`select id from global_states_list where state_name=?`, country).Int64(); err != nil {
			return err
		} else if id > 0 {
			return fmt.Errorf(`State %s already exists`, country)
		}
		if id, err := utils.DB.Single(`select id from global_currencies_list where currency_code=?`, currency).Int64(); err != nil {
			return err
		} else if id > 0 {
			return fmt.Errorf(`Currency %s already exists`, currency)
		}
	}
	return nil
}

// NewStateFront checks conditions of NewState transaction
func (p *Parser) NewStateFront() error {
	err := p.generalCheck(`new_state`)
	if err != nil {
		fmt.Printf(">>> generalCheck %s\n", err)
		//return p.ErrInfo(err)
	}

	// Check InputData
	verifyData := map[string]string{"state_name": "state_name", "currency_name": "currency_name"}
	err = p.CheckInputData(verifyData)
	if err != nil {
		fmt.Printf(">>> CheckInputData %s\n", err)
		//return p.ErrInfo(err)
	}

	forSign := fmt.Sprintf("%s,%s,%d,%s,%s", p.TxMap["type"], p.TxMap["time"], p.TxWalletID, p.TxMap["state_name"], p.TxMap["currency_name"])
	CheckSignResult, err := utils.CheckSign(p.PublicKeys, forSign, p.TxMap["sign"], false)
	if err != nil {
		fmt.Printf(">>> CheckSign %s\n", err)
		//return p.ErrInfo(err)
	}
	if !CheckSignResult {
		fmt.Printf(">>> CheckSignResult %s\n", err)
		//return p.ErrInfo("incorrect sign")
	}
	country := string(p.TxMap["state_name"])
	if exist, err := p.IsState(country); err != nil {
		fmt.Printf(">>> IsState %s\n", err)
		//return p.ErrInfo(err)
	} else if exist > 0 {
		fmt.Printf(">>> exist %s\n", err)
		//return fmt.Errorf(`State %s already exists`, country)
	}

	err = p.NewStateGlobal(country, string(p.TxMap["currency_name"]))
	if err != nil {
		fmt.Printf(">>> NewStateGlobal %s\n", err)
		//return p.ErrInfo(err)
	}
	return nil
}

// NewStateMain creates state tables in the database
func (p *Parser) NewStateMain(country, currency string) (id string, err error) {
	id, err = p.ExecSQLGetLastInsertID(`INSERT INTO system_states DEFAULT VALUES`, "system_states")
	if err != nil {
		return
	}
	err = p.ExecSQL("INSERT INTO rollback_tx ( block_id, tx_hash, table_name, table_id ) VALUES (?, [hex], ?, ?)", p.BlockData.BlockId, p.TxHash, "system_states", id)
	if err != nil {
		return
	}

	err = p.ExecSQL(`CREATE TABLE "` + id + `_state_parameters" (
				"name" varchar(100)  NOT NULL DEFAULT '',
				"value" text  NOT NULL DEFAULT '',
				"bytecode" bytea  NOT NULL DEFAULT '',
				"conditions" text  NOT NULL DEFAULT '',
				"rb_id" bigint NOT NULL DEFAULT '0'
				);
				ALTER TABLE ONLY "` + id + `_state_parameters" ADD CONSTRAINT "` + id + `_state_parameters_pkey" PRIMARY KEY (name);
				`)
	if err != nil {
		return
	}
	sid := "ContractConditions(`MainCondition`)" //`$citizen == ` + utils.Int64ToStr(p.TxWalletID) // id + `_citizens.id=` + utils.Int64ToStr(p.TxWalletID)
	psid := sid                                  //fmt.Sprintf(`Eval(StateParam(%s, "main_conditions"))`, id) //id+`_state_parameters.main_conditions`
	err = p.ExecSQL(`INSERT INTO "`+id+`_state_parameters" (name, value, bytecode, conditions) VALUES
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?),
		(?, ?, ?, ?)`,
		"restore_access_condition", sid, "", psid,
		"new_table", sid, "", psid,
		"new_column", sid, "", psid,
		"changing_tables", sid, "", psid,
		"changing_language", sid, "", psid,
		"changing_signature", sid, "", psid,
		"changing_smart_contracts", sid, "", psid,
		"changing_menu", sid, "", psid,
		"changing_page", sid, "", psid,
		"currency_name", currency, "", psid,
		"gender_list", "male,female", "", psid,
		"money_digit", "0", "", psid,
		"tx_fiat_limit", "10", "", psid,
		"state_name", country, "", psid,
		"gov_account", p.TxWalletID, "", psid,
		"dlt_spending", p.TxWalletID, "", psid,
		"state_flag", "", "", psid,
		"state_coords", ``, "", psid,
		"citizenship_price", "1000000", "", psid)
	if err != nil {
		return
	}
	err = p.ExecSQL(`CREATE SEQUENCE "` + id + `_smart_contracts_id_seq" START WITH 1;
				CREATE TABLE "` + id + `_smart_contracts" (
				"id" bigint NOT NULL  default nextval('` + id + `_smart_contracts_id_seq'),
				"name" varchar(100)  NOT NULL DEFAULT '',
				"value" text  NOT NULL DEFAULT '',
				"wallet_id" bigint  NOT NULL DEFAULT '0',
				"active" character(1) NOT NULL DEFAULT '0',
				"conditions" text  NOT NULL DEFAULT '',
				"variables" bytea  NOT NULL DEFAULT '',
				"rb_id" bigint NOT NULL DEFAULT '0'
				);
				ALTER SEQUENCE "` + id + `_smart_contracts_id_seq" owned by "` + id + `_smart_contracts".id;
				ALTER TABLE ONLY "` + id + `_smart_contracts" ADD CONSTRAINT "` + id + `_smart_contracts_pkey" PRIMARY KEY (id);
				CREATE INDEX "` + id + `_smart_contracts_index_name" ON "` + id + `_smart_contracts" (name);
				`)
	if err != nil {
		return
	}
	err = p.ExecSQL(`INSERT INTO "`+id+`_smart_contracts" (name, value, wallet_id, active) VALUES
		(?, ?, ?, ?)`,
		`MainCondition`, `contract MainCondition {
            data {}
            conditions {
                    if(StateVal("gov_account")!=$citizen)
                    {
                        warning "Sorry, you don't have access to this action."
                    }
            }
            action {}
    }`, p.TxWalletID, 1,
	)

	if err != nil {
		return
	}
	err = p.ExecSQL(`UPDATE "`+id+`_smart_contracts" SET conditions = ?`, sid)
	if err != nil {
		return
	}

	err = p.ExecSQL(`CREATE TABLE "` + id + `_tables" (
				"name" varchar(100)  NOT NULL DEFAULT '',
				"columns_and_permissions" jsonb,
				"conditions" text  NOT NULL DEFAULT '',
				"rb_id" bigint NOT NULL DEFAULT '0'
				);
				ALTER TABLE ONLY "` + id + `_tables" ADD CONSTRAINT "` + id + `_tables_pkey" PRIMARY KEY (name);
				`)
	if err != nil {
		return
	}

	err = p.ExecSQL(`INSERT INTO "`+id+`_tables" (name, columns_and_permissions, conditions) VALUES
		(?, ?, ?)`,
		id+`_citizens`, `{"general_update":"`+sid+`", "update": {"public_key_0": "`+sid+`"}, "insert": "`+sid+`", "new_column":"`+sid+`"}`, psid)
	if err != nil {
		return
	}

	err = p.ExecSQL(`CREATE TABLE "` + id + `_pages" (
				"name" varchar(255)  NOT NULL DEFAULT '',
				"value" text  NOT NULL DEFAULT '',
				"menu" varchar(255)  NOT NULL DEFAULT '',
				"conditions" bytea  NOT NULL DEFAULT '',
				"rb_id" bigint NOT NULL DEFAULT '0'
				);
				ALTER TABLE ONLY "` + id + `_pages" ADD CONSTRAINT "` + id + `_pages_pkey" PRIMARY KEY (name);
				`)
	if err != nil {
		return
	}

	err = p.ExecSQL(`INSERT INTO "`+id+`_pages" (name, value, menu, conditions) VALUES
		(?, ?, ?, ?),
		(?, ?, ?, ?)`,
		`dashboard_default`, `FullScreen(1)
If(StateVal(tokens_accounts_type,1))
Else:
Title : Basic Apps
Divs: col-md-4
  Divs: panel panel-default elastic
   Divs: panel-body text-center fill-area flexbox-item-grow
    Divs: flexbox-item-grow flex-center
     Divs: pv-lg
     Image("/static/img/apps/money.png", Basic, center-block img-responsive img-circle img-thumbnail thumb96 )
     DivsEnd:
     P(h4,Basic Apps)
     P(text-left,"Election and Assign, Polling, Messenger, Simple Money System")
    DivsEnd:
   DivsEnd:
   Divs: panel-footer
    Divs: clearfix
     Divs: pull-right
      BtnPage(app-basic, Install,'',btn btn-primary lang)
     DivsEnd:
    DivsEnd:
   DivsEnd:
  DivsEnd:
 DivsEnd:
IfEnd:
PageEnd:
`, `menu_default`, sid,

		`government`, `
If(StateVal(tokens_accounts_type,1))
Title : Basic Apps
Divs: col-md-12
  Divs: panel panel-default elastic
   Divs: panel-body text-center fill-area flexbox-item-grow
    Divs: flexbox-item-grow flex-center
     Divs: pv-lg
     Image("/static/img/apps/money.png", Basic, center-block img-responsive img-circle img-thumbnail thumb96 )
     DivsEnd:
     P(h4,Application was successfully installed)
    DivsEnd:
   DivsEnd:
   Divs: panel-footer
    Divs: clearfix
     Divs: pull-right
        BtnPage(dashboard_default, Get Started,'',btn btn-primary lang)
     DivsEnd:
    DivsEnd:
   DivsEnd:
  DivsEnd:
 DivsEnd:
IfEnd:
PageEnd:
`, `government`, sid,
	)
	if err != nil {
		return
	}

	err = p.ExecSQL(`CREATE TABLE "` + id + `_menu" (
				"name" varchar(255)  NOT NULL DEFAULT '',
				"value" text  NOT NULL DEFAULT '',
				"conditions" bytea  NOT NULL DEFAULT '',
				"rb_id" bigint NOT NULL DEFAULT '0'
				);
				ALTER TABLE ONLY "` + id + `_menu" ADD CONSTRAINT "` + id + `_menu_pkey" PRIMARY KEY (name);
				`)
	if err != nil {
		return
	}
	err = p.ExecSQL(`INSERT INTO "`+id+`_menu" (name, value, conditions) VALUES
		(?, ?, ?),
		(?, ?, ?)`,
		`menu_default`, `MenuItem(Dashboard, dashboard_default)
 MenuItem(Ecosystem dashboard, government)`, sid,
		`government`, `MenuItem(Member dashboard, dashboard_default)
MenuItem(Ecosystem dashboard, government)
MenuGroup(Admin tools,admin)
MenuItem(Tables,sys-listOfTables)
MenuItem(Smart contracts, sys-contracts)
MenuItem(Interface, sys-interface)
MenuItem(App List, sys-app_catalog)
MenuItem(Export, sys-export_tpl)
MenuItem(Wallet,  sys-edit_wallet)
MenuItem(Languages, sys-languages)
MenuItem(Signatures, sys-signatures)
MenuEnd:
MenuBack(Welcome)`, sid)
	if err != nil {
		return
	}

	err = p.ExecSQL(`CREATE TABLE "` + id + `_citizens" (
				"id" bigint NOT NULL DEFAULT '0',
				"public_key_0" bytea  NOT NULL DEFAULT '',				
				"block_id" bigint NOT NULL DEFAULT '0',
				"rb_id" bigint NOT NULL DEFAULT '0'
				);
				ALTER TABLE ONLY "` + id + `_citizens" ADD CONSTRAINT "` + id + `_citizens_pkey" PRIMARY KEY (id);
				`)
	if err != nil {
		return
	}

	pKey, err := p.Single(`SELECT public_key_0 FROM dlt_wallets WHERE wallet_id = ?`, p.TxWalletID).Bytes()
	if err != nil {
		return
	}

	err = p.ExecSQL(`INSERT INTO "`+id+`_citizens" (id,public_key_0) VALUES (?, [hex])`, p.TxWalletID, utils.BinToHex(pKey))
	if err != nil {
		return
	}
	err = p.ExecSQL(`CREATE TABLE "` + id + `_languages" (
				"name" varchar(100)  NOT NULL DEFAULT '',
				"res" jsonb,
				"conditions" text  NOT NULL DEFAULT '',
				"rb_id" bigint NOT NULL DEFAULT '0'
				);
				ALTER TABLE ONLY "` + id + `_languages" ADD CONSTRAINT "` + id + `_languages_pkey" PRIMARY KEY (name);
				`)
	if err != nil {
		return
	}
	err = p.ExecSQL(`INSERT INTO "`+id+`_languages" (name, res, conditions) VALUES
		(?, ?, ?),
		(?, ?, ?),
		(?, ?, ?),
		(?, ?, ?),
		(?, ?, ?)`,
		`dateformat`, `{"en": "YYYY-MM-DD", "ru": "DD.MM.YYYY"}`, sid,
		`timeformat`, `{"en": "YYYY-MM-DD HH:MI:SS", "ru": "DD.MM.YYYY HH:MI:SS"}`, sid,
		`Gender`, `{"en": "Gender", "ru": "Пол"}`, sid,
		`male`, `{"en": "Male", "ru": "Мужской"}`, sid,
		`female`, `{"en": "Female", "ru": "Женский"}`, sid)
	if err != nil {
		return
	}

	err = p.ExecSQL(`CREATE TABLE "` + id + `_signatures" (
				"name" varchar(100)  NOT NULL DEFAULT '',
				"value" jsonb,
				"conditions" text  NOT NULL DEFAULT '',
				"rb_id" bigint NOT NULL DEFAULT '0'
				);
				ALTER TABLE ONLY "` + id + `_signatures" ADD CONSTRAINT "` + id + `_signatures_pkey" PRIMARY KEY (name);
				`)
	if err != nil {
		return
	}

	err = p.ExecSQL(`CREATE TABLE "` + id + `_apps" (
				"name" varchar(100)  NOT NULL DEFAULT '',
				"done" integer NOT NULL DEFAULT '0',
				"blocks" text  NOT NULL DEFAULT ''
				);
				ALTER TABLE ONLY "` + id + `_apps" ADD CONSTRAINT "` + id + `_apps_pkey" PRIMARY KEY (name);
				`)
	if err != nil {
		return
	}

	err = p.ExecSQL(`CREATE TABLE "` + id + `_anonyms" (
				"id_citizen" bigint NOT NULL DEFAULT '0',
				"id_anonym" bigint NOT NULL DEFAULT '0',
				"encrypted" bytea  NOT NULL DEFAULT ''
				);
				CREATE INDEX "` + id + `_anonyms_index_id" ON "` + id + `_anonyms" (id_citizen);`)
	if err != nil {
		return
	}

	err = utils.LoadContract(id)
	return
}

// NewState proceeds NewState transaction
func (p *Parser) NewState() error {
	var pkey string
	country := string(p.TxMap["state_name"])
	currency := string(p.TxMap["currency_name"])
	id, err := p.NewStateMain(country, currency)
	if err != nil {
		return p.ErrInfo(err)
	}
	if isGlobal {
		_, err = p.selectiveLoggingAndUpd([]string{"gstate_id", "state_name", "timestamp date_founded"},
			[]interface{}{id, country, p.BlockData.Time}, "global_states_list", nil, nil, true)

		if err != nil {
			return p.ErrInfo(err)
		}
		_, err = p.selectiveLoggingAndUpd([]string{"currency_code", "settings_table"},
			[]interface{}{currency, id + `_state_parameters`}, "global_currencies_list", nil, nil, true)
		if err != nil {
			return p.ErrInfo(err)
		}
	}

	if pkey, err = p.Single(`SELECT public_key_0 FROM dlt_wallets WHERE wallet_id = ?`, p.TxWalletID).String(); err != nil {
		return p.ErrInfo(err)
	} else if len(p.TxMaps.Bytes["public_key"]) > 30 && len(pkey) == 0 {
		_, err = p.selectiveLoggingAndUpd([]string{"public_key_0"}, []interface{}{utils.HexToBin(p.TxMaps.Bytes["public_key"])}, "dlt_wallets",
			[]string{"wallet_id"}, []string{utils.Int64ToStr(p.TxWalletID)}, true)
	}
	return err
}

// NewStateRollback rollbacks NewState transaction
func (p *Parser) NewStateRollback() error {
	id, err := p.Single(`SELECT table_id FROM rollback_tx WHERE tx_hash = [hex] AND table_name = ?`, p.TxHash, "system_states").Int64()
	if err != nil {
		return p.ErrInfo(err)
	}
	err = p.autoRollback()
	if err != nil {
		return p.ErrInfo(err)
	}

	for _, name := range []string{`menu`, `pages`, `citizens`, `languages`, `signatures`, `tables`,
		`smart_contracts`, `state_parameters`, `apps`, `anonyms` /*, `citizenship_requests`*/} {
		err = p.ExecSQL(fmt.Sprintf(`DROP TABLE "%d_%s"`, id, name))
		if err != nil {
			return p.ErrInfo(err)
		}
	}

	err = p.ExecSQL(`DELETE FROM rollback_tx WHERE tx_hash = [hex] AND table_name = ?`, p.TxHash, "system_states")
	if err != nil {
		return p.ErrInfo(err)
	}

	maxID, err := p.Single(`SELECT max(id) FROM "system_states"`).Int64()
	if err != nil {
		return p.ErrInfo(err)
	}
	// обновляем AI
	// update  the AI
	err = p.SetAI("system_states", maxID+1)
	if err != nil {
		return p.ErrInfo(err)
	}
	err = p.ExecSQL(`DELETE FROM "system_states" WHERE id = ?`, id)
	if err != nil {
		return p.ErrInfo(err)
	}

	return nil
}
