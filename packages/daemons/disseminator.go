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

package daemons

import (
	"github.com/GACHAIN/go-gachain-mvp/packages/consts"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
	"io"
)

/*
 * just send to all who have hashes of block and transaction in nodes_connection
 * if we are not a miner, then send transaction totally, we are not able not send blocks
 * if we are a miner then send only hashes because we have the host where we can upload everything
 * */

// Disseminator sends hashes of block and transactions
func Disseminator(chBreaker chan bool, chAnswer chan string) {
	defer func() {
		if r := recover(); r != nil {
			logger.Error("daemon Recovered", r)
			panic(r)
		}
	}()

	const GoroutineName = "Disseminator"
	d := new(daemon)
	d.DCDB = DbConnect(chBreaker, chAnswer, GoroutineName)
	if d.DCDB == nil {
		return
	}
	d.goRoutineName = GoroutineName
	d.chAnswer = chAnswer
	d.chBreaker = chBreaker
	d.sleepTime = 1

	if !d.CheckInstall(chBreaker, chAnswer, GoroutineName) {
		return
	}
	d.DCDB = DbConnect(chBreaker, chAnswer, GoroutineName)
	if d.DCDB == nil {
		return
	}

BEGIN:
	for {
		logger.Info(GoroutineName)
		MonitorDaemonCh <- []string{GoroutineName, utils.Int64ToStr(utils.Time())}

		// check if we have to break the cycle
		if CheckDaemonsRestart(chBreaker, chAnswer, GoroutineName) {
			break BEGIN
		}

		hosts, err := d.GetHosts()
		if err != nil {
			logger.Error("%v", err)
		}

		myStateID, myWalletID, err := d.GetMyStateIDAndWalletID()
		logger.Debug("%v", myWalletID)
		if err != nil {
			logger.Error("%v", err)
			if d.dSleep(d.sleepTime) {
				break BEGIN
			}
			continue
		}

		fullNode := true
		if myStateID > 0 {
			delegate, err := d.CheckDelegateCB(myStateID)
			if err != nil {
				logger.Error("%v", err)
				if d.dSleep(d.sleepTime) {
					break BEGIN
				}
				continue
			}
			// if we are a state we have a delegate, that means we delegated our authority of the node maintenance to another user or state, then we exit.
			if delegate {
				fullNode = false
			}
		}

		// whether we are in the list of those who are able to generate blocks
		fullNodeID, err := d.Single("SELECT id FROM full_nodes WHERE final_delegate_state_id = ? OR final_delegate_wallet_id = ? OR state_id = ? OR wallet_id = ?", myStateID, myWalletID, myStateID, myWalletID).Int64()
		if err != nil {
			logger.Error("%v", err)
			if d.dSleep(d.sleepTime) {
				break BEGIN
			}
			continue
		}
		if fullNodeID == 0 {
			fullNode = false
		}

		var dataType int64 // this type is needed to let the host understand how exactly it has to process the sent data

		// if we are fullNode we have to send hashes, blocks will take themselves
		if fullNode {

			logger.Debug("dataType = 1")

			dataType = 1

			// take the hash of current block and number of a block
			// disconnect for some time to test rollbacks
			data, err := d.OneRow("SELECT block_id, hash FROM info_block WHERE sent  =  0").Bytes()
			if err != nil {
				if d.dPrintSleep(err, d.sleepTime) {
					break BEGIN
				}
				continue BEGIN
			}
			err = d.ExecSQL("UPDATE info_block SET sent = 1")
			if err != nil {
				if d.dPrintSleep(err, d.sleepTime) {
					break BEGIN
				}
				continue BEGIN
			}

			/*
			 * We compose the data for sending
			 * */
			toBeSent := []byte{}
			toBeSent = append(toBeSent, utils.DecToBin(fullNodeID, 2)...)
			if len(data) > 0 { // блок // block
				// if 0, we will read the block on the receiver, if = 1, then immediately we will read the hashes of transactions
				toBeSent = append(toBeSent, utils.DecToBin(0, 1)...)
				toBeSent = append(toBeSent, utils.DecToBin(utils.BytesToInt64(data["block_id"]), 3)...)
				toBeSent = append(toBeSent, data["hash"]...)
				err = d.ExecSQL("UPDATE info_block SET sent = 1")
				if err != nil {
					if d.dPrintSleep(err, d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
			} else { // transactions without block
				toBeSent = append(toBeSent, utils.DecToBin(1, 1)...)
			}
			logger.Debug("toBeSent block %x", toBeSent)

			// take the hashes of transactions
			//utils.WriteSelectiveLog("SELECT hash, high_rate FROM transactions WHERE sent = 0 AND for_self_use = 0")
			transactions, err := d.GetAll("SELECT hash, high_rate FROM transactions WHERE sent = 0 AND for_self_use = 0", -1)
			if err != nil {
				utils.WriteSelectiveLog(err)
				if d.dPrintSleep(err, d.sleepTime) {
					break BEGIN
				}
				continue BEGIN
			}
			// transaction and block for sending are absent...
			if len(transactions) == 0 && len(toBeSent) < 10 {
				//utils.WriteSelectiveLog("len(transactions) == 0")
				//log.Debug("len(transactions) == 0")
				if d.dSleep(d.sleepTime) {
					break BEGIN
				}
				logger.Debug("len(transactions) == 0 && len(toBeSent) == 0")
				continue BEGIN
			}
			for _, data := range transactions {
				hexHash := utils.BinToHex([]byte(data["hash"]))
				toBeSent = append(toBeSent, []byte(data["hash"])...)
				logger.Debug("hash %x", data["hash"])
				utils.WriteSelectiveLog("UPDATE transactions SET sent = 1 WHERE hex(hash) = " + string(hexHash))
				affect, err := d.ExecSQLGetAffect("UPDATE transactions SET sent = 1 WHERE hex(hash) = ?", hexHash)
				if err != nil {
					utils.WriteSelectiveLog(err)
					if d.dPrintSleep(err, d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
				utils.WriteSelectiveLog("affect: " + utils.Int64ToStr(affect))
			}

			logger.Debug("toBeSent %x", toBeSent)
			// send the block and hashes of transactions if there is anything to send
			if len(toBeSent) > 0 {
				for _, host := range hosts {
					go d.DisseminatorType1(host+":"+consts.TCP_PORT, toBeSent, dataType)
				}
			}
		} else {

			logger.Debug("1")

			dataType = 2

			logger.Debug("dataType: %d", dataType)

			var toBeSent []byte // here we record all transactions which we will send to other nodes
			// take hashes and transactions themselve
			utils.WriteSelectiveLog("SELECT hash, data FROM transactions WHERE sent  =  0")
			rows, err := d.Query("SELECT hash, data FROM transactions WHERE sent  =  0")
			if err != nil {
				utils.WriteSelectiveLog(err)
				if d.dPrintSleep(err, d.sleepTime) {
					break BEGIN
				}
				continue BEGIN
			}
			for rows.Next() {
				var hash, data []byte
				err = rows.Scan(&hash, &data)
				if err != nil {
					rows.Close()
					if d.dPrintSleep(err, d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
				logger.Debug("hash %x", hash)
				hashHex := utils.BinToHex(hash)
				utils.WriteSelectiveLog("UPDATE transactions SET sent = 1 WHERE hex(hash) = " + string(hashHex))
				affect, err := d.ExecSQLGetAffect("UPDATE transactions SET sent = 1 WHERE hex(hash) = ?", hashHex)
				if err != nil {
					utils.WriteSelectiveLog(err)
					rows.Close()
					if d.dPrintSleep(err, d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
				utils.WriteSelectiveLog("affect: " + utils.Int64ToStr(affect))
				toBeSent = append(toBeSent, data...)
			}
			rows.Close()

			// send the transactions
			if len(toBeSent) > 0 {
				for _, host := range hosts {

					go func(host string) {

						logger.Debug("host %v", host)

						conn, err := utils.TCPConn(host)
						if err != nil {
							logger.Error("%v", utils.ErrInfo(err))
							return
						}
						defer conn.Close()

						// at first we send the data type to let the host understand how exactly it has to process the sent data
						_, err = conn.Write(utils.DecToBin(dataType, 2))
						if err != nil {
							logger.Error("%v", utils.ErrInfo(err))
							return
						}

						// we record the data size in 4 bytes which we will send further
						size := utils.DecToBin(len(toBeSent), 4)
						_, err = conn.Write(size)
						if err != nil {
							logger.Error("%v", utils.ErrInfo(err))
							return
						}
						// further we send data itself
						_, err = conn.Write(toBeSent)
						if err != nil {
							logger.Error("%v", utils.ErrInfo(err))
							return
						}

					}(host + ":" + consts.TCP_PORT)
				}
			}
		}

		if d.dSleep(d.sleepTime) {
			break BEGIN
		}
	}
	logger.Debug("break BEGIN %v", GoroutineName)
}

func (d *daemon) DisseminatorType1(host string, toBeSent []byte, dataType int64) {

	logger.Debug("host %v", host)

	// send data itself to the specified host
	conn, err := utils.TCPConn(host)
	if err != nil {
		logger.Error("%v", utils.ErrInfo(err))
		return
	}
	defer conn.Close()

	// at first we send the data type to let the host understand how exactly it has to process the sent data
	n, err := conn.Write(utils.DecToBin(dataType, 2))
	if err != nil {
		logger.Error("%v", utils.ErrInfo(err))
		return
	}
	logger.Debug("n: %x (host : %v)", n, host)

	// we record the data size in 4 bytes which we will send further
	size := utils.DecToBin(len(toBeSent), 4)
	n, err = conn.Write(size)
	if err != nil {
		logger.Error("%v", utils.ErrInfo(err))
		return
	}
	logger.Debug("n: %x (host : %v)", n, host)
	n, err = conn.Write(toBeSent)
	if err != nil {
		logger.Error("%v", utils.ErrInfo(err))
		return
	}
	logger.Debug("n: %d / size: %v / len: %d  (host : %v)", n, utils.BinToDec(size), len(toBeSent), host)
	// as a response we recieve the data size which the server wants to transfer to us
	buf := make([]byte, 4)
	n, err = conn.Read(buf)
	if err != nil {
		logger.Error("%v", utils.ErrInfo(err))
		return
	}
	logger.Debug("n: %x (host : %v)", n, host)
	dataSize := utils.BinToDec(buf)
	logger.Debug("dataSize %d (host : %v)", dataSize, host)
	// if data is less than MAX_TX_SIZE, so get it
	if dataSize < consts.MAX_TX_SIZE && dataSize > 0 {
		binaryTxHashes := make([]byte, dataSize)
		_, err = io.ReadFull(conn, binaryTxHashes)
		if err != nil {
			logger.Error("%v", utils.ErrInfo(err))
			return
		}
		logger.Debug("binaryTxHashes %x (host : %v)", binaryTxHashes, host)
		var binaryTx []byte
		for {
			// Parse the list of transactions
			txHash := make([]byte, 16)
			if len(binaryTxHashes) >= 16 {
				txHash = utils.BytesShift(&binaryTxHashes, 16)
			}
			txHash = utils.BinToHex(txHash)
			logger.Debug("txHash %s (host : %v)", txHash, host)
			utils.WriteSelectiveLog("SELECT data FROM transactions WHERE hex(hash) = " + string(txHash))
			tx, err := d.Single("SELECT data FROM transactions WHERE hex(hash) = ?", txHash).Bytes()
			logger.Debug("tx %x", tx)
			if err != nil {
				utils.WriteSelectiveLog(err)
				logger.Error("%v", utils.ErrInfo(err))
				return
			}
			utils.WriteSelectiveLog("tx: " + string(utils.BinToHex(tx)))
			if len(tx) > 0 {
				binaryTx = append(binaryTx, utils.EncodeLengthPlusData(tx)...)
			}
			if len(binaryTxHashes) == 0 {
				break
			}
		}

		logger.Debug("binaryTx %x (host : %v)", binaryTx, host)

		// send to the server
		// we record the data size in 4 bytes which we will send further
		size := utils.DecToBin(len(binaryTx), 4)
		_, err = conn.Write(size)
		if err != nil {
			logger.Error("%v", utils.ErrInfo(err))
			return
		}
		// further send data itself
		_, err = conn.Write(binaryTx)
		if err != nil {
			logger.Error("%v", utils.ErrInfo(err))
			return
		}
	} else if dataSize == 0 {
		logger.Debug("dataSize == 0 (%v)", host)
	} else {
		logger.Error("incorrect dataSize  (host : %v)", host)
	}
}
