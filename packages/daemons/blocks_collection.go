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
	"errors"
	"fmt"
	"io/ioutil"
	"os"

	"github.com/GACHAIN/go-gachain-mvp/packages/consts"
	"github.com/GACHAIN/go-gachain-mvp/packages/parser"
	"github.com/GACHAIN/go-gachain-mvp/packages/static"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

// BlocksCollection collects and parses blocks
func BlocksCollection(chBreaker chan bool, chAnswer chan string) {
	defer func() {
		if r := recover(); r != nil {
			logger.Error("daemon Recovered", r)
			panic(r)
		}
	}()

	const GoroutineName = "BlocksCollection"
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
	//var cur bool
	var file *os.File
BEGIN:
	for {
		if file != nil {
			file.Close()
			file = nil
		}
		logger.Info(GoroutineName)
		MonitorDaemonCh <- []string{GoroutineName, utils.Int64ToStr(utils.Time())}

		// check if we have to break the cycle
		if CheckDaemonsRestart(chBreaker, chAnswer, GoroutineName) {
			break BEGIN
		}
		logger.Debug("0")
		config, err := d.GetNodeConfig()
		if err != nil {
			if d.dPrintSleep(err, d.sleepTime) {
				break BEGIN
			}
			continue BEGIN
		}
		logger.Debug("1")

		// remove that disturbs
		if *utils.StartBlockID > 0 {
			del := []string{"queue_tx", "my_notifications", "main_lock"}
			for _, table := range del {
				err := utils.DB.ExecSQL(`DELETE FROM ` + table)
				fmt.Println(`DELETE FROM ` + table)
				if err != nil {
					fmt.Println(err)
					panic(err)
				}
			}
		}

		restart, err := d.dbLock()
		if restart {
			logger.Debug("restart true")
			break BEGIN
		}
		if err != nil {
			logger.Debug("restart err %v", err)
			if d.dPrintSleep(err, d.sleepTime) {
				break BEGIN
			}
			continue BEGIN
		}
		logger.Debug("2")

		// if this is the first launch during the installation
		currentBlockID, err := d.GetBlockID()
		if err != nil {
			if d.unlockPrintSleep(err, d.sleepTime) {
				break BEGIN
			}
			continue BEGIN
		}

		logger.Info("config", config)
		logger.Info("currentBlockID", currentBlockID)

		// for duration of the tests
		/*if !cur {
		    currentBlockID = 0
		    cur = true
		}*/

		parser := new(parser.Parser)
		parser.DCDB = d.DCDB
		parser.GoroutineName = GoroutineName
		if currentBlockID == 0 || *utils.StartBlockID > 0 {
			/*
			   IsNotExistBlockChain := false
			   if _, err := os.Stat(*utils.Dir+"/public/blockchain"); os.IsNotExist(err) {
			       IsNotExistBlockChain = true
			   }*/
			if config["first_load_blockchain"] == "file" /* && IsNotExistBlockChain*/ {

				logger.Info("first_load_blockchain=file")
				//nodeConfig, err := d.GetNodeConfig()
				blockchainURL := config["first_load_blockchain_url"]
				if len(blockchainURL) == 0 {
					blockchainURL = consts.BLOCKCHAIN_URL
				}
				logger.Debug("blockchainURL: %s", blockchainURL)
				// probably server will not give the blockchain from the first attempt
				var blockchainSize int64
				for i := 0; i < 10; i++ {
					logger.Debug("blockchainURL: %s, i: %d", blockchainURL, i)
					blockchainSize, err = utils.DownloadToFile(blockchainURL, *utils.Dir+"/public/blockchain", 3600, chBreaker, chAnswer, GoroutineName)
					if err != nil {
						logger.Error("%v", utils.ErrInfo(err))
					}
					if blockchainSize > consts.BLOCKCHAIN_SIZE {
						break
					}
				}
				logger.Debug("blockchain dw ok")
				if err != nil || blockchainSize < consts.BLOCKCHAIN_SIZE {
					if err != nil {
						logger.Error("%v", utils.ErrInfo(err))
					} else {
						logger.Info(fmt.Sprintf("%v < %v", blockchainSize, consts.BLOCKCHAIN_SIZE))
					}
					if d.unlockPrintSleep(err, d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}

				first := true
				/*// blockchain could be uploaded earlier, check it's size


								  stat, err := file.Stat()
								  if err != nil {
								      if d.unlockPrintSleep(err, d.sleepTime) {	break BEGIN }
								      file.Close()
								      continue BEGIN
								  }
								  if stat.Size() < consts.BLOCKCHAIN_SIZE {
								      d.unlockPrintSleep(fmt.Errorf("%v < %v", stat.Size(), consts.BLOCKCHAIN_SIZE), 1)
								      file.Close()
								      continue BEGIN
								  }*/

				logger.Debug("GO!")
				file, err = os.Open(*utils.Dir + "/public/blockchain")
				if err != nil {
					if d.unlockPrintSleep(err, d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
				err = d.ExecSQL(`UPDATE config SET current_load_blockchain = 'file'`)
				if err != nil {
					if d.unlockPrintSleep(err, d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}

				for {
					// check if we have to break the cycle
					if CheckDaemonsRestart(chBreaker, chAnswer, GoroutineName) {
						d.unlockPrintSleep(fmt.Errorf("DaemonsRestart"), 0)
						break BEGIN
					}
					b1 := make([]byte, 5)
					file.Read(b1)
					dataSize := utils.BinToDec(b1)
					logger.Debug("dataSize", dataSize)
					if dataSize > 0 {

						data := make([]byte, dataSize)
						file.Read(data)
						logger.Debug("data %x\n", data)
						blockID := utils.BinToDec(data[0:5])
						if *utils.EndBlockID > 0 && blockID == *utils.EndBlockID {
							if d.dPrintSleep(err, d.sleepTime) {
								break BEGIN
							}
							continue BEGIN
						}
						logger.Info("blockID", blockID)
						data2 := data[5:]
						length := utils.DecodeLength(&data2)
						logger.Debug("length", length)
						//logger.Debug("data2 %x\n", data2)
						blockBin := utils.BytesShift(&data2, length)
						//logger.Debug("blockBin %x\n", blockBin)

						if *utils.StartBlockID == 0 || (*utils.StartBlockID > 0 && blockID > *utils.StartBlockID) {

							logger.Debug("block parsing")
							// parsing of a block
							parser.BinaryData = blockBin

							if first {
								parser.CurrentVersion = consts.VERSION
								first = false
							}

							if err = parser.ParseDataFull(false); err != nil {
								logger.Error("%v", err)
								parser.BlockError(err)
								if d.dPrintSleep(err, d.sleepTime) {
									break BEGIN
								}
								continue BEGIN
							}
							if err = parser.InsertIntoBlockchain(); err != nil {
								if d.dPrintSleep(err, d.sleepTime) {
									break BEGIN
								}
								continue BEGIN
							}

							// mark ourselves for not to cause the cleaning of tables
							if err = parser.UpdMainLock(); err != nil {
								if d.dPrintSleep(err, d.sleepTime) {
									break BEGIN
								}
								continue BEGIN
							}
							if CheckDaemonsRestart(chBreaker, chAnswer, GoroutineName) {
								d.unlockPrintSleep(nil, 0)
								/*!!!								if d.dPrintSleep(err, d.sleepTime) {
									break BEGIN
								}*/
								break BEGIN
								//!!!   						continue BEGIN
							}
						}
						// the size which is unnecessary here at the end of the data block
						data = make([]byte, 5)
						file.Read(data)
					} else {
						if d.unlockPrintSleep(nil, d.sleepTime) {
							break BEGIN
						}
						continue BEGIN
					}
					// utils.Sleep(1)
				}
				file.Close()
				file = nil
			} else {

				var newBlock []byte
				if len(*utils.FirstBlockDir) > 0 {
					newBlock, _ = ioutil.ReadFile(*utils.FirstBlockDir + "/1block")
				} else {
					newBlock, err = static.Asset("static/1block")
					if err != nil {
						if d.dPrintSleep(err, d.sleepTime) {
							break BEGIN
						}
						continue BEGIN
					}
				}
				parser.BinaryData = newBlock
				parser.CurrentVersion = consts.VERSION

				if err = parser.ParseDataFull(false); err != nil {
					logger.Error("%v", err)
					parser.BlockError(err)
					if d.dPrintSleep(err, d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
				logger.Debug("ParseDataFull ok")
				if err = parser.InsertIntoBlockchain(); err != nil {
					if d.dPrintSleep(err, d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
				logger.Debug("InsertIntoBlockchain ok")
			}
			utils.Sleep(1)
			d.dbUnlock()
			continue BEGIN
		}
		d.dbUnlock()

		logger.Debug("UPDATE config SET current_load_blockchain = 'nodes'")
		err = d.ExecSQL(`UPDATE config SET current_load_blockchain = 'nodes'`)
		if err != nil {
			//!!!			d.unlockPrintSleep(err, d.sleepTime) unlock was higher 
			if d.dPrintSleep(err, d.sleepTime) {
				break
			}
			continue
		}

		hosts, err := d.GetHosts()
		if err != nil {
			logger.Error("%v", err)
		}

		logger.Info("%v", hosts)
		if len(hosts) == 0 {
			if d.dPrintSleep(err, 1) {
				break BEGIN
			}
			continue
		}

		maxBlockID := int64(1)
		maxBlockIDHost := ""
		// receive the maximum block number
		for i := 0; i < len(hosts); i++ {
			if CheckDaemonsRestart(chBreaker, chAnswer, GoroutineName) {
				break BEGIN
			}
			conn, err := utils.TCPConn(hosts[i] + ":" + consts.TCP_PORT)
			if err != nil {
				if d.dPrintSleep(err, 1) {
					break BEGIN
				}
				continue
			}

			logger.Debug("conn", conn)

			// send the data type
			_, err = conn.Write(utils.DecToBin(consts.DATA_TYPE_MAX_BLOCK_ID, 2))
			if err != nil {
				conn.Close()
				if d.dPrintSleep(err, 1) {
					break BEGIN
				}
				continue
			}

			// obtain the block number as a response
			blockIDBin := make([]byte, 4)
			_, err = conn.Read(blockIDBin)
			if err != nil {
				conn.Close()
				if d.dPrintSleep(err, 1) {
					break BEGIN
				}
				continue
			}
			conn.Close()

			logger.Debug("blockIDBin %x", blockIDBin)

			id := utils.BinToDec(blockIDBin)
			if id > maxBlockID || i == 0 {
				maxBlockID = id
				maxBlockIDHost = hosts[i] + ":" + consts.TCP_PORT
			}
			if CheckDaemonsRestart(chBreaker, chAnswer, GoroutineName) {
				utils.Sleep(1)
				break BEGIN
			}
		}

		// obtain our current block number which we already have
		// wait until it will be unlocked and block it by ourselves. It's needed for not to be in the moment when data from block is already inserted in database but info_block is not updated yet
		restart, err = d.dbLock()
		if restart {
			break BEGIN
		}
		if err != nil {
			if d.dPrintSleep(err, d.sleepTime) {
				break BEGIN
			}
			continue BEGIN
		}

		currentBlockID, err = d.GetBlockID()
		if err != nil {
			if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
				break BEGIN
			}
			continue
		}
		logger.Info("currentBlockID", currentBlockID, "maxBlockID", maxBlockID)
		if maxBlockID <= currentBlockID {
			if d.unlockPrintSleepInfo(utils.ErrInfo(errors.New("maxBlockID <= currentBlockID")), d.sleepTime) {
				break BEGIN
			}
			continue
		}

		fmt.Printf("\nnode: %s curid=%d maxid=%d\n", maxBlockIDHost, currentBlockID, maxBlockID)

		/////----///////
		// we collect the blocks during the cycle, until we reach the maximum one
		for blockID := currentBlockID + 1; blockID < maxBlockID+1; blockID++ {
			d.UpdMainLock()
			if CheckDaemonsRestart(chBreaker, chAnswer, GoroutineName) {
				d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime)
				break BEGIN
			}

			// download the body of the block from the host maxBlockIDHost
			binaryBlock, err := utils.GetBlockBody(maxBlockIDHost, blockID, consts.DATA_TYPE_BLOCK_BODY)

			if len(binaryBlock) == 0 {
				// ban host which gave us an empty block (but had to give all to the maximum one) for 1 hour
				// remove for the tests then paste
				//nodes_ban ($db, $max_block_id_user_id, substr($binary_block, 0, 512)."\n".__FILE__.', '.__LINE__.', '. __FUNCTION__.', '.__CLASS__.', '. __METHOD__);
				//p.NodesBan("len(binaryBlock) == 0")
				if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
					break BEGIN
				}
				continue BEGIN
			}
			binaryBlockFull := binaryBlock
			utils.BytesShift(&binaryBlock, 1) // remove 1-st byte - type (block/transaction)
			// parse the heading of a block
			blockData := utils.ParseBlockHeader(&binaryBlock)
			logger.Info("blockData: %v, blockID: %v", blockData, blockID)

			// the size of a block couln't be more then max_block_size
			if currentBlockID > 1 {
				if int64(len(binaryBlock)) > consts.MAX_BLOCK_SIZE {
					d.NodesBan(fmt.Sprintf(`len(binaryBlock) > variables.Int64["max_block_size"]  %v > %v`, len(binaryBlock), consts.MAX_BLOCK_SIZE))
					if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
			}

			logger.Debug("currentBlockID %v", currentBlockID)

			if blockData.BlockId != blockID {
				d.NodesBan(fmt.Sprintf(`blockData.BlockId != blockID  %v > %v`, blockData.BlockId, blockID))
				if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
					break BEGIN
				}
				continue BEGIN
			}
			
			// we need the hash of the previous block, to check the signature
			prevBlockHash := ""
			if blockID > 1 {
				prevBlockHash, err = d.Single("SELECT hash FROM block_chain WHERE id = ?", blockID-1).String()
				if err != nil {
					if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
				prevBlockHash = string(utils.BinToHex([]byte(prevBlockHash)))
			} else {
				prevBlockHash = "0"
			}

			logger.Debug("prevBlockHash %x", prevBlockHash)

			first :=
				false
			if blockID == 1 {
				first = true
			}
			// we need the mrklRoot of current block
			mrklRoot, err := utils.GetMrklroot(binaryBlock, first)
			if err != nil {
				d.NodesBan(fmt.Sprintf(`%v`, err))
				if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
					break BEGIN
				}
				continue BEGIN
			}

			logger.Debug("mrklRoot %s", mrklRoot)

			// public key of those who has generated this block
			nodePublicKey, err := d.GetNodePublicKeyWalletOrCB(blockData.WalletId, blockData.StateID)
			if err != nil {
				if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
					break BEGIN
				}
				continue BEGIN
			}

			logger.Debug("nodePublicKey %x", nodePublicKey)
			// SIGN from 128 bytes to 512 bytes. Signature from TYPE, BLOCK_ID, PREV_BLOCK_HASH, TIME, USER_ID, LEVEL, MRKL_ROOT
			forSign := fmt.Sprintf("0,%v,%v,%v,%v,%v,%s", blockData.BlockId, prevBlockHash, blockData.Time, blockData.WalletId, blockData.StateID, mrklRoot)
			logger.Debug("forSign %v", forSign)

			// check the signature
			if !first {
				_, err = utils.CheckSign([][]byte{nodePublicKey}, forSign, blockData.Sign, true)
			}

			// download the previous blocks until the hash of the previous one differs.
			// in other words while the signature with prevBlockHash is incorrect, while there is something in $error
			if err != nil {
				logger.Error("%v", utils.ErrInfo(err))
				if blockID < 1 {
					if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
				// it is necessary to make data in our database according with the data of the one who has the most recent block which we download
				err := parser.GetBlocks(blockID-1, maxBlockIDHost, "rollback_blocks_2", GoroutineName, consts.DATA_TYPE_BLOCK_BODY)
				if err != nil {
					logger.Error("%v", err)
					d.NodesBan(fmt.Sprintf(`blockID: %v / %v`, blockID, err))
					if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}

			} else {

				logger.Info("plug found blockID=%v\n", blockID)

				utils.WriteSelectiveLog("UPDATE transactions SET verified = 0 WHERE verified = 1 AND used = 0")
				affect, err := d.ExecSQLGetAffect("UPDATE transactions SET verified = 0 WHERE verified = 1 AND used = 0")
				if err != nil {
					utils.WriteSelectiveLog(err)
					if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
				utils.WriteSelectiveLog("affect: " + utils.Int64ToStr(affect))
				/*
									//var transactions []byte
									utils.WriteSelectiveLog("SELECT data FROM transactions WHERE verified = 1 AND used = 0")
									count, err := d.Query("SELECT data FROM transactions WHERE verified = 1 AND used = 0")
									if err != nil {
										utils.WriteSelectiveLog(err)
										if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
											break BEGIN
										}
										continue BEGIN
									}
									for rows.Next() {
										var data []byte
										err = rows.Scan(&data)
										utils.WriteSelectiveLog(utils.BinToHex(data))
										if err != nil {
											rows.Close()
											if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
												break BEGIN
											}
											continue BEGIN
										}
										//transactions = append(transactions, utils.EncodeLengthPlusData(data)...)
									}
									rows.Close()
									if len(transactions) > 0 {
										// mark that we have to check this transaction again
										utils.WriteSelectiveLog("UPDATE transactions SET verified = 0 WHERE verified = 1 AND used = 0")
										affect, err := d.ExecSQLGetAffect("UPDATE transactions SET verified = 0 WHERE verified = 1 AND used = 0")
										if err != nil {
											utils.WriteSelectiveLog(err)
											if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
												break BEGIN
											}
											continue BEGIN
										}
										utils.WriteSelectiveLog("affect: " + utils.Int64ToStr(affect))
										//  roll back all recent transactions on a front
										/*parser.BinaryData = transactions
										err = parser.ParseDataRollbackFront(false)
										if err != nil {
											utils.Sleep(1)
											continue BEGIN
										}*/
				/*}*/
			}

			// currently we have in our tables the same that the node, where we download the block, has 
			// and we can check this node and insert into database
			parser.BinaryData = binaryBlockFull

			err = parser.ParseDataFull(false)
			if err == nil {
				err = parser.InsertIntoBlockchain()
				if err != nil {
					logger.Error("%v", err)
					if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
						break BEGIN
					}
					continue BEGIN
				}
			}
			// Start from the beginning already with other nodes. But we could have new blocks to $block_id taking from the node wich we eventually ban 
			if err != nil {
				logger.Error("%v", err)
				parser.BlockError(err)
				d.NodesBan(fmt.Sprintf(`blockID: %v / %v`, blockID, err))
				if d.unlockPrintSleep(utils.ErrInfo(err), d.sleepTime) {
					break BEGIN
				}
				continue BEGIN
			}
		}

		d.dbUnlock()

		if d.dSleep(d.sleepTime) {
			break
			//continue
		}
	}
	if file != nil {
		file.Close()
	}

	logger.Debug("break BEGIN %v", GoroutineName)
}
