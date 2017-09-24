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
	"encoding/hex"
	"fmt"
	"io/ioutil"
	"os"

	"github.com/GACHAIN/go-gachain-mvp/packages/lib"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"

	qrcode "github.com/skip2/go-qrcode"
)

const aGenWallet = `ajax_gen_wallet`

type GenWallet struct {
	Address string `json:"address"`
	Public  string `json:"public"`
	Time    string `json:"time"`
	Error   string `json:"error"`
}

func init() {
	newPage(aGenWallet, `json`)
}

func (c *Controller) AjaxGenWallet() interface{} {
	var result GenWallet

	key := c.r.FormValue("private")
	phrase := c.r.FormValue("phrase")
	bkey, err := hex.DecodeString(key)
	if err != nil {
		result.Error = err.Error()
		return result
	}
	pubkey := lib.PrivateToPublic(bkey)
	idkey := int64(lib.Address(pubkey))

	//		in, _ := ioutil.ReadFile(*utils.Dir + `/words.txt`)
	exist, err := c.Single(`select wallet_id from dlt_wallets where wallet_id=?`, idkey).Int64()
	if err != nil {
		result.Error = err.Error()
		return result
	}
	if exist != 0 {
		result.Error = `key already exists`
		return result
	}
	result.Time = utils.Int64ToStr(utils.Time())
	result.Public = hex.EncodeToString(pubkey)
	result.Address = lib.AddressToString(idkey)
	dir := *utils.Dir + `/masswallets/` + utils.Int64ToStr(c.SessWalletID)
	err = os.MkdirAll(dir, os.FileMode(0777))
	if err != nil {
		result.Error = err.Error()
		return result
	}
	f, err := os.OpenFile(dir+"/wallets.txt", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		result.Error = err.Error()
		return result
	}
	if _, err := f.Write([]byte(fmt.Sprintf("%s, %s, %d, %s, %s\r\n", phrase, key, idkey, result.Address, c.r.FormValue("amount")))); err != nil {
		result.Error = err.Error()
		return result
	}
	if err := f.Close(); err != nil {
		result.Error = err.Error()
		return result
	}
	png, err := qrcode.Encode("http://ico.egaas.org/?pkey="+key, qrcode.Medium, 170)
	if err != nil {
		result.Error = err.Error()
		return result
	}
	err = ioutil.WriteFile(dir+`/`+result.Address+`.png`, png, os.FileMode(0644))
	if err != nil {
		result.Error = err.Error()
		return result
	}
	return result
}
