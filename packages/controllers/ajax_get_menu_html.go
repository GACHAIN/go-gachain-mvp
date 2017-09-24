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
	"github.com/GACHAIN/go-gachain-mvp/packages/textproc"
	"github.com/GACHAIN/go-gachain-mvp/packages/utils"
	//	"strings"
)

// AjaxGetMenuHtml is a controller for AjaxGetMenuHtml
func (c *Controller) AjaxGetMenuHtml() (string, error) {

	pageName := c.r.FormValue("page")

	global := c.r.FormValue("global")
	prefix := "global"
	if global == "" || global == "0" {
		prefix = c.StateIDStr
	}
	menuName := ``
	menu := ``
	var err error
	if len(prefix) > 0 {

		menuName, err = c.Single(`SELECT menu FROM "`+prefix+`_pages" WHERE name = ?`, pageName).String()
		if err != nil {
			return "", utils.ErrInfo(err)
		}
		menu, err = c.Single(`SELECT value FROM "`+prefix+`_menu" WHERE name = ?`, menuName).String()
		if err != nil {
			return "", utils.ErrInfo(err)
		}
	}
	/*	outmenu := ReplaceMenu(menu)
		menu = fmt.Sprintf(`{"idname": "%s", "menu": "%s<script>
		$('.aside .nav li').removeClass('active');
		$('.citizen_`+pageName+`').addClass('active');
		</script>"}`, menuName, strings.Replace(strings.Replace(outmenu, "\"", "\\\"", -1), `li class='`, `li class='menu_page `, -1))

		return strings.Replace(strings.Replace(strings.Replace(menu, "\n", "", -1), "\r", "", -1), "\t", "", -1), nil
	*/
	params := make(map[string]string)
	params[`state_id`] = c.StateIDStr
	params[`accept_lang`] = c.r.Header.Get(`Accept-Language`)
	if len(menu) > 0 {
		menu = utils.LangMacro(textproc.Process(menu, &params), utils.StrToInt(c.StateIDStr), params[`accept_lang`]) +
			`<!--#` + menuName + `#-->`
	}
	return menu, nil

}
