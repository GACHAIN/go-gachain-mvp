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
	"encoding/json"
	"github.com/GACHAIN/go-gachain-mvp/packages/consts"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
	"net/http"
	"os"
	"time"
)

var (
	// data may not be updated yet at the first running
	timeSynchro int64 // When the first running
	lastSBlock  int64 // last block
	lastSTime   int64
)

// SynchronizationBlockchain synchronizes the blockchain
func (c *Controller) SynchronizationBlockchain() (string, error) {

	if c.DCDB == nil || c.DCDB.DB == nil {
		return "", nil
	}
	blockData, err := c.DCDB.GetInfoBlock()
	if err != nil {
		log.Error("%v", utils.ErrInfo(err))

		var (
			downloadFile, blockURL string
			fileSize               int64
		)
		downloadFile = *utils.Dir + "/public/blockchain"
		nodeConfig, err := c.GetNodeConfig()
		if err != nil {
			return "", err
		}
		blockURL = nodeConfig["first_load_blockchain_url"]
		if len(blockURL) == 0 {
			blockURL = consts.BLOCKCHAIN_URL
		}
		resp, err := http.Get(blockURL)
		if err != nil {
			return "", err
		}
		fileSize = resp.ContentLength
		resp.Body.Close()

		// block is downloading
		file, err := os.Open(downloadFile)
		if err != nil {
			return "", err
		}
		defer file.Close()
		stat, err := file.Stat()
		if err != nil {
			return "", err
		}
		if stat.Size() > 0 {
			log.Debug("stat.Size(): %v", int(stat.Size()))
			return `{"download": "` + utils.Int64ToStr(int64(utils.Round(float64((float64(stat.Size())/float64(fileSize))*100), 0))) + `"}`, nil
		}
		return `{"download": "0"}`, nil
	}
	blockID := blockData["block_id"]
	blockTime := blockData["time"]
	if len(blockID) == 0 {
		blockID = "0"
	}
	if len(blockTime) == 0 {
		blockTime = "0"
	}

	wTime := int64(12)
	wTimeReady := int64(1)
	if c.ConfigIni["test_mode"] == "1" {
		wTime = 2 * 365 * 86400
		wTimeReady = 2 * 365 * 86400
	}
	log.Debug("wTime: %v / utils.Time(): %v / blockData[time]: %v", wTime, utils.Time(), utils.StrToInt64(blockData["time"]))
	// if time differs less than for 12 hours from current time, give not confirmed but those which are in blockchain
	if utils.Time()-utils.StrToInt64(blockData["time"]) < 3600*wTime {
		lastBlockData, err := c.DCDB.GetLastBlockData()
		if err != nil {
			return "", err
		}
		log.Debug("lastBlockData[lastBlockTime]: %v", lastBlockData["lastBlockTime"])
		log.Debug("time.Now().Unix(): %v", time.Now().Unix())
		// if almost all blocks are collected
		if time.Now().Unix()-lastBlockData["lastBlockTime"] < 600*wTimeReady {
			blockID = "-1"
			blockTime = "-1"
		}
	}

	confirmedBlockID, err := c.GetConfirmedBlockID()
	if err != nil {
		return "", err
	}

	currentLoadBlockchain := "nodes"
	if c.NodeConfig["current_load_blockchain"] == "file" {
		currentLoadBlockchain = c.NodeConfig["first_load_blockchain_url"]
	}
	var needReload string
	iBlock := utils.StrToInt64(blockID)
	if timeSynchro == 0 {
		timeSynchro = utils.Time()
		lastSBlock = iBlock
		lastSTime = utils.Time()
	} else if utils.Time()-timeSynchro > 300 { // Here is possible to set 20 minutes or less
		if lastSBlock != iBlock {
			lastSBlock = iBlock
			lastSTime = utils.Time()
		} else if utils.Time()-lastSTime > 60 { // Set the timeout in 60 seconds on the next block
			// There is a sence to check the last block
			if utils.Time()-utils.StrToInt64(blockTime) > 3600 {
				needReload = `1`
			}
		}
	}

	result := map[string]string{"block_id": blockID, "confirmed_block_id": utils.Int64ToStr(confirmedBlockID),
		"block_time": blockTime, "current_load_blockchain": currentLoadBlockchain,
		"need_reload": needReload}
	resultJ, _ := json.Marshal(result)

	return string(resultJ), nil
}
