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
	"flag"
	//	"fmt"
	"net"
	//	"runtime"
	"sync"

	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
	"github.com/op/go-logging"
)

var (
	log     = logging.MustGetLogger("tcpserver")
	counter int64
	mutex   = &sync.Mutex{}
)

func init() {
	flag.Parse()
}

// TCPServer is a structure for TCP connecvtion
type TCPServer struct {
	*utils.DCDB
	Conn net.Conn
}

func (t *TCPServer) deferClose() {
	t.Conn.Close()
	mutex.Lock()
	counter--
	//	fmt.Println("--", counter)
	mutex.Unlock()
}

// HandleTCPRequest proceed TCP requests
func (t *TCPServer) HandleTCPRequest() {

	/*	fmt.Println("NumCPU:", runtime.NumCPU(),
		" NumGoRoutine:", runtime.NumGoroutine(),
		" t.counter:", counter)
	*/
	var err error

	log.Debug("HandleTCPRequest from %v", t.Conn.RemoteAddr())
	defer t.deferClose()

	mutex.Lock()
	if counter > 20 {
		t.Conn.Close()
		mutex.Unlock()
		return
	}
	counter++
	//		fmt.Println("++", counter)
	mutex.Unlock()

	// data type
	buf := make([]byte, 2)
	_, err = t.Conn.Read(buf)
	if err != nil {
		log.Error("%v", utils.ErrInfo(err))
		return
	}
	dataType := utils.BinToDec(buf)
	log.Debug("dataType %v", dataType)
	switch dataType {
	case 1:
		t.Type1()
	case 2:
		t.Type2()
	case 4:
		t.Type4()
	case 7:
		t.Type7()
	case 10:
		t.Type10()
	}
	log.Debug("END")
}
