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

package daylight

import (
	"fmt"
	//	_ "image/png"
	"os/exec"
	"runtime"

	"github.com/GACHAIN/go-gachain-mvp/packages/consts"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
	"github.com/op/go-logging"
)

var (
	log       = logging.MustGetLogger("daylight")
	format    = logging.MustStringFormatter("%{color}%{time:15:04:05.000} %{shortfile} %{shortfunc} [%{level:.4s}] %{color:reset} %{message}[" + consts.VERSION + "]" + string(byte(0)))
	configIni map[string]string
)

/*
func firstBlock() {
	if *utils.GenerateFirstBlock == 1 {

		if len(*utils.FirstBlockPublicKey) == 0 {
			priv, pub, _ := lib.GenHexKeys()
			err := ioutil.WriteFile(*utils.Dir+"/PrivateKey", []byte(priv), 0644)
			if err != nil {
				log.Error("%v", utils.ErrInfo(err))
			}
			*utils.FirstBlockPublicKey = pub
		}
		if len(*utils.FirstBlockNodePublicKey) == 0 {
			priv, pub, _ := lib.GenHexKeys()
			err := ioutil.WriteFile(*utils.Dir+"/NodePrivateKey", []byte(priv), 0644)
			if err != nil {
				log.Error("%v", utils.ErrInfo(err))
			}
			*utils.FirstBlockNodePublicKey = pub
		}

		PublicKey := *utils.FirstBlockPublicKey
		//		PublicKeyBytes, _ := base64.StdEncoding.DecodeString(string(PublicKey))
		PublicKeyBytes, _ := hex.DecodeString(string(PublicKey))

		NodePublicKey := *utils.FirstBlockNodePublicKey
		//		NodePublicKeyBytes, _ := base64.StdEncoding.DecodeString(string(NodePublicKey))
		NodePublicKeyBytes, _ := hex.DecodeString(string(NodePublicKey))
		Host := *utils.FirstBlockHost

		var block, tx []byte
		iAddress := int64(lib.Address(PublicKeyBytes))
		now := lib.Time32()
		_, err := lib.BinMarshal(&block, &consts.BlockHeader{Type: 0, BlockID: 1, Time: now, WalletID: iAddress})
		if err != nil {
			log.Error("%v", utils.ErrInfo(err))
		}
		_, err = lib.BinMarshal(&tx, &consts.FirstBlock{TxHeader: consts.TxHeader{Type: 1,
			Time: now, WalletID: iAddress, CitizenID: 0},
			PublicKey: PublicKeyBytes, NodePublicKey: NodePublicKeyBytes, Host: string(Host)})
		if err != nil {
			log.Error("%v", utils.ErrInfo(err))
		}
		lib.EncodeLenByte(&block, tx)

		FirstBlockDir := ""
		if len(*utils.FirstBlockDir) == 0 {
			FirstBlockDir = *utils.Dir
		} else {
			FirstBlockDir = filepath.Join("", *utils.FirstBlockDir)
			if _, err := os.Stat(FirstBlockDir); os.IsNotExist(err) {
				if err = os.Mkdir(FirstBlockDir, 0755); err != nil {
					log.Error("%v", utils.ErrInfo(err))
				}
			}
		}
		ioutil.WriteFile(filepath.Join(FirstBlockDir, "1block"), block, 0644)
		os.Exit(0)
	}

}

// http://grokbase.com/t/gg/golang-nuts/12a9yhgr64/go-nuts-disable-directory-listing-with-http-fileserver#201210093cnylxyosmdfuf3wh5xqnwiut4
func noDirListing(h http.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/") {
			http.NotFound(w, r)
			return
		}
		h.ServeHTTP(w, r)
	})
}
*/
func openBrowser(BrowserHTTPHost string) {
	log.Debug("runtime.GOOS: %v", runtime.GOOS)
	var err error
	switch runtime.GOOS {
	case "linux":
		err = exec.Command("xdg-open", BrowserHTTPHost).Start()
	case "windows", "darwin":
		err = exec.Command("open", BrowserHTTPHost).Start()
		if err != nil {
			exec.Command("cmd", "/c", "start", BrowserHTTPHost).Start()
		}
	default:
		err = fmt.Errorf("unsupported platform")
	}
	if err != nil {
		log.Error("%v", err)
	}
}

// GetHTTPHost returns program's hosts
func GetHTTPHost() (string, string, string) {
	BrowserHTTPHost := "http://localhost:" + *utils.ListenHTTPPort
	HandleHTTPHost := ""
	ListenHTTPHost := ":" + *utils.ListenHTTPPort
	if len(*utils.TCPHost) > 0 {
		ListenHTTPHost = *utils.TCPHost + ":" + *utils.ListenHTTPPort
		BrowserHTTPHost = "http://" + *utils.TCPHost + ":" + *utils.ListenHTTPPort
	}
	return BrowserHTTPHost, HandleHTTPHost, ListenHTTPHost
}
