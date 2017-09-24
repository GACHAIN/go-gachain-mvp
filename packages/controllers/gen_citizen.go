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
	"html/template"
	//"github.com/GACHAIN/go-gachain-mvp/packages/utils"
)

const nGenCitizen = `gen_citizen`

type genCitizenPage struct {
	Data    *CommonPage
	Message string
	Unique  template.JS
}

func init() {
	newPage(nGenCitizen)
}

// GenCitizen is a control for creating a new citizen
func (c *Controller) GenCitizen() (string, error) {
	name := c.r.FormValue(`name`)
	message := ``
	if len(name) > 0 {
	}
	//prefix := utils.Int64ToStr(c.SessStateID)
	pageData := genCitizenPage{Data: c.Data, Message: message, Unique: template.JS(`255`)}
	return proceedTemplate(c, nGenCitizen, &pageData)
}
