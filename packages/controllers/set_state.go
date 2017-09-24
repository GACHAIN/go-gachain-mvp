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
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

const aSetState = `set_state`

type setStateJSON struct {
	Error string `json:"error"`
}

func init() {
	newPage(aSetState, `json`)
}

// SetState changes the state in the browser
func (c *Controller) SetState() interface{} {

	var result setStateJSON

	c.r.ParseForm()
	c.sess.Set("state_id", utils.StrToInt64(c.r.FormValue("state_id")))
	c.sess.Set("citizen_id", utils.StrToInt64(c.r.FormValue("citizen_id")))
	result.Error = ""
	return result //`{"result":1,"address": "` + address + `"}`, nil
}
