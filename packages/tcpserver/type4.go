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

package tcpserver

import (
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

/*
 * Data is sent by 'confirmations' daemon
*/

// Type4 writes the hash of the specified block
func (t *TCPServer) Type4() {

	buf := make([]byte, 4)
	_, err := t.Conn.Read(buf)
	if err != nil {
		log.Error("%v", utils.ErrInfo(err))
		return
	}
	blockID := utils.BinToDec(buf)
	log.Debug("blockID %d", blockID)
	// It is used to account the number of confirmed blocks, those which belong to majority of nodes
	hash, err := t.Single("SELECT hash FROM block_chain WHERE id = ?", blockID).String()
	if err != nil {
		log.Error("%v", utils.ErrInfo(err))
		t.Conn.Write(utils.DecToBin(0, 1))
		return
	}
	if len(hash) == 0 {
		hash = "0"
	}
	log.Debug("hash %x", hash)
	_, err = t.Conn.Write([]byte(hash))
	if err != nil {
		log.Error("%v", utils.ErrInfo(err))
		return
	}
}
