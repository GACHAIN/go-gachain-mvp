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

type installStep0Struct struct {
	Lang map[string]string
	//KeyPassword string
}

// InstallStep0 is a controller for the first step of the installation
// Step 1, select either standard settings (sqlite and blockchain from the server) or extended settings pg/mysql and upload from the nodes
func (c *Controller) InstallStep0() (string, error) {

	//keyPassword := c.r.FormValue("key_password")

	TemplateStr, err := makeTemplate("install_step_0", "installStep0", &installStep0Struct{
		Lang: c.Lang})
	if err != nil {
		return "", utils.ErrInfo(err)
	}
	return TemplateStr, nil
}
