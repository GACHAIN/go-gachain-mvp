SetVar(
	global = 0,
	type_new_page_id = TxId(NewPage),
	type_append_page_id = TxId(AppendPage),
	type_new_menu_id = TxId(NewMenu),
	type_edit_table_id = TxId(EditTable),
	type_edit_column_id = TxId(EditColumn),
	type_append_menu_id = TxId(AppendMenu),
	type_new_lang_id = TxId(NewLang),
	type_new_contract_id = TxId(NewContract),
	type_activate_contract_id = TxId(ActivateContract),
	type_new_sign_id = TxId(NewSign),
	type_new_state_params_id = TxId(NewStateParameters), 
	type_new_table_id = TxId(NewTable))
SetVar(`sc_AddLand #= contract AddLand {
	data {
		coords string "polymap"
		land_use int "@land_use"
		buildings_use_class int "@buildings_use_class"
		area int
		coords_address string
		owner_id string

	}
	func conditions {
	    
	    $citizen_id = AddressToId($owner_id)
	    
	    if ! DBInt(Table("citizens"), "id", $citizen_id) {
			warning "not valid citizen id"
		}
		
	}
	func action {
	    var lend_object_id int
		lend_object_id = DBInsert(Table("land_registry"), "address, area, buildings_use_class,coords, land_use, timestamp date_insert", $coords_address, $area, $buildings_use_class,  $coords, $land_use, $block_time)
		
		 DBInsert(Table("land_ownership"), "timestamp  date_creat, timestamp date_signing, lend_object_id,owner_id,owner_new_id", $block_time, $block_time, lend_object_id,$citizen_id,$citizen_id)
	}
}`,
`scc_AddLand #= ContractConditions("MainCondition")`,
`sc_AddProperty #= contract AddProperty {
    
	data {

		coords string "polymap"
		property_types int 
		area int
		coords_address string
		owner_id string
    }
    
	func conditions {
	    
	    $citizen_id = AddressToId($owner_id)
	    
	    if ! DBInt(Table("citizens"), "id", $citizen_id) {
			warning "not valid citizen id"
		}
	}
	
	func action {
	    var lend_object_id int
		DBInsert(Table("property"), "name, area, type,coords,citizen_id", $coords_address, $area, $property_types,$coords,$citizen_id)
	}
	
}`,
`scc_AddProperty #= ContractConditions("MainCondition")`,
`sc_chat_notification_close #= contract chat_notification_close {
    data {
        message_id int
    }

    conditions {
        CitizenCondition()
    }

    action {
        var incoming_notification_id int
        incoming_notification_id = DBIntWhere(Table("notification"), "id", "page_name = 'Chat_history' and page_value = ? and closed = 0 and recipient_id = ?", $message_id, $citizen)
        if incoming_notification_id > 0 {
            notification_single_close("NotificID", incoming_notification_id)
        }

    }
}`,
`scc_chat_notification_close #= ContractConditions("MainCondition")`,
`sc_chat_reply_to_message #= contract chat_reply_to_message {
    data {
        to int
        to_role int
        as_role int
        text string "optional"
        in_reply_to int
    }

    conditions {
        ContractConditions(``CitizenCondition``)
        if ($text == "") {
            warning "The message should not be empty"
        }
    }

    action {
        chat_send_private_message("to,to_role,as_role,text", $to, $to_role, $as_role, $text)
        var notification_id int
        notification_id = DBIntWhere(Table("notification"), "id", "page_name = 'Chat_history' and page_value = ? and recipient_id = ?", $in_reply_to, $citizen)
        notification_single_close("NotificID", notification_id)
    }
}`,
`scc_chat_reply_to_message #= ContractConditions("MainCondition")`,
`sc_chat_send_private_message #= contract chat_send_private_message {
    data {
        to int
        to_role int
        as_role int
        text string "optional"
    }

    conditions {
        ContractConditions(``CitizenCondition``)
        
        if ($text == "") {
            warning "The message should not be empty"
        }
    }

    action {
        var sender_avatar string
		sender_avatar = DBStringExt( Table("citizens"), "avatar", $citizen, "id")
		var sender_name string
		sender_name = DBStringExt( Table("citizens"), "name", $citizen, "id")

		var receiver_avatar string
		var receiver_name string
		
		if $to != 0 {
		    receiver_avatar = DBStringExt( Table("citizens"), "avatar", $to, "id")
		    receiver_name = DBStringExt( Table("citizens"), "name", $to, "id")
		} else {
		    receiver_avatar = ""
		    receiver_name = ""
		}
		
		var message_id int
        message_id = DBInsert(Table("chat_private_messages"),
            "sender,receiver,message,sender_avatar,sender_name,receiver_avatar,receiver_name,receiver_role_id,sender_role_id",
            $citizen, $to, $text,sender_avatar,sender_name,receiver_avatar,receiver_name,$to_role,$as_role)
        

        if $as_role == 0 && $to_role == 0 {
	        var lower_id int
	        var higher_id int
	        if $citizen > $to {
	            lower_id = $to
	            higher_id = $citizen
	        } else {
	            lower_id = $citizen
	            higher_id = $to
	        }
	        var existing_chat_id int
	        existing_chat_id = DBIntWhere(Table("chat_private_chats"), "id", "lower_id=? and higher_id=?", lower_id, higher_id)
	        if existing_chat_id > 0 {
	            DBUpdate(Table("chat_private_chats"), existing_chat_id, 
	                "last_message,sender_id,receiver_id,sender_avatar,sender_name,receiver_avatar,receiver_name", 
	                $text, $citizen, $to, sender_avatar,sender_name,receiver_avatar,receiver_name)
	        } else {
	            DBInsert(Table("chat_private_chats"), 
	                "lower_id,higher_id,last_message,sender_id,receiver_id,sender_avatar,sender_name,receiver_avatar,receiver_name",
	                lower_id, higher_id, $text, $citizen, $to, sender_avatar,sender_name,receiver_avatar,receiver_name)
	        }
        } else {
            var role_id int
            var user_id int
            var last_message_frome_role int
            if $as_role > 0 {
                role_id = $as_role
                user_id = $to
                last_message_frome_role = 1
            } else {
                role_id = $to_role
                user_id = $citizen
                last_message_frome_role = 0
            }
            var existing_chat_id int
	        existing_chat_id = DBIntWhere(Table("chat_role_chats"), "id", "role_id=? and citizen_id=?", role_id, user_id)
	         if existing_chat_id > 0 {
	            DBUpdate(Table("chat_role_chats"), existing_chat_id, 
	                "last_message,citizen_id,role_id,sender_avatar,sender_name,last_message_frome_role", 
	                $text, user_id, role_id, sender_avatar,sender_name,last_message_frome_role)
	        } else {
	            DBInsert(Table("chat_role_chats"), 
	                "last_message,citizen_id,role_id,sender_avatar,sender_name,last_message_frome_role", 
	                $text, user_id, role_id, sender_avatar,sender_name,last_message_frome_role)
	        }
        }
        

        var notification_title string
        notification_title = Sprintf("Message from %v", sender_name)
        
        if $to_role == 0 { notification_single_send("NotificationIcon,NotificHeader,PageName,PageValue,RecipientID,TextBody,PageValue2", 3, notification_title, "Chat_history", message_id, IdToAddress($to), $text, "")
        } else {
            var closure_type int
            closure_type = 2
            
            notification_roles_send("NotificationIcon,NotificHeader,PageName,PageValue,RoleID,ClosureType,TextBody,PageValue2", 3, notification_title, "Chat_history", message_id, $to_role, closure_type, $text, "")
        }
        

    }
}`,
`scc_chat_send_private_message #= ContractConditions("MainCondition")`,
`sc_CitizenCondition #= contract CitizenCondition 
{
    
    data {   }

    conditions 
    {
    
        if !DBInt(Table("citizens"), "id", $citizen) 
        {
            warning "Sorry, you don't have access to this action"
        }

    }

    action {    }
}`,
`scc_CitizenCondition #= ContractConditions("MainCondition")`,
`sc_EditLand #= contract EditLand {
    data {
		LandId int "hidden"
		Coords string "polymap"
		land_use int "@land_use"
		buildings_use_class int "@buildings_use_class"
		area int
		coords_address string
	}
	func conditions {
		
	}
	func action {
	    
	    var str array
	    var attr array
	    var name string
	    var row map
	    
	    name = DBStringExt( Table("citizens"), "name", $citizen, "id")

        str = DBGetTable(Table("land_registry"), "address,area,buildings_use_class,coords,land_use", 0, -1, "", "id=?",$LandId)
        
        row = str[0]
        
        if($land_use!=Int(row["land_use"]))
        {
            DBInsert(Table("editing_land_registry"), "editing_attribute,lend_object_id,new_attr_value,old_attr_value,person_id,person_name,timestamp date", "land_use", $LandId, $land_use, Int(row["land_use"]),$citizen, name, $block_time)
        }
        
        if($buildings_use_class!=Int(row["buildings_use_class"]))
        {
            DBInsert(Table("editing_land_registry"), "editing_attribute,lend_object_id,new_attr_value,old_attr_value,person_id,person_name,timestamp date", "buildings_use_class", $LandId, $buildings_use_class, Int(row["buildings_use_class"]),$citizen, name, $block_time)
        }
        
        if($coords_address!=row["address"])
        {
            DBInsert(Table("editing_land_registry"), "editing_attribute,lend_object_id,new_attr_value,old_attr_value,person_id,person_name,timestamp date", "address", $LandId, $coords_address, row["address"],$citizen, name, $block_time)
        }
        
        if($Coords!=row["coords"])
        {
            DBInsert(Table("editing_land_registry"), "editing_attribute,lend_object_id,new_attr_value,old_attr_value,person_id,person_name,timestamp date", "coords", $LandId, $Coords, row["coords"],$citizen, name, $block_time)
        }
        
        if($area!=Int(row["area"]))
        {   
            DBInsert(Table("editing_land_registry"), "editing_attribute,lend_object_id,new_attr_value,old_attr_value,person_id,person_name,timestamp date", "area", $LandId, $area, row["area"],$citizen, name, $block_time)
        }

		DBUpdate(Table("land_registry"), $LandId, "address,area, buildings_use_class,coords,land_use", $coords_address, $area,$buildings_use_class,$Coords,$land_use)
	}
}`,
`scc_EditLand #= ContractConditions("MainCondition")`,
`sc_EditProperty #= contract EditProperty {
    
	data {
		PropertyId int "hidden"
		Coords string "polymap"
		CitizenId string "address"
		Name string
		police_inspection int
		PropertyType int "@property_types"
	}
	
	func conditions {
		if AddressToId($CitizenId) == 0 {
			error "invalid address"
		}
	}
	
	func action {
		DBUpdate(Table("property"), $PropertyId, "coords,citizen_id,type,name,police_inspection", $Coords, AddressToId($CitizenId),  $PropertyType,$Name,$police_inspection)
	}
	
}`,
`scc_EditProperty #= ContractConditions("MainCondition")`,
`sc_LandBuyContract #= contract LandBuyContract {
    data {
        buyer_id int
        LandId int 
        owner_id int
    }

    conditions {
        
        if $citizen!=$buyer_id {
			warning "not valid citizen id"
		}
		
		if(DBIntWhere(Table("land_ownership"), "id", "owner_new_id=$ and lend_object_id=$", $citizen, $LandId))
		{
		    warning "Purchase contract already created."
		}

    }

    action {
        
         DBInsert(Table("land_ownership"), "timestamp date_creat,lend_object_id,owner_id,owner_new_id", $block_time,$LandId,0,$buyer_id)
    }
}`,
`scc_LandBuyContract #= ContractConditions("MainCondition")`,
`sc_LandSaleContract #= contract LandSaleContract 
{
    data {
        
        LandId int 
        owner_id int
        contract_id int
        notification_id int
        
    }

    conditions {
        
        if $citizen!=$owner_id {
            
			warning "not valid citizen id"
		}
		
		if(DBIntWhere(Table("land_ownership"), "id", "owner_id=$ and lend_object_id=$ and id=$", $citizen, $LandId, $contract_id))
		{
		    warning "Purchase contract has already been signed."
		}

    }

    action {
 
        DBUpdate(Table("land_ownership"), $contract_id, "owner_id,timestamp date_signing", $owner_id, $block_time)
    
    }
}`,
`scc_LandSaleContract #= ContractConditions("MainCondition")`,
`sc_MainCondition #= contract MainCondition {
            data {}
            conditions {
                    if(StateVal("gov_account")!=$citizen)
                    {
                        warning "Sorry, you don't have access to this action."
                    }
            }
            action {}
    }`,
`scc_MainCondition #= ContractConditions("MainCondition")`,
`sc_MemberEdit #= contract MemberEdit
{
    data 
    {
        MemberId string
        MemberBirthday string
        MemberSex string
		coords_address string
		coords string "polymap"
    }
    
    func conditions 
    {
        MainCondition()
        
        $int_MemberId = AddressToId($MemberId)
    }
    
    func action  
    { 
        DBUpdate(Table("citizens"), $int_MemberId,"newbirthday,newsex,newcoords,newaddress",$MemberBirthday,$MemberSex,$coords,$coords_address);
    }
}`,
`scc_MemberEdit #= ContractConditions("MainCondition")`,
`sc_members_Change_Status #= contract members_Change_Status
{
    data 
    {
        MemberId string
        PersonStatus int
        isDateExpiration int          
        DateExpiration string "date"    
    }
    
    func conditions 
    {
        MainCondition()
        
        $int_MemberId = AddressToId($MemberId)
    }
    
    func action  
    { 
        if ($PersonStatus > 1) && ($isDateExpiration == 1)
        {
           DBUpdate(Table("citizens"),$int_MemberId,"person_status,timestamp date_start,date_expiration", $PersonStatus, $block_time,$DateExpiration) 
        }
        else
        {
            DBUpdate(Table("citizens"),$int_MemberId,"person_status,timestamp date_start,date_expiration", $PersonStatus, $block_time,"NULL")
        }
    }
}`,
`scc_members_Change_Status #= ContractConditions("MainCondition")`,
`sc_members_Delete #= contract members_Delete
{
    data 
    {
        MemberId string
    }
    
    func conditions 
    {
        MainCondition()
        
        $int_MemberId = AddressToId($MemberId)
    }
    
    func action  
    { 
        DBUpdate(Table("citizens"),$int_MemberId,"timestamp date_end,person_status",$block_time,-1)
    }
}`,
`scc_members_Delete #= ContractConditions("MainCondition")`,
`sc_members_Request_Accept #= contract members_Request_Accept
{
    data 
    {
        RequestId int
        RequestName string
        PersonStatus int
        isDateExpiration int          
        DateExpiration string "date"   
    }
    
    func conditions 
    {
        MainCondition()
        
        $wallet_id = DBInt(Table( "citizenship_requests"), "dlt_wallet_id", $RequestId )
        
        if Balance($wallet_id) < Money(StateParam($state, "citizenship_price")) 
        {
			warning "Sorry, your balance does not contain enough funds"
		}
		
		var member_id int
        member_id = DBIntWhere(Table("citizens"), "id",  "id=?",  $wallet_id)
        
        if (member_id != 0)
        {
            warning "This member has already been added"
        }
    }
    
    func action  
    { 
        if ($PersonStatus > 1) && ($isDateExpiration == 1)
        {
            DBInsert(Table("citizens"), "id,person_status,block_id,name,lastname,timestamp date_start,date_expiration", $wallet_id, $PersonStatus, $block, $RequestName,$RequestLastName,$block_time,$DateExpiration)  
        }
        else
        {
            DBInsert(Table("citizens"), "id,person_status,block_id,name,timestamp date_start", $wallet_id, $PersonStatus, $block, $RequestName,$block_time)   
        }

        DBUpdate(Table("citizenship_requests"), $RequestId, "approved", 1)
    }
}`,
`scc_members_Request_Accept #= ContractConditions("MainCondition")`,
`sc_members_Request_Reject #= contract members_Request_Reject 
{
    data 
    {
        RequestId int
    }
    
    func conditions 
    {
        MainCondition()
    }
    
    func action  
    { 
        DBUpdate(Table("citizenship_requests"), $RequestId, "approved", -1)
    }
}`,
`scc_members_Request_Reject #= ContractConditions("MainCondition")`,
`sc_members_Return #= contract members_Return
{
    data 
    {
        MemberId string
    }
    
    func conditions 
    {
        MainCondition()
        
        $int_MemberId = AddressToId($MemberId)
    }
    
    func action  
    { 
        DBUpdate(Table("citizens"),$int_MemberId,"timestamp date_start,person_status,date_end,date_expiration",$block_time,1,"NULL","NULL")
    }
}`,
`scc_members_Return #= ContractConditions("MainCondition")`,
`sc_notification_role_close #= contract notification_role_close
{
    
    data 
    {
        NotificID int
    }

    conditions 
    {
        CitizenCondition()
        
        var role_id int
        role_id = DBIntWhere(Table("notification"), "role_id",  "id=?",  $NotificID)
        var assign_id int
        assign_id = DBIntWhere(Table("roles_assign"), "id",  "role_id=? and member_id=?",  role_id, $citizen)
        if (assign_id == 0)
        {
            warning "Sorry, you are not part of the role for which this notification is intended"  
        }
        
        var started_processing_id int
        started_processing_id = DBIntWhere(Table("notification"), "started_processing_id",  "id=?",  $NotificID)
        if (started_processing_id == 0)
        {
            warning "Sorry, processing of this notification has not yet begun"  
        }
        
        var finished_processing_id int
        finished_processing_id = DBIntWhere(Table("notification"), "finished_processing_id",  "id=?",  $NotificID)
        var isClosed int
        isClosed = DBIntWhere(Table("notification"), "closed",  "id=?",  $NotificID)
        if ( (finished_processing_id != 0) || (isClosed > 0) )
        {
            warning "Sorry, this notification has already been closed before"  
        }
        
        if (started_processing_id != $citizen)
        {
            warning "Sorry, processing of this notice began another member"   
        }
        
    }

    action 
    {
        DBUpdate(Table("notification"),$NotificID,"finished_processing_id,timestamp finished_processing_time,closed", $citizen, $block_time,1)
    }
    
}`,
`scc_notification_role_close #= ContractConditions("MainCondition")`,
`sc_notification_role_processing #= contract notification_role_processing
{
    
    data 
    {
        NotificID int
    }

    conditions 
    {
        CitizenCondition()
        
        var role_id int
        role_id = DBIntWhere(Table("notification"), "role_id",  "id=?",  $NotificID)
        var assign_id int
        assign_id = DBIntWhere(Table("roles_assign"), "id",  "role_id=? and member_id=?",  role_id, $citizen)
        if (assign_id == 0)
        {
            warning "Sorry, you are not part of the role for which this notification is intended"  
        }
        
        var started_processing_id int
        started_processing_id = DBIntWhere(Table("notification"), "started_processing_id",  "id=?",  $NotificID)
        if (started_processing_id != 0)
        {
            warning "Sorry, processing of this notification has already begun"  
        }
    }

    action 
    {
        DBUpdate(Table("notification"),$NotificID,"started_processing_id,timestamp started_processing_time", $citizen, $block_time)
    }
    
}`,
`scc_notification_role_processing #= ContractConditions("MainCondition")`,
`sc_notification_roles_send #= contract notification_roles_send 
{
    
    data 
    {
        NotificationIcon int
        NotificHeader string
        TextBody string
        PageName string
        PageValue int
        PageValue2 string
        RoleID int
        ClosureType int
    }

    conditions 
    {
        CitizenCondition()
    }

    action 
    {
        if ($ClosureType == 1)
        {

            DBInsert(Table("notification"), "icon,header,text_body,page_name,page_value,page_value2,type,role_id",$NotificationIcon, $NotificHeader, $TextBody, $PageName, $PageValue, $PageValue2, "role", $RoleID)
        }
        else
        {
    		var list array      
    		var i, len int      
    		var war map        
            
    		list = DBGetList(Table("roles_assign"), "member_id", 0, 100, "id desc", "role_id=$ and delete=0", $RoleID)
    		len = Len(list)
    		while i < len 
    		{
    			war = list[i]  
    			i = i + 1       
    
                DBInsert(Table("notification"), "icon,header,text_body,page_name,page_value,page_value2,type,recipient_id",$NotificationIcon, $NotificHeader, $TextBody, $PageName, $PageValue, $PageValue2, "single", Int(war["member_id"])) 
    		}
        }
    }
    
}`,
`scc_notification_roles_send #= ContractConditions("MainCondition")`,
`sc_notification_send #= contract notification_send 
{
    
    data 
    {

        NotificationIcon int
        NotificHeader string
        TextBody string
        PageName string
        PageValue int
        PageValue2 string
    
        RecipientID string "optional"
        
        RoleID int "optional"
        ClosureType int "optional"
    }

    conditions 
    {
        CitizenCondition()
    }

    action 
    {
        if ($RoleID > 0)
        {
            notification_roles_send("NotificationIcon,NotificHeader,TextBody,PageName,PageValue,PageValue2,RoleID,ClosureType",$NotificationIcon,$NotificHeader,$TextBody,$PageName,$PageValue,$PageValue2,$RoleID,$ClosureType)
            
        }
        else
        {
            notification_single_send("NotificationIcon,NotificHeader,TextBody,PageName,PageValue,PageValue2,RecipientID",$NotificationIcon,$NotificHeader,$TextBody,$PageName,$PageValue,$PageValue2,$RecipientID)
        }
    }
    
}`,
`scc_notification_send #= ContractConditions("MainCondition")`,
`sc_notification_single_close #= contract notification_single_close 
{
    
    data 
    {
        NotificID int
    }

    conditions 
    {
        
    }

    action 
    {
        DBUpdate(Table("notification"),$NotificID,"closed,timestamp finished_processing_time,finished_processing_id",1,$block_time,$citizen)
    }
    
}`,
`scc_notification_single_close #= ContractConditions("MainCondition")`,
`sc_notification_single_send #= contract notification_single_send 
{
    
    data 
    {
        NotificationIcon int
        NotificHeader string
        TextBody string
        PageName string
        PageValue int
        PageValue2 string
        RecipientID string
    }

    conditions 
    {
        CitizenCondition()
        
        $int_RecipientID = AddressToId($RecipientID)
    }

    action 
    {
        DBInsert(Table("notification"), "icon,header,text_body,page_name,page_value,page_value2,type,recipient_id",$NotificationIcon, $NotificHeader, $TextBody, $PageName, $PageValue, $PageValue2, "single", $int_RecipientID)  
    }
    
}`,
`scc_notification_single_send #= ContractConditions("MainCondition")`,
`sc_PropertyAcceptOffers #= contract PropertyAcceptOffers {
    
	data {
		OfferId int
	}

	func conditions {
	    
		var property_id int
		property_id = DBIntExt(Table("property_offers"), "property_id", $OfferId, "id")
		
		var citizen_id int
		citizen_id = DBIntExt(Table("property"), "citizen_id", property_id, "id")
		if citizen_id!=$citizen {
		    error "incorrect citizen"
		}
	}
	
	func action {

		var property_id int
		property_id = DBIntExt(Table("property_offers"), "property_id", $OfferId, "id")
		
		
		var sender_citizen_id int
		sender_citizen_id = DBIntExt(Table("property_offers"), "sender_citizen_id", $OfferId, "id")

		var price int
		price = DBIntExt(Table("property_offers"), "price", $OfferId, "id")

		var sender_id int
		sender_id = DBIntExt(Table("accounts"), "id", sender_citizen_id, "citizen_id")
		var recipient_id int
		recipient_id = DBIntExt(Table("accounts"), "id", $citizen, "citizen_id")

		DBUpdate(Table("property"), property_id, "citizen_id", sender_citizen_id)

	}
	
}`,
`scc_PropertyAcceptOffers #= ContractConditions("MainCondition")`,
`sc_PropertyRegistryChange #= contract PropertyRegistryChange {
    
    data {
        PropertyId int
        Column_name string
        Value int
        Signature string "optional hidden"
    }

    conditions {

    }

    action {
        DBUpdate(Table("property"), $PropertyId, $Column_name, $Value)
    }
    
}`,
`scc_PropertyRegistryChange #= ContractConditions("MainCondition")`,
`sc_PropertySendOffer #= contract PropertySendOffer {
    
	data {
		PropertyId int "hidden"
		OfferType int
		Price money
	}
	
	func action {
		DBInsert(Table("property_offers"), "property_id, type, price, sender_citizen_id", $PropertyId, $OfferType, $Price, $citizen)
		
		var offers int
		offers = DBInt(Table("property"), "offers", $PropertyId)
		DBUpdate(Table("property"), $PropertyId, "offers", offers+1)
	}
	
}`,
`scc_PropertySendOffer #= ContractConditions("MainCondition")`,
`sc_roles_Add #= contract roles_Add
{
    
	data 
	{
		position_name string
		position_type int
	}
	
	func conditions 
	{
        CitizenCondition()
	    
        var id_role int
        id_role = DBIntWhere(Table("roles_list"), "id",  "role_name=?",  $position_name)
        if id_role != 0    
        {
            warning "Sorry, this role has already been created"
        } 
	}
	
	func action 
	{
	    $creator_name =  DBStringWhere(Table("citizens"), "name",  "id=?",  $citizen)
	    
        DBInsert(Table("roles_list"), "role_type,role_name,creator_id,creator_name,timestamp date_create",$position_type,$position_name,$citizen,$creator_name,$block_time)
	}
	
}`,
`scc_roles_Add #= ContractConditions("MainCondition")`,
`sc_roles_Assign #= contract roles_Assign
{
    
    data 
	{
	    RoleID int
		MemberID int
	}
	
	func conditions 
	{
	    
        CitizenCondition()
        
        var isDelete int
        isDelete = DBIntWhere(Table("roles_list"), "delete",  "id=?", $RoleID)
        if (isDelete > 0)
        {
            warning "This role has been deleted"  
        }
        
        var id_creator int
        id_creator = DBIntWhere(Table("roles_list"), "creator_id",  "id=?", $RoleID)
        if (id_creator != $citizen)
        {
            warning "Sorry, you are not the creator of this role"  
        }
        
        var id_ct int
        id_ct = DBIntWhere(Table("roles_assign"), "id",  "role_id=? and member_id=? and delete=?", $RoleID, $MemberID, 0)
        if (id_ct > 0)
        {
            warning "This member has already been added"  
        }
	}
	
	func action 
	{
	    $role_name =  DBStringWhere(Table("roles_list"), "role_name",  "id=?",  $RoleID)
	    $role_type =  DBIntWhere(Table("roles_list"), "role_type",  "id=?",  $RoleID)
	    
	    $member_name =  DBStringWhere(Table("citizens"), "name",  "id=?",  $MemberID)
	    
	    if ($role_type == 1)  
	    {
	        $appointed_by_id = $citizen
	        $appointed_by_name =  DBStringWhere(Table("citizens"), "name",  "id=?", $appointed_by_id)
	        
	        DBInsert(Table("roles_assign"), "role_id,role_name,member_id,member_name,timestamp date_start,appointed_by_id,appointed_by_name", $RoleID, $role_name, $MemberID, $member_name, $block_time, $appointed_by_id, $appointed_by_name)
	    }
	    else
	    {
	        DBInsert(Table("roles_assign"), "role_id,role_name,member_id,member_name,timestamp date_start", $RoleID, $role_name, $MemberID, $member_name, $block_time)  
	    }
	}
	
}`,
`scc_roles_Assign #= ContractConditions("MainCondition")`,
`sc_roles_Del #= contract roles_Del
{
    
    data 
	{
		IDRole int
	}
	
	func conditions 
	{
        CitizenCondition()
        
        var id_creator int
        id_creator = DBIntWhere(Table("roles_list"), "creator_id",  "id=?",  $IDRole)
        if (id_creator != $citizen)
        {
            warning "Sorry, you are not the creator of this role"  
        }
	}
	
	func action 
	{
	    DBUpdate(Table("roles_list"),$IDRole,"delete,timestamp date_delete",1,$block_time)
	    
		var list array     
		var i, len int      
		var war map         
	   
		list = DBGetList(Table("roles_assign"), "id", 0, 100, "id desc", "role_id=$ and delete=0", $IDRole)
		len = Len(list)
		while i < len 
		{
			war = list[i]   
			i = i + 1      

            DBUpdate(Table("roles_assign"),Int(war["id"]),"delete,timestamp date_end",1,$block_time)
		}
		
		var list2 array      
		var i2, len2 int      
		var war2 map          
	  
		list2 = DBGetList(Table("notification"), "id", 0, 100, "id desc", "role_id=$ and closed=0", $IDRole)
		len2 = Len(list2)
		while i2 < len2 
		{
			war2 = list2[i2]   
			i2   = i2 + 1      

            DBUpdate(Table("notification"),Int(war2["id"]),"closed",1)
		}
	}
	
}`,
`scc_roles_Del #= ContractConditions("MainCondition")`,
`sc_roles_Search #= contract roles_Search
{
    
	data 
	{
		StrSearch   string
	}
	
	func conditions 
	{
	}
	
	func action
	{
	}
	
}`,
`scc_roles_Search #= ContractConditions("MainCondition")`,
`sc_roles_UnAssign #= contract roles_UnAssign
{
    
    data 
	{
	    assignID int
	}
	
	func conditions 
	{
	    
        var role_id int
        role_id = DBIntWhere(Table("roles_assign"), "role_id",  "id=?", $assignID)
        if (role_id == 0)
        {
            warning "Role was not found"  
        }
        
        var id_creator int
        id_creator = DBIntWhere(Table("roles_list"), "creator_id",  "id=?", role_id)
        if (id_creator != $citizen)
        {
            warning "Sorry, you are not the creator of this role"  
        }
	    
	}
	
	func action 
	{
	    DBUpdate(Table("roles_assign"),$assignID,"delete,timestamp date_end",1,$block_time)
	}
	
}`,
`scc_roles_UnAssign #= ContractConditions("MainCondition")`,
`sc_tokens_Account_Add #= contract tokens_Account_Add
{
    
	data 
	{
		TypeAccount int
		CitizenID string
	}
	
	func conditions 
	{
	    $intCitizen_id = AddressToId($CitizenID)
	    
        MainCondition()
        
        if ($TypeAccount == 1) || ($TypeAccount == 2)
        {
            var id_SysAcc int
            id_SysAcc = DBIntWhere(Table("accounts"), "id",  "type=? and onhold=?",  $TypeAccount, 0)
            
            if id_SysAcc > 0    
            {
                warning "Sorry, you can not perform this action. Account with this type has already been created"
            }
        }
        else
        {
            var id_Acc int
            id_Acc = DBIntWhere(Table("accounts"), "id",  "type=? and citizen_id=? and onhold=?",  $TypeAccount, $intCitizen_id, 0)
            
            if (id_Acc > 0)
            {
                warning "Sorry, you can not perform this action. This account has already been created"  
            }
        }
	}
	
	func action 
	{
        DBInsert(Table("accounts"), "citizen_id,type",$intCitizen_id, $TypeAccount)  
	}
	
}`,
`scc_tokens_Account_Add #= ContractConditions("MainCondition")`,
`sc_tokens_Account_Close #= contract tokens_Account_Close
{
    
    data 
	{
		idAccount int
	}
	
	func conditions 
	{
        MainCondition()
	}
	
	func action 
	{
	    DBUpdate(Table("accounts"),$idAccount,"onhold",1)
	}
	
}`,
`scc_tokens_Account_Close #= ContractConditions("MainCondition")`,
`sc_tokens_CheckingClose #= contract tokens_CheckingClose
{
    
	data 
	{
	}
	
	func conditions 
	{
	}
	
	func action 
	{
        var id_tokens int
        id_tokens = DBIntWhere(Table("accounts_tokens"), "id",  "delete=? and date_expiration < now()",  0)
        
        if id_tokens != 0    
        {
            tokens_Close("tokens_id",id_tokens) 
        }
	}
	
}`,
`scc_tokens_CheckingClose #= ContractConditions("MainCondition")`,
`sc_tokens_Close #= contract tokens_Close 
{
    
	data 
	{
		tokens_id int
	}
	
	func conditions 
	{
		MainCondition()
	}
	
	func action 
	{
		var list array   
		var i, len int      
		var war map         

		list = DBGetList(Table("accounts"), "id", 0, 100, "id desc", "onhold=$ or onhold=$ and type<>?", 0, 1, 2)
		len = Len(list)
		while i < len 
		{
			war = list[i]   
			i = i + 1      

            tokens_Account_Close("idAccount", Int(war["id"]))
		}
		
		DBUpdate(Table("accounts_tokens"), $tokens_id, "delete", "1")
	}
	
}`,
`scc_tokens_Close #= ContractConditions("MainCondition")`,
`sc_tokens_Emission #= contract tokens_Emission
{
	data 
	{
	    NameTokens string              
		TypeEmission int             
		RollbackTokens int            
		Amount money                    
		isDateExpiration int            
		DateExpiration string "date"   
		
		Signature string "signature:tokens_Money_Transfer"
	}
	
	func conditions 
	{

        MainCondition()                
        
        var id_tokens int
        id_tokens = DBIntWhere(Table("accounts_tokens"), "id",  "delete=?",  0)
        if id_tokens != 0    
        {
            warning "Sorry, you can not perform this action. Tokens have already been created"
        }

        $id_SysAccEmission = DBIntWhere(Table("accounts"), "id",  "onhold=? and type=?", 0, 1)

	    if ($id_SysAccEmission == 0)
	    {
	        warning "Sorry, you can not perform this action. Emission account not found"
	    }        
	}
	
	func action 
	{

	    if ($isDateExpiration == 0)
	    {
		    DBInsert(Table("accounts_tokens"), "name_tokens,timestamp date_create,type_emission,flag_rollback_tokens,amount,delete", $NameTokens, $block_time, $TypeEmission,$RollbackTokens,$Amount,0)
	    }
		else
		{
		    DBInsert(Table("accounts_tokens"), "name_tokens,timestamp date_create,type_emission,flag_rollback_tokens,amount,delete,date_expiration", $NameTokens, $block_time, $TypeEmission,$RollbackTokens,$Amount,0,$DateExpiration)
		}

		tokens_Money_Transfer("Amount,SenderAccountID,RecipientAccountID,Signature",$Amount,0,$id_SysAccEmission,$Signature)
	}
	
}`,
`scc_tokens_Emission #= ContractConditions("MainCondition")`,
`sc_tokens_EmissionAdd #= contract tokens_EmissionAdd
{
	data 
	{
		Amount money                   
		
		Signature string "signature:tokens_Money_Transfer"
	}
	
	func conditions 
	{
        MainCondition()
        
        $id_tokens = DBIntWhere(Table("accounts_tokens"), "id",  "delete=?",  0)
        if $id_tokens != 0    
        {
            var type_emission int
            type_emission = DBIntWhere(Table("accounts_tokens"), "type_emission",  "id=?",  $id_tokens)

            if type_emission == 2    
            {
        	    $id_SysAccEmission = DBIntWhere(Table("accounts"), "id",  "onhold=? and type=?", 0, 1)
        	    if ($id_SysAccEmission == 0)
                {
                    warning "Additional emissions can not be made. System account not found"
                }
            }
            else
            {
                warning "Additional emissions can not be made for this tokens"
            }
        }
        else
        {
            warning "Additional emissions can not be made. Tokens were not created"
        }
	}
	
	func action 
	{
        $amount_in_tokens = DBAmount(Table("accounts_tokens"), "id",  $id_tokens)
        $amount_in_tokens = $amount_in_tokens + $Amount
        DBUpdate(Table("accounts_tokens"),$id_tokens,"amount",$amount_in_tokens)
        tokens_Money_Transfer("Amount,SenderAccountID,RecipientAccountID,Signature",$Amount,0,$id_SysAccEmission,$Signature)
	}
	
}`,
`scc_tokens_EmissionAdd #= ContractConditions("MainCondition")`,
`sc_tokens_Money_Rollback #= contract tokens_Money_Rollback
{
    
	data 
	{
		AccountID int              
		Amount money              
		
		Signature string "signature:tokens_Money_Transfer"
	}
	
	func conditions 
	{

        MainCondition()   
    
        var id_tokens int
        id_tokens = DBIntWhere(Table("accounts_tokens"), "id",  "delete=?",  0)
        
        if id_tokens != 0    
        {
            var flag_rollback_tokens int
            flag_rollback_tokens = DBIntWhere(Table("accounts_tokens"), "flag_rollback_tokens",  "id=?",  id_tokens)
            if flag_rollback_tokens != 2   
            {
                warning "Rollback funds is not allowed for this token"
            }
        }
        else
        {
            warning "Rollback funds can not be made. Tokens were not created"
        }
        
        var type_AccountID int
        type_AccountID = DBIntWhere(Table("accounts"), "type",  "id=?",  $AccountID)
        if (type_AccountID == 2)
        {
            warning "Sorry, you can not rollback funds from trash-account"
        }
        
        var amount_Account money
        amount_Account = DBIntWhere(Table("accounts"), "amount",  "id=?",  $AccountID)
        if (amount_Account < $Amount )
        {
            warning "Sorry, account has insufficient funds for rollback"
        }
        
        $id_AccountTrash = DBIntWhere(Table("accounts"), "id",  "type=? and onhold=?",  2, 0)
        if ($id_AccountTrash == 0)
        {
            warning "Rollback funds can not be made. Trash-account were not created"
        }  
	}
	
	func action 
	{
        tokens_Money_Transfer("Amount,SenderAccountID,RecipientAccountID,Signature",$Amount,$AccountID,$id_AccountTrash,$Signature) 
	}
	
}`,
`scc_tokens_Money_Rollback #= ContractConditions("MainCondition")`,
`sc_tokens_Money_Transfer #= contract tokens_Money_Transfer
{

	data 
	{
		SenderAccountID int     
		RecipientAccountID int  
		Amount money           
		
		Signature string "optional hidden"
	}
	
	func conditions 
	{
	   
		var type_RecipientAccount int
		type_RecipientAccount = DBIntWhere(Table("accounts"), "type", "id=? and onhold=?", $RecipientAccountID, 0)
		
		if ( (type_RecipientAccount==1) && ($SenderAccountID != 0) ) 
		{
			warning "Sorry, you can not send money to the system account"
		}
		
		if ( (type_RecipientAccount==2) && ($Signature == "") )
		{
			warning "Sorry, you can not send money to the system account"
		}
        
		var onHold_RecipientAccount int
		onHold_RecipientAccount = DBIntWhere(Table("accounts"), "onhold", "id=?", $RecipientAccountID)
		if ( (onHold_RecipientAccount > 0) && (type_RecipientAccount != 2))
		{
			warning "Recipient account on hold."
		}

		if ($SenderAccountID == $RecipientAccountID) 
		{
			warning "Sender account ID and Recipient account ID are the same."
		}
	   
		if ($SenderAccountID!= 0)
		{
			var type_SenderAccount int
			type_SenderAccount = DBIntWhere(Table("accounts"), "type", "id=?", $SenderAccountID)
			if (type_SenderAccount == 1) 
			{
				MainCondition()                             
			}
			if (type_SenderAccount == 2) 
			{
				warning "Sorry, you can not send funds from trash-account"
			}
			
			var onHold_SenderAccount int
			onHold_SenderAccount = DBIntWhere(Table("accounts"), "onhold", "id=?", $SenderAccountID)
			if ( (onHold_SenderAccount > 0) && (type_RecipientAccount != 2) ) 
			{
				warning "Sender account on hold."          
			}
			
    		$amount_SenderAccount = DBAmount(Table("accounts"), "id", $SenderAccountID)
    		if ($amount_SenderAccount < $Amount) 
    		{
    		    warning "Sorry, your account has insufficient funds"
    		}
		}

		else 
		{
		    MainCondition()
		}
		
	}
	
	func action 
	{
		var amount_RecipientAccount money
		amount_RecipientAccount = DBIntWhere(Table("accounts"), "amount", "id=?", $RecipientAccountID)
        amount_RecipientAccount = amount_RecipientAccount + $Amount
        DBUpdate(Table("accounts"), $RecipientAccountID, "amount", amount_RecipientAccount)
		
		if ($SenderAccountID != 0) 
		{
		    $amount_SenderAccount = $amount_SenderAccount - $Amount
		    DBUpdate(Table("accounts"), $SenderAccountID, "amount", $amount_SenderAccount)  
		}
	}
	
}`,
`scc_tokens_Money_Transfer #= ContractConditions("MainCondition")`,
`sc_tokens_Money_Transfer_extra #= contract tokens_Money_Transfer_extra
{
    
	data 
	{
		SenderAccountType int   
		RecipientAccountID int 
		Amount money            
		
		Signature string "signature:tokens_Money_Transfer"
	}
	
	func conditions 
	{
        CitizenCondition()
	    
		$SenderAccountID = DBIntWhere(Table("accounts"), "id", "citizen_id=? and type=? and onhold=?", $citizen, $SenderAccountType, 0)
		
		if ($SenderAccountID == 0)
        {
            warning "Sorry, your account with this type was not found"
        } 
	}
	
	func action 
	{
        tokens_Money_Transfer("Amount,SenderAccountID,RecipientAccountID,Signature",$Amount,$SenderAccountID,$RecipientAccountID,$Signature) 
	}
	
}`,
`scc_tokens_Money_Transfer_extra #= ContractConditions("MainCondition")`,
`sc_tokens_SearchCitizen #= contract tokens_SearchCitizen
{
    
	data 
	{
	    StrSearch   string
	}
	
	func conditions 
	{
	}
	
	func action
	{
	}
	
}`,
`scc_tokens_SearchCitizen #= ContractConditions("MainCondition")`,
`sc_TXCitizenRequest #= contract TXCitizenRequest 
{
	data 
	{
		StateId    int    "hidden"
		FullName   string	
	}
	conditions 
	{
		if Balance($wallet) < StateParam($StateId, "citizenship_price") 
		{
			error "not enough money"
		}
	}
	action 
	{
		DBInsert(TableTx( "citizenship_requests"), "dlt_wallet_id,name,block_id", 
		    $wallet, $FullName, $block)
	}
}`,
`scc_TXCitizenRequest #= ContractConditions("MainCondition")`,
`sc_TXEditProfile #= contract TXEditProfile 
{
	data 
	{
	    name_first string
		name_last  string
		gender int
		photo string "image"
	}
	action 
	{
	  if $photo != "" {
	      DBUpdate(Table( "citizens"), $citizen, "name,name_last,gender,avatar",$name_first,$name_last,$gender,$photo)
	  } else {
	      DBUpdate(Table( "citizens"), $citizen, "name,name_last,gender",$name_first,$name_last,$gender)
	  }
	}
}`,
`scc_TXEditProfile #= ContractConditions("MainCondition")`,
`sc_votingAcceptCandidates #= contract votingAcceptCandidates 
{
    
    data 
    {
        votingID int
        candidateID int
        
        flag_notifics int
    }

    conditions 
    {

    }

    action 
    {
        if ($flag_notifics==1)
        {
            $notifc_id = DBIntWhere(Table("notification"), "id",  "page_name=? and page_value=? and recipient_id=?", "voting_view", $votingID, $citizen) 
        
            if($notifc_id != 0)
            {
                notification_single_close("NotificID", $notifc_id)
            }
        }

        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate < now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting has not yet begun. Try again later, please"
        }
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and enddate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting has expired. Voting is now not possible"
        } 

        $flag_decision = DBIntWhere(Table("voting_instances"), "flag_decision",  "id=?", $votingID)
        if ($flag_decision == 1)
        {
            warning "Decision was taken. Voting is now not possible"
        } 

        $voting_participants = DBIntWhere(Table("voting_participants"), "id",  "voting_id=? and member_id=?", $votingID,$citizen)
        if($voting_participants > 0)
        {
            DBUpdate(Table("voting_participants"), $voting_participants, "timestamp decision_date, decision", $block_time,$candidateID)
        }

        votingIncAcceptCandidate("votingID,candidateID",$votingID,$candidateID)
        votingUpdateDataForGraphs("votingID",$votingID)
    }
    
}`,
`scc_votingAcceptCandidates #= ContractConditions("MainCondition")`,
`sc_votingAcceptDecision #= contract votingAcceptDecision
{
    
    data 
    {
        votingID int
        flag_notifics int
    }

    conditions 
    {
   
    }

    action 
    {
        if ($flag_notifics==1)
        {
            $notifc_id = DBIntWhere(Table("notification"), "id",  "page_name=? and page_value=? and recipient_id=?", "voting_view", $votingID, $citizen) 
        
            if($notifc_id != 0)
            {
                notification_single_close("NotificID", $notifc_id)
            }
        }
        
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate < now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting has not yet begun. Try again later, please"
        }
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and enddate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting has expired. Voting is now not possible"
        } 
        
        $flag_decision = DBIntWhere(Table("voting_instances"), "flag_decision",  "id=?", $votingID)
        if ($flag_decision == 1)
        {
            warning "Decision was taken. Voting is now not possible"
        }         

        $voting_participants = DBIntWhere(Table("voting_participants"), "id",  "voting_id=? and member_id=?", $votingID, $citizen)
        if($voting_participants > 0)
        {
            DBUpdate(Table("voting_participants"), $voting_participants, "timestamp decision_date, decision", $block_time, 1)
        }

        votingIncAcceptOther("votingID",$votingID)
        votingUpdateDataForGraphs("votingID",$votingID)
    }
    
}`,
`scc_votingAcceptDecision #= ContractConditions("MainCondition")`,
`sc_votingAcceptDocument #= contract votingAcceptDocument
{
    
    data 
    {
        votingID int
        flag_notifics int
    }

    conditions 
    {
  
    }

    action 
    {
        if ($flag_notifics==1)
        {
            $notifc_id = DBIntWhere(Table("notification"), "id",  "page_name=? and page_value=? and recipient_id=?", "voting_view", $votingID, $citizen) 
        
            if($notifc_id != 0)
            {
                notification_single_close("NotificID", $notifc_id)
            }
        }
        
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate < now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting has not yet begun. Try again later, please"
        }
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and enddate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting has expired. Voting is now not possible"
        } 
        
        $flag_decision = DBIntWhere(Table("voting_instances"), "flag_decision",  "id=?", $votingID)
        if ($flag_decision == 1)
        {
            warning "Decision was taken. Voting is now not possible"
        } 

        $voting_participants = DBIntWhere(Table("voting_participants"), "id",  "voting_id=? and member_id=?", $votingID, $citizen)
        if($voting_participants > 0)
        {
            DBUpdate(Table("voting_participants"), $voting_participants, "timestamp decision_date, decision", $block_time, 1)
        }
        
        votingIncAcceptOther("votingID",$votingID)
        votingUpdateDataForGraphs("votingID",$votingID)
    }
    
}`,
`scc_votingAcceptDocument #= ContractConditions("MainCondition")`,
`sc_votingCheckDecision #= contract votingCheckDecision 
{
    data 
    {
        votingID int
    }

    conditions 
    {
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and enddate > now()", $votingID)
        if ($v_ID > 0)
        {
            warning "Voting has not expired. Try again later, please"
        }
        
        $creator_id = DBIntWhere(Table("voting_instances"), "creator_id",  "id=?", $votingID)
        if ($creator_id != $citizen)
        {
            warning "Only creator the voting can check decision"   
        }
    }

    action 
    {
        $flag_success = DBIntWhere(Table("voting_instances"), "flag_success",  "id=?", $votingID)
        
        if ($flag_success == 1)
        {
            $typedecision = DBIntWhere(Table("voting_instances"), "typedecision",  "id=?", $votingID)
            
            if ( ($typedecision == 1) || ($typedecision == 2) )
            {
                votingDecideCandidates("votingID",$votingID)   
            }
            if ($typedecision == 3)
            {
                votingDecideDocument("votingID",$votingID)   
            }
            if ($typedecision == 4)
            {
                votingDecideDecision("votingID",$votingID)   
            }
        }
        else
        {
            DBUpdate(Table("voting_instances"), $votingID, "flag_decision", -2)    
        }
    }
}`,
`scc_votingCheckDecision #= ContractConditions("MainCondition")`,
`sc_votingCreateNew #= contract votingCreateNew 
{
    
    data 
    {
        voting_name string
        description string
        typeParticipants int
        typeDecision int
        nowDate string "date"
        startDate string "date"
        endDate string "date"
        volume int
        quorum int
    }

    func conditions 
    {
        CitizenCondition()
        
        if ( $nowDate > $startDate )
        {
            warning "Voting start date is less than the current date"
        }
        
        if ( $startDate > $endDate )
        {
            warning "Voting end date is less than the start date"
        }
        
        if ( ($volume < 50) || ($volume > 100) )
        {
            warning "Volume should be in the range from 50 to 100"  
        }
        
        if ( ($quorum < 5) || ($quorum > 100) )
        {
            warning "Quorum should be in the range from 5 to 100"  
        }
        
    }

    func action 
    {
        $voting_id = DBInsert(Table("voting_instances"), "name,description,typeParticipants,typeDecision,startDate,endDate,volume,quorum,creator_id,flag_success,percent_success,number_participants,number_voters,flag_decision,flag_notifics,delete", $voting_name, $description, $typeParticipants, $typeDecision, $startDate, $endDate, $volume, $quorum, $citizen,0,0,0,0,0,0,0)
        
        if ($typeParticipants==1)
        {
            votingInvite("votingID,varID",$voting_id,0)
        }
    } 
    
}`,
`scc_votingCreateNew #= ContractConditions("MainCondition")`,
`sc_votingDecideCandidates #= contract votingDecideCandidates 
{
    
    data 
    {
        votingID int
    }

    conditions 
    {   }

    action 
    {

        $number_voters = DBIntWhere(Table("voting_instances"), "number_voters",  "id=?", $votingID)
        $optional_role_vacancies = DBIntWhere(Table("voting_instances"), "optional_role_vacancies",  "id=?", $votingID)
        $voting_name = DBStringWhere(Table("voting_instances"), "name",  "id=?", $votingID)
        $quorum = DBIntWhere(Table("voting_instances"), "quorum",  "id=?", $votingID)
        $optional_role_id = DBIntWhere(Table("voting_instances"), "optional_role_id",  "id=?", $votingID)
        $role_name =  DBStringWhere(Table("roles_list"), "role_name",  "id=?",  $optional_role_id)
        
        $number_inserts = 0
        $flag_decision = -1
        
		var list array      
		var i, len int      
		var war map         

		list = DBGetList(Table("voting_subject"), "member_id, number_accept", 0, 100, "number_accept desc", "voting_id=$", $votingID)
		
		len = Len(list)
		while i < len 
		{
			war = list[i]   
			i = i + 1      

            if ($number_inserts < $optional_role_vacancies)
            {

                $v_percent =  Int(war["number_accept"]) * 100 / $number_voters
                
                if ($v_percent >= $quorum)
                {
                    $member_name = DBStringWhere(Table("citizens"), "name",  "id=?", Int(war["member_id"]))
                    
                    DBInsert(Table("roles_assign"), "role_id,role_name,member_id,member_name,timestamp date_start,appointed_by_id,appointed_by_name", $optional_role_id, $role_name, Int(war["member_id"]),$member_name, $block_time, $votingID, $voting_name) 
                    
                    $number_inserts = $number_inserts + 1
                    $flag_decision = 1
                }
            }
		}
		
		DBUpdate(Table("voting_instances"), $votingID, "flag_decision", $flag_decision)
    }
}`,
`scc_votingDecideCandidates #= ContractConditions("MainCondition")`,
`sc_votingDecideDecision #= contract votingDecideDecision 
{
    data 
    {
        votingID int
    }

    conditions 
    {   }

    action 
    {
        $number_voters = DBIntWhere(Table("voting_instances"), "number_voters",  "id=?", $votingID)
        $number_accept = DBIntWhere(Table("voting_subject"), "number_accept",  "voting_id=?", $votingID)
        $quorum = DBIntWhere(Table("voting_instances"), "quorum",  "id=?", $votingID)
        $v_percent =  $number_accept  * 100 / $number_voters
        
        if ($v_percent >= $quorum)
        {
            $flag_decision = 1
        }
        else
        {
            $flag_decision = -1    
        }
        
        DBUpdate(Table("voting_instances"), $votingID, "flag_decision", $flag_decision)
        
        if ($flag_decision == 1)
        {
            $decisionTable  = DBIntWhere(Table("voting_subject"), "formal_decision_table",  "voting_id=?", $votingID)
            $decisionId     = DBIntWhere(Table("voting_subject"), "formal_decision_tableid",  "voting_id=?", $votingID)
            $decisionColumn = DBIntWhere(Table("voting_subject"), "formal_decision_column",  "voting_id=?", $votingID)
            $decisionValue  = DBIntWhere(Table("voting_subject"), "formal_decision_colvalue",  "voting_id=?", $votingID)
            
            DBUpdate(Table($decisionTable), $decisionId, $decisionColumn, $decisionValue)
        }
    }
}`,
`scc_votingDecideDecision #= ContractConditions("MainCondition")`,
`sc_votingDecideDocument #= contract votingDecideDocument 
{

    data 
    {
        votingID int
    }

    conditions 
    {   }

    action 
    {
        $number_voters = DBIntWhere(Table("voting_instances"), "number_voters",  "id=?", $votingID)
        $number_accept = DBIntWhere(Table("voting_subject"), "number_accept",  "voting_id=?", $votingID)
        $quorum = DBIntWhere(Table("voting_instances"), "quorum",  "id=?", $votingID)
        $v_percent =  $number_accept  * 100 / $number_voters
        
        if ($v_percent >= $quorum)
        {
            $flag_decision = 1
        }
        else
        {
            $flag_decision = -1    
        }
        
        DBUpdate(Table("voting_instances"), $votingID, "flag_decision", $flag_decision)
    }
}`,
`scc_votingDecideDocument #= ContractConditions("MainCondition")`,
`sc_votingDelete #= contract votingDelete
{
    data 
    {
        votingID int
    }

    conditions 
    {
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting already started. Delete voting impossible"
        }
    }

    action 
    {
        DBUpdate(Table("voting_instances"), $votingID, "delete", 1) 
    }
}`,
`scc_votingDelete #= ContractConditions("MainCondition")`,
`sc_votingIncAcceptCandidate #= contract votingIncAcceptCandidate 
{
    data 
    {
        votingID int
        candidateID int 
    }

    conditions 
    {

    }

    action 
    {
        $voting_subject = DBIntWhere(Table("voting_subject"), "id",  "voting_id=? and member_id=?", $votingID, $candidateID)
        $number_accept = DBIntWhere(Table("voting_subject"), "number_accept",  "id=?", $voting_subject)
        $number_accept = $number_accept + 1
        DBUpdate(Table("voting_subject"), $voting_subject, "number_accept", $number_accept)
    }
}`,
`scc_votingIncAcceptCandidate #= ContractConditions("MainCondition")`,
`sc_votingIncAcceptOther #= contract votingIncAcceptOther
{
    data 
    {
        votingID int
    }

    conditions 
    {
    }

    action 
    {
        $voting_subject = DBIntWhere(Table("voting_subject"), "id",  "voting_id=?", $votingID)
        $number_accept = DBIntWhere(Table("voting_subject"), "number_accept",  "id=?", $voting_subject)
        $number_accept = $number_accept + 1
        DBUpdate(Table("voting_subject"), $voting_subject, "number_accept", $number_accept)
    }
}`,
`scc_votingIncAcceptOther #= ContractConditions("MainCondition")`,
`sc_votingInvite #= contract votingInvite 
{
    
    data 
    {
        votingID int
        varID int
    }

    func conditions 
    {
        CitizenCondition()

        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and enddate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting has expired. Can not add new participants"
        }  

        $type_p = DBIntWhere(Table("voting_instances"), "typeparticipants",  "id=?", $votingID)
        if ($type_p == 1)
        {   }
        if ($type_p == 2)
        {
            $member_id= DBIntWhere(Table("voting_participants"), "member_id",  "voting_id=? and member_id=?", $votingID, $varID)
            if ($member_id != 0)
            {
                warning "Member has already been added before"
            }
        }
        if ($type_p == 3) 
        {
            $member_id= DBIntWhere(Table("voting_participants"), "member_id",  "voting_id=?", $votingID)
            if ($member_id != 0)
            {
                warning "Voting participants have already been added before"    
            }
        }        
    }

    func action 
    {
        $number_participants = DBIntWhere(Table("voting_instances"), "number_participants",  "id=?", $votingID) 
        
        
        if ($type_p == 1)     
        {
    		var list array    
    		var i, len int      
    		var war map     
            
    		list = DBGetList(Table("citizens"), "id", 0, 100, "id desc", "person_status>?", 0)
    		len = Len(list)
    		while i < len 
    		{
    			war = list[i]   
    			i = i + 1     
    
                DBInsert(Table("voting_participants"), "voting_id, member_id, decision", $votingID, Int(war["id"]), 0)
                $number_participants = $number_participants + 1
    		}
            
            DBUpdate(Table("voting_instances"), $votingID, "number_participants", $number_participants )
        }

        if ($type_p == 2)      
        {
            DBInsert(Table("voting_participants"), "voting_id, member_id, decision", $votingID, $varID, 0)
            $number_participants = $number_participants + 1
            DBUpdate(Table("voting_instances"), $votingID, "number_participants", $number_participants )
        }
        if ($type_p == 3)   
        {
    		var list array   
    		var i, len int    
    		var war map      
            
    		list = DBGetList(Table("roles_assign"), "member_id", 0, 100, "id desc", "role_id=$ and delete=0", $varID)
    		len = Len(list)
    		while i < len 
    		{
    			war = list[i]   
    			i = i + 1      
    
                DBInsert(Table("voting_participants"), "voting_id, member_id, decision", $votingID, Int(war["member_id"]), 0)
                
                $number_participants = $number_participants + 1
    		}
    	    DBUpdate(Table("voting_instances"), $votingID, "number_participants", $number_participants )	
        }
    } 
}`,
`scc_votingInvite #= ContractConditions("MainCondition")`,
`sc_votingRejectDecision #= contract votingRejectDecision 
{
    
    data 
    {
        votingID int
        flag_notifics int
    }

    conditions 
    {

    }

    action 
    {
        
        if ($flag_notifics==1)
        {
            $notifc_id = DBIntWhere(Table("notification"), "id",  "page_name=? and page_value=? and recipient_id=?", "voting_view", $votingID, $citizen) 
        
            if($notifc_id != 0)
            {
                notification_single_close("NotificID", $notifc_id)
            }
        }

        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate < now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting has not yet begun. Try again later, please"
        }
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and enddate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting has expired. Voting is now not possible"
        } 
        
        $flag_decision = DBIntWhere(Table("voting_instances"), "flag_decision",  "id=?", $votingID)
        if ($flag_decision == 1)
        {
            warning "Decision was taken. Voting is now not possible"
        } 
        
        $voting_participants = DBIntWhere(Table("voting_participants"), "id",  "voting_id=? and member_id=?", $votingID, $citizen)
        if($voting_participants > 0)
        {
            DBUpdate(Table("voting_participants"), $voting_participants, "timestamp decision_date, decision", $block_time, -1)
        }
        
        votingUpdateDataForGraphs("votingID",$votingID)
        
    }
}`,
`scc_votingRejectDecision #= ContractConditions("MainCondition")`,
`sc_votingRejectDocument #= contract votingRejectDocument 
{
    
    data 
    {
        votingID int
        flag_notifics int
    }

    conditions 
    {

    }

    action 
    {
        if ($flag_notifics==1)
        {
            $notifc_id = DBIntWhere(Table("notification"), "id",  "page_name=? and page_value=? and recipient_id=?", "voting_view", $votingID, $citizen) 
            
            if($notifc_id != 0)
            {
                notification_single_close("NotificID", $notifc_id)
            }
        }
        
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate < now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting has not yet begun. Try again later, please"
        }
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and enddate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting has expired. Voting is now not possible"
        } 
        
        $flag_decision = DBIntWhere(Table("voting_instances"), "flag_decision",  "id=?", $votingID)
        if ($flag_decision == 1)
        {
            warning "Decision was taken. Voting is now not possible"
        } 
        
        $voting_participants = DBIntWhere(Table("voting_participants"), "id",  "voting_id=? and member_id=?", $votingID, $citizen)
        if($voting_participants > 0)
        {
            DBUpdate(Table("voting_participants"), $voting_participants, "timestamp decision_date, decision", $block_time, -1)
        }
        
        votingUpdateDataForGraphs("votingID",$votingID)
    }
    
}`,
`scc_votingRejectDocument #= ContractConditions("MainCondition")`,
`sc_votingSearch #= contract votingSearch
{
    
	data 
	{
		StrSearch   string
	}
	
	func conditions 
	{
	}
	
	func action
	{
	}
	
}`,
`scc_votingSearch #= ContractConditions("MainCondition")`,
`sc_votingSendNotifics #= contract votingSendNotifics 
{
    data 
    {
        votingID int
    }

    conditions 
    {
        CitizenCondition()
    }

    action 
    {
        $voting_name = DBStringWhere(Table("voting_instances"), "name",  "id=?", $votingID) 

		var list array     
		var i, len int     
		var war map       
        
		list = DBGetList(Table("voting_participants"), "member_id", 0, 100, "id desc", "voting_id=?", $votingID)
		len = Len(list)
		while i < len 
		{
			war = list[i]   
			i = i + 1 
			
            $recipient = IdToAddress(Int(war["member_id"]))
            notification_send("NotificationIcon,NotificHeader,TextBody,PageName,PageValue,PageValue2,RecipientID,RoleID,ClosureType", 5, "Voting", $voting_name, "voting_view", $votingID, "", $recipient, 0, 0)
		}
		
		DBUpdate(Table("voting_instances"), $votingID, "flag_notifics", 1)
    }
}`,
`scc_votingSendNotifics #= ContractConditions("MainCondition")`,
`sc_votingSubjectApply #= contract votingSubjectApply
{
    data
    {
        votingID int
    }

    conditions 
    {
        CitizenCondition()
        
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting already started. New candidate can not be added"
        }
        
        $member_id = DBIntWhere(Table("voting_subject"), "member_id",  "voting_id=? and member_id=?", $votingID, $citizen)
        if ($member_id != 0)
        {
            warning "Your candidature for this role has already been added before"
        }
    }

    action 
    {
        DBInsert(Table("voting_subject"), "member_id, voting_id", $citizen, $votingID)
        
        $optional_number_cands = DBIntWhere(Table("voting_instances"), "optional_number_cands",  "id=?", $votingID)
        $optional_number_cands = $optional_number_cands + 1
        DBUpdate(Table("voting_instances"), $votingID, "optional_number_cands", $optional_number_cands)
        
        $optional_role_id           = DBIntWhere(Table("voting_instances"), "optional_role_id",  "id=?", $votingID)
        $optional_role_vacancies    = DBIntWhere(Table("voting_instances"), "optional_role_vacancies",  "id=?", $votingID)
        if ( ($optional_role_id > 0) && ($optional_role_vacancies > 0) )
        {
            DBUpdate(Table("voting_instances"), $votingID, "flag_fulldata", 1)
        }
    }
}`,
`scc_votingSubjectApply #= ContractConditions("MainCondition")`,
`sc_votingSubjectCandidates #= contract votingSubjectCandidates 
{
    data
    {
        votingID int
        memberID int
    }

    conditions 
    {
        CitizenCondition()
        
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting already started. New candidate can not be added"
        }
        
        $member_id = DBIntWhere(Table("voting_subject"), "member_id",  "voting_id=? and member_id=?", $votingID, $memberID)
        if ($member_id != 0)
        {
            warning "This candidature for this role has already been added before"
        } 
    }

    action 
    {
        DBInsert(Table("voting_subject"), "member_id, voting_id", $memberID, $votingID)
        
        $optional_number_cands = DBIntWhere(Table("voting_instances"), "optional_number_cands",  "id=?", $votingID)
        $optional_number_cands = $optional_number_cands + 1
        DBUpdate(Table("voting_instances"), $votingID, "optional_number_cands", $optional_number_cands)
        
        $optional_role_id           = DBIntWhere(Table("voting_instances"), "optional_role_id",  "id=?", $votingID)
        $optional_role_vacancies    = DBIntWhere(Table("voting_instances"), "optional_role_vacancies",  "id=?", $votingID)
        if ( ($optional_role_id > 0) && ($optional_role_vacancies > 0) )
        {
            DBUpdate(Table("voting_instances"), $votingID, "flag_fulldata", 1)
        }
    }
}`,
`scc_votingSubjectCandidates #= ContractConditions("MainCondition")`,
`sc_votingSubjectDocument #= contract votingSubjectDocument 
{
    data 
    {
        votingID int
        text_document string
    }

    func conditions 
    {
        CitizenCondition()
        
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting already started. Can not edit document"
        }
    }

    func action 
    {
        $hash = Sha256($text_document)
        $voting_subject = DBIntWhere(Table("voting_subject"), "id", "voting_id = ?", $votingID)
        
        if $voting_subject == 0 
        {
            DBInsert(Table("voting_subject"), "text_document, text_doc_hash, voting_id", $text_document, $hash, $votingID)
            DBUpdate(Table("voting_instances"), $votingID, "flag_fulldata", 1)
        }
        else 
        {
            DBUpdate(Table("voting_subject"), $voting_subject, "text_document, text_doc_hash", $text_document, $hash)
        }
    } 
}`,
`scc_votingSubjectDocument #= ContractConditions("MainCondition")`,
`sc_votingSubjectFormal #= contract votingSubjectFormal 
{
    data 
    {
        votingID int
        
        decisionDescription string
        decisionTable string
        decisionId string
        decisionColumn string
        decisionValue string
    }

    func conditions 
    {
        CitizenCondition()
        
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting already started. Change settings not allowed"
        }
    }

    func action
    {
        $voting_subject = DBIntWhere(Table("voting_subject"), "id", "voting_id = ?", $votingID)
        
        if $voting_subject == 0 
        {
            DBInsert(Table("voting_subject"), "voting_id,formal_decision_description,formal_decision_table,formal_decision_tableid,formal_decision_column,formal_decision_colvalue", $votingID, $decisionDescription, $decisionTable, $decisionId, $decisionColumn, $decisionValue)
            
            DBUpdate(Table("voting_instances"), $votingID, "flag_fulldata", 1)
        }
        else 
        {
            DBUpdate(Table("voting_subject"), $voting_subject, "formal_decision_description,formal_decision_table,formal_decision_tableid,formal_decision_column,formal_decision_colvalue", $decisionDescription, $decisionTable, $decisionId, $decisionColumn, $decisionValue)
        }
    } 
}`,
`scc_votingSubjectFormal #= ContractConditions("MainCondition")`,
`sc_votingSubjectRole #= contract votingSubjectRole 
{
    data 
    {
        votingID int
        roleID int
    }

    conditions 
    {

        CitizenCondition() 
        
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting already started. Can not change the role"
        }
        
        $role_type = DBIntWhere(Table("roles_list"), "role_type",  "id=? and delete=0", $roleID)
        if ($role_type != 2)
        {
            warning "The chosen role is not elective or has been removed"
        }
    }

    action 
    {
        DBUpdate(Table("voting_instances"), $votingID, "optional_role_id", $roleID)
        
        $optional_role_vacancies    = DBIntWhere(Table("voting_instances"), "optional_role_vacancies",  "id=?", $votingID)
        $optional_number_cands      = DBIntWhere(Table("voting_instances"), "optional_number_cands",  "id=?", $votingID)
        if ( ($optional_role_vacancies > 0) && ($optional_number_cands > 0) )
        {
            DBUpdate(Table("voting_instances"), $votingID, "flag_fulldata", 1)
        }
    }
}`,
`scc_votingSubjectRole #= ContractConditions("MainCondition")`,
`sc_votingSubjectVacancies #= contract votingSubjectVacancies 
{
    data 
    {
        votingID int
        Vacancies int
    }

    conditions 
    {
        CitizenCondition()
        
        $v_ID = DBIntWhere(Table("voting_instances"), "id",  "id=? and startdate > now()", $votingID)
        if ($v_ID == 0)
        {
            warning "Voting already started. Can not change the vacancies"
        }
    }

    action 
    {
        DBUpdate(Table("voting_instances"), $votingID, "optional_role_vacancies", $Vacancies)
        
        $optional_role_id           = DBIntWhere(Table("voting_instances"), "optional_role_id",  "id=?", $votingID)
        $optional_number_cands      = DBIntWhere(Table("voting_instances"), "optional_number_cands",  "id=?", $votingID)
        if ( ($optional_role_id > 0) && ($optional_number_cands > 0) )
        {
            DBUpdate(Table("voting_instances"), $votingID, "flag_fulldata", 1)
        }
    }
}`,
`scc_votingSubjectVacancies #= ContractConditions("MainCondition")`,
`sc_votingUpdateDataForGraphs #= contract votingUpdateDataForGraphs 
{
    data 
    {
        votingID int
    }

    conditions 
    {

    }

    action 
    {

        $number_participants = DBIntWhere(Table("voting_instances"), "number_participants",  "id=?", $votingID) 
        $number_voters = DBIntWhere(Table("voting_instances"), "number_voters",  "id=?", $votingID)
        $number_voters = $number_voters + 1
        
        $percent_voters = ($number_voters * 100) / $number_participants
        if ($percent_voters > 100) {$percent_voters = 100}
        
        $volume = DBIntWhere(Table("voting_instances"), "volume",  "id=?", $votingID)
        
        $percent_success = ($percent_voters * 100) / $volume
        if ($percent_success > 100) {$percent_success = 100}

        $flag_success = 0
        if ($percent_success == 100) {$flag_success = 1}

        DBUpdate(Table("voting_instances"), $votingID, "number_voters, percent_voters, percent_success, flag_success", $number_voters,$percent_voters, $percent_success, $flag_success)
    }
}`,
`scc_votingUpdateDataForGraphs #= ContractConditions("MainCondition")`)
TextHidden( sc_AddLand, scc_AddLand, sc_AddProperty, scc_AddProperty, sc_chat_notification_close, scc_chat_notification_close, sc_chat_reply_to_message, scc_chat_reply_to_message, sc_chat_send_private_message, scc_chat_send_private_message, sc_CitizenCondition, scc_CitizenCondition, sc_EditLand, scc_EditLand, sc_EditProperty, scc_EditProperty, sc_LandBuyContract, scc_LandBuyContract, sc_LandSaleContract, scc_LandSaleContract, sc_MainCondition, scc_MainCondition, sc_MemberEdit, scc_MemberEdit, sc_members_Change_Status, scc_members_Change_Status, sc_members_Delete, scc_members_Delete, sc_members_Request_Accept, scc_members_Request_Accept, sc_members_Request_Reject, scc_members_Request_Reject, sc_members_Return, scc_members_Return, sc_notification_role_close, scc_notification_role_close, sc_notification_role_processing, scc_notification_role_processing, sc_notification_roles_send, scc_notification_roles_send, sc_notification_send, scc_notification_send, sc_notification_single_close, scc_notification_single_close, sc_notification_single_send, scc_notification_single_send, sc_PropertyAcceptOffers, scc_PropertyAcceptOffers, sc_PropertyRegistryChange, scc_PropertyRegistryChange, sc_PropertySendOffer, scc_PropertySendOffer, sc_roles_Add, scc_roles_Add, sc_roles_Assign, scc_roles_Assign, sc_roles_Del, scc_roles_Del, sc_roles_Search, scc_roles_Search, sc_roles_UnAssign, scc_roles_UnAssign, sc_tokens_Account_Add, scc_tokens_Account_Add, sc_tokens_Account_Close, scc_tokens_Account_Close, sc_tokens_CheckingClose, scc_tokens_CheckingClose, sc_tokens_Close, scc_tokens_Close, sc_tokens_Emission, scc_tokens_Emission, sc_tokens_EmissionAdd, scc_tokens_EmissionAdd, sc_tokens_Money_Rollback, scc_tokens_Money_Rollback, sc_tokens_Money_Transfer, scc_tokens_Money_Transfer, sc_tokens_Money_Transfer_extra, scc_tokens_Money_Transfer_extra, sc_tokens_SearchCitizen, scc_tokens_SearchCitizen, sc_TXCitizenRequest, scc_TXCitizenRequest, sc_TXEditProfile, scc_TXEditProfile, sc_votingAcceptCandidates, scc_votingAcceptCandidates, sc_votingAcceptDecision, scc_votingAcceptDecision, sc_votingAcceptDocument, scc_votingAcceptDocument, sc_votingCheckDecision, scc_votingCheckDecision, sc_votingCreateNew, scc_votingCreateNew, sc_votingDecideCandidates, scc_votingDecideCandidates, sc_votingDecideDecision, scc_votingDecideDecision, sc_votingDecideDocument, scc_votingDecideDocument, sc_votingDelete, scc_votingDelete, sc_votingIncAcceptCandidate, scc_votingIncAcceptCandidate, sc_votingIncAcceptOther, scc_votingIncAcceptOther, sc_votingInvite, scc_votingInvite, sc_votingRejectDecision, scc_votingRejectDecision, sc_votingRejectDocument, scc_votingRejectDocument, sc_votingSearch, scc_votingSearch, sc_votingSendNotifics, scc_votingSendNotifics, sc_votingSubjectApply, scc_votingSubjectApply, sc_votingSubjectCandidates, scc_votingSubjectCandidates, sc_votingSubjectDocument, scc_votingSubjectDocument, sc_votingSubjectFormal, scc_votingSubjectFormal, sc_votingSubjectRole, scc_votingSubjectRole, sc_votingSubjectVacancies, scc_votingSubjectVacancies, sc_votingUpdateDataForGraphs, scc_votingUpdateDataForGraphs)
SetVar(`sign_tokens_Money_Transfer #= {"title": "Are you agree to send money?", "params": [{"name": "Amount", "text": "Amount"}]}`,
`signc_tokens_Money_Transfer #= ContractConditions("MainCondition")`)
TextHidden( sign_tokens_Money_Transfer, signc_tokens_Money_Transfer)
SetVar(`sign_tokens_Money_Transfer #= {"title": "Are you agree to send money?", "params": [{"name": "Amount", "text": "Amount"}]}`,
`signc_tokens_Money_Transfer #= ContractConditions("MainCondition")`)
TextHidden( sign_tokens_Money_Transfer, signc_tokens_Money_Transfer)
SetVar(`sign_tokens_Money_Transfer #= {"title": "Are you agree to send money?", "params": [{"name": "Amount", "text": "Amount"}]}`,
`signc_tokens_Money_Transfer #= ContractConditions("MainCondition")`)
TextHidden( sign_tokens_Money_Transfer, signc_tokens_Money_Transfer)
SetVar(`sign_tokens_Money_Transfer #= {"title": "Are you agree to send money?", "params": [{"name": "Amount", "text": "Amount"}]}`,
`signc_tokens_Money_Transfer #= ContractConditions("MainCondition")`)
TextHidden( sign_tokens_Money_Transfer, signc_tokens_Money_Transfer)
SetVar(`p_AddLand #= Title: Add Land
Navigation(LiTemplate(LandRegistry, $land_registry$), $add_land$)
SetVar(``coord = {"center_point":["41.840465","-37.234806"], "zoom":"3"}``)

Divs(md-6, panel panel-default data-sweet-alert)
    Div(panel-heading, Div(panel-title,))
    Divs(panel-body)
        Form()
            Divs(form-group)
               InputMapPoly(coords,#coord#,coords_address,area)
            DivsEnd:
            Divs(form-group)
               Label($area$)
               Input(area,form-control input-sm,"",text)
            DivsEnd:
            Divs(form-group)
               Label($address$)
               Input(coords_address,form-control input-sm,"",text)
            DivsEnd:
            Divs(form-group)
                Label($land_use$)
                Select(land_use,land_use,form-control input-lg)
            DivsEnd:
            Divs(form-group)
                Label($buildings_use_class$)
                Select(buildings_use_class,buildings_use_class,form-control input-lg)
            DivsEnd:

            Divs(form-group)
                Label("$Owner$")
                InputAddress(owner_id, "form-control input-lg m-b")
            DivsEnd:
        FormEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs: clearfix
            Divs: pull-right
                TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract: AddLand,Name: Add, OnSuccess: "template,LandRegistry"}
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_AddLand #= ContractConditions("MainCondition")`,
`p_AddProperty #= Title: LangJS(add_property)
UList(breadcrumb, ol)
    LiTemplate(Property, LangJS(property))
    Li(LangJS(add))
UListEnd:
SetVar(``coord = {"center_point":["41.840465","-37.234806"], "zoom":"3"}``)

Divs(md-6, panel panel-default data-sweet-alert)
    Div(panel-heading, Div(panel-title,))
    Divs(panel-body)
        Form()
            Divs(form-group)
               InputMapPoly(coords,#coord#,coords_address,area)
            DivsEnd:
            Divs(form-group)
               Label(LangJS(area))
               Input(area,form-control input-sm,"",text)
            DivsEnd:
            Divs(form-group)
               Label(LangJS(address))
               Input(coords_address,form-control input-sm,"",text)
            DivsEnd:

            Divs(form-group)
                Label(LangJS(property_types))
                Select(property_types,buildings_use_class,form-control input-lg)
            DivsEnd:

            Divs(form-group)
                Label(LangJS(owner))
                InputAddress(owner_id, "form-control input-lg m-b")
            DivsEnd:
        FormEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs: clearfix
            Divs: pull-right
                TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract: AddProperty,Name: $add$, OnSuccess: "template,Property"}
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_AddProperty #= ContractConditions("MainCondition")`,
`p_Chat_history #= Title: LangJS(chat_history)

Navigation(LiTemplate(MyChats, LangJS(my_chats)), LangJS(chat_history))

If(#vPageValue#==-1)
    SetVar(showAllUnreplied=1)
    SetVar(messageId=-1)
Else:
    SetVar(showAllUnreplied=0)
    SetVar(messageId=#vPageValue#)
    SetVar(citizenId=GetOne(sender, #state_id#_chat_private_messages, "id", #messageId#))
    SetVar(as_role=GetOne(receiver_role_id, #state_id#_chat_private_messages, "id", #messageId#))

    SetVar(to_role=GetOne(sender_role_id, #state_id#_chat_private_messages, "id", #messageId#))
IfEnd:

GetRow("user", #state_id#_citizens, "id", #citizenId#)

SetVar(noNewMessages=1)
SetVar(toRoleName=GetOne(role_name, #state_id#_roles_list, "id", #to_role#))
SetVar(asRoleName=GetOne(role_name, #state_id#_roles_list, "id", #as_role#))
If(#as_role#>0)
    SetVar(roleName=#asRoleName#)
ElseIf(#to_role#>0)
    SetVar(roleName=#toRoleName#)
Else:
    SetVar(roleName="")
IfEnd:

Divs(md-12, panel panel-default elastic data-sweet-alert)
    Div(panel-heading, Div(panel-title, LangJS(unanswered_messages_1) If(#to_role#!=0, LinkPage(roles_view, #toRoleName#, "RoleName:'#toRoleName#',isSearch:1", profile-flag text-blue), #user_name#) LangJS(unanswered_messages_2)))
    Divs: panel-body
            GetList(messages, #state_id#_chat_private_messages, "id,sender,receiver,sender_avatar,sender_name,message,sender_role_id,receiver_role_id","(#as_role#=0 and #to_role#=0 and sender_role_id=0 and receiver_role_id=0 and ((#citizen# = sender and #citizenId# = receiver) or (#citizen# = receiver and #citizenId# = sender))) or (#as_role# > 0 and ((#as_role# = sender_role_id and #citizenId# = receiver) or (#as_role# = receiver_role_id and #citizenId# = sender))) or (#to_role# > 0 and ((#to_role# = sender_role_id and #citizen# = receiver) or (#to_role# = receiver_role_id and #citizen# = sender)))", "id")
            ForList(messages)
                If (Or(#id#==#messageId#, And(#showAllUnreplied#,GetOne(1-closed,#state_id#_notification, page_name='Chat_history' and page_value=#id# and recipient_id=#citizen#))))
                    SetVar(noNewMessages=0)
                    Divs: list-group-item list-group-item-hover
                        Divs: media-box
                        
Divs(md-12, panel panel-info elastic center data-sweet-alert)
    Divs: panel-body
        Form()
            Divs(form-group)
                Label(#message#)
                Divs: input-group
                    Input(UpperReplyText#index#, "form-control")
                    Divs(input-group-btn)
                        SetVar(buttonTitle=Answer If(#as_role# > 0, as role, If(#to_role# > 0, to role, privately)))
                        
                        TxButton{ Contract: chat_reply_to_message, Name: #buttonTitle#, Inputs: "to#=citizenId,in_reply_to#=id,text=UpperReplyText#index#,as_role#=as_role,to_role#=to_role", OnSuccess: "template,Chat_history,vPageValue:-1,citizenId:'#citizenId#',as_role:'#as_role#',to_role:'#to_role#'" }
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        FormEnd:
    DivsEnd:
    Divs(panel-footer)
        TxButton{ Contract: chat_notification_close, Name: Close without an answer, Inputs: "message_id#=id", OnSuccess: "template,Chat_history,vPageValue:-1,citizenId:'#citizenId#',as_role:'#as_role#',to_role:'#to_role#'" }
    DivsEnd:
DivsEnd:
                            
                        DivsEnd:
                    DivsEnd:
                IfEnd:
            ForListEnd:
    DivsEnd:
    If (#noNewMessages#)
        Div(list-group-item, Small('', LangJS(no_unanswered_messages)))
    IfEnd:
DivsEnd:

Divs(md-12, panel panel-default elastic data-sweet-alert)
    Div(panel-heading, Div(panel-title, LangJS(chat_history)))
    Divs: panel-body
        ForList(messages)
            Divs: list-group-item list-group-item-hover
                Divs: media-box
                    Divs: pull-left
                        Image(If(#sender_avatar#!=="",#sender_avatar#,"/static/img/avatar.svg"), Avatar, img-circle thumb32)
                    DivsEnd:
                    Divs: media-box-body clearfix
                        LinkPage(CitizenInfo,#sender_name#,"citizenId:'#sender#',gstate_id:#state_id#",pointer)
                        P(small, #message#)
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        ForListEnd:
    DivsEnd:
    
    Divs(panel-footer)
        Divs(input-group)
            Input(chat_message,form-control,$write_a_message$,text)
            Divs(input-group-btn)
                    TxButton{ClassBtn: fa fa-paper-plane btn btn-default btn-sm bl0 radius-tl-clear radius-bl-clear,Contract: chat_send_private_message, Name: LangJS(send), Inputs: "to#=citizenId, text=chat_message, as_role#=as_role, to_role#=to_role", OnSuccess: "template,Chat_history,vPageValue:-1,citizenId:'#citizenId#',as_role:'#as_role#',to_role:'#to_role#'"}
                IfEnd:
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:

AutoUpdate(2)
Include(notification)
AutoUpdateEnd:
PageEnd:`,
`pc_Chat_history #= ContractConditions("MainCondition")`,
`p_chat_IncomingRoleMessages #= Title: $role_messages$

Navigation(LiTemplate(MyChats, LangJS(my_chats)), $role_messages$)

AutoUpdate(2)
Include(notification)
AutoUpdateEnd:

GetRow("assign", #state_id#_roles_assign, "member_id = #citizen# and role_id = #roleId#")

Divs(md-12, panel panel-default elastic data-sweet-alert)
    If(#assign_id# <= 0)
      Div(panel-heading, Div(panel-title, "Sorry, you are not assigned to this role!"))
    Else:
      Div(panel-heading, Div(panel-title, "Assignment: #assign_role_name#: #assign_member_name#"))
    Divs: panel-body
        GetList(messages, #state_id#_chat_role_chats, "id,citizen_id,role_id,sender_avatar,sender_name,last_message,last_message_frome_role","role_id = #roleId#", "id")
        ForList(messages)
            Divs: list-group-item list-group-item-hover
                Divs: media-box
                    Divs: pull-left
                        Image(If(#sender_avatar#!=="",#sender_avatar#,"/static/img/avatar.svg"), Avatar, img-circle thumb32)
                    DivsEnd:
                    Divs: media-box-body clearfix
                        If(#last_message_frome_role#>0)
                            LinkPage(Chat_history,#sender_name# as #assign_role_name#,"vPageValue:-1,citizenId:'#citizen_id#',as_role:'#roleId#',to_role:'0'",pointer)
                            P(small, #last_message#)
                        Else:
                            LinkPage(Chat_history,#sender_name#,"vPageValue:-1,citizenId:'#citizen_id#',as_role:'#roleId#',to_role:'0'",pointer)
                            P(small, #last_message#)                        
                        IfEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        ForListEnd:
    DivsEnd:
DivsEnd:

IfEnd:`,
`pc_chat_IncomingRoleMessages #= ContractConditions("MainCondition")`,
`p_CitizenInfo #= Title: LangJS(user_info)
UList(breadcrumb, ol)
    Li(LangJS(user_info))
UListEnd:

If(GetVar(citizenId))
Else:
    SetVar(
        citizenId = GetVar(citizen),
        gstate_id = "#state_id#"
    )
IfEnd:
GetRow("user", #gstate_id#_citizens, "id", #citizenId#)

Divs(md-6, panel panel-default elastic data-sweet-alert)
    Div(panel-heading, Div(panel-title, Div(text-bold, LangJS(user_info)) ))
    Divs: panel-body text-center
        Divs:
            Image(If(GetVar(user_avatar)!=="", #user_avatar#, "/static/img/avatar.svg"), Image, img-thumbnail img-circle w-100 h-100)
        DivsEnd:
        Divs: panel-body text-center
            Tag(h3, If(GetVar(user_name)!=="", #user_name#, $Anonym$), m0)
        DivsEnd:
        Divs: list-comma align-center
            GetList(pos, #state_id#_roles_assign, "role_name,role_title", "member_id = #citizenId#" and delete = 0)
            ForList(pos)
                P(text-muted, <b>#role_title#</b> #role_name#)
            ForListEnd:
        DivsEnd:
        Divs: row
            Divs: col-md-12 mt-sm
                Tag(h4, Address(#user_id#) Em(clipboard fa fa-clipboard id="clipboard" aria-hidden="true" data-clipboard-action="copy" data-clipboard-text=Address(#user_id#) onClick="CopyToClipboard('#clipboard')", ), m0)
                P(text-muted m0, LangJS(citizen_id))
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:

Divs(md-6, panel panel-default elastic data-sweet-alert)
    Div(panel-heading, Div(panel-title, Div(text-bold,  LangJS(money_transfer))) )
    Divs(panel-body)
        Form()
            Divs(form-group)
                Label(LangJS(my_tokens))
                Input(MyTokens, "form-control  m-b disabled=''",text,text,Money(GetOne(amount, #state_id#_accounts#, "citizen_id='#citizen#' and onhold=0 and type=3")))
            DivsEnd:
            Divs(form-group)
                Label(LangJS(recipient_account_id))
                Select(RecipientAccountID, #state_id#_accounts.id, "form-control m-b",#vRecipientAccID#)
            DivsEnd:
            Divs(form-group)
                Label(LangJS(amount))
                Input(Amount, "form-control  m-b ",text,text,12.50)
            DivsEnd:
        FormEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs:clearfix 
            Divs: pull-left
            DivsEnd:
            Divs: pull-right
                TxButton{ClassBtn:btn btn-primary, Contract:tokens_Money_Transfer_extra,Name:"Send", Inputs:"SenderAccountType#=person_acc,RecipientAccountID=RecipientAccountID,Amount=Amount",OnSuccess: "template,tokens_accounts_list"}
            DivsEnd:
        DivsEnd:
    DivsEnd:  
DivsEnd:

Divs(md-12, panel panel-default elastic data-sweet-alert)
    Div(panel-heading, Div(panel-title, Div(text-bold,  LangJS(pending_notifications))) )
    Divs(panel-body)
        Divs(table-responsive)
        Table{
            Table: #state_id#_notification
            Class: table-striped table-bordered table-hover data-role="table"
            Order: "id DESC"
            Where: "type = 'single' AND recipient_id = #citizenId# AND closed = 0"
            Columns:  [
                [ ID,  SetVar(style=If(#closed#==0,"text-normal","text-muted")) Div(text-center #style#, #id#), text-center h4 align="center" width="50" ],
                [ Icon, Div(text-center, Em(fa StateVal(notification_icon,#icon#) fa-1x) ), text-center h4 align="center" width="50" ],
                [ Header, Div(#style# , #header# ), h4 ],
                [ Direction page, LinkPage(#page_name#, View the document, "vHeader:'#header#',vPageValue:#page_value#,vNotificID:#id#,vType:'#type#'", pointer), h4 ]
            ]
        }
        DivsEnd:
    DivsEnd:
DivsEnd:

If(#citizenId#!=#citizen#)

Divs(md-12, panel panel-primary elastic data-sweet-alert)
    Divs(panel-footer)
        Divs(input-group)
            Input(chat_message,form-control,$write_a_message$,text)
            Divs(input-group-btn)
                SetVar(as_role=0)
                SetVar(to_role=0)
				TxButton{ClassBtn: fa fa-paper-plane btn btn-default btn-sm bl0 radius-tl-clear radius-bl-clear,Contract: chat_send_private_message, Name: Send, Inputs: "to#=citizenId, text=chat_message, as_role#=as_role, to_role#=to_role", OnSuccess: "template,Chat_history,vPageValue:-1,citizenId:'#citizenId#',as_role:'#as_role#',to_role:'#to_role#'"}
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:

IfEnd:
    
AutoUpdate(2)
    Include(notification)
AutoUpdateEnd:
PageEnd:

PageEnd:`,
`pc_CitizenInfo #= ContractConditions("MainCondition")`,
`p_citizen_profile #= Title:$profile$
Navigation(LiTemplate(dashboard_default, $dashboard$),$editing_profile$)

GetRow("user", #state_id#_citizens, "id", #citizen#)

Divs(md-12, panel panel-default elastic data-sweet-alert)
    Divs(panel-body)
        Form()
            Divs(form-group)
                Label($name_last$)
                Input(name_last, "form-control input-lg m-b",text,"", #user_name_last#)
                Label($name_first$)
                Input(name_first, "form-control input-lg m-b",text,"", #user_name#)
                
            DivsEnd:
            Divs(form-group)
                Label("$Gender$")
                Select(gender,gender_list,form-control input-lg,#user_gender#)
            DivsEnd:
            Divs(form-group)
                Label("$photo$", d-block)
                Image(If(GetVar(user_avatar)!=="",#user_avatar#,"/static/img/avatar.svg"),,w-100 h-100 id=imgphoto)
            DivsEnd:
        FormEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs: clearfix
            Divs: pull-left
                ImageInput(photo,100,100)
            DivsEnd:
            Divs: pull-right
                TxButton{ClassBtn:btn btn-primary, Contract:TXEditProfile,Name:$Save$, OnSuccess: MenuReload()}
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_citizen_profile #= ContractConditions("MainCondition")`,
`p_dashboard_default #= FullScreen(1)
If(StateVal(tokens_accounts_type,1))
Else:
Title : Basic Apps
Divs: col-md-4
  Divs: panel panel-default elastic
   Divs: panel-body text-center fill-area flexbox-item-grow
    Divs: flexbox-item-grow flex-center
     Divs: pv-lg
     Image("/static/img/apps/money.png", Basic, center-block img-responsive img-circle img-thumbnail thumb96 )
     DivsEnd:
     P(h4,Basic Apps)
     P(text-left,"Election and Assign, Polling, Messenger, Simple Money System")
    DivsEnd:
   DivsEnd:
   Divs: panel-footer
    Divs: clearfix
     Divs: pull-right
      BtnPage(app-basic, Install,'',btn btn-primary lang)
     DivsEnd:
    DivsEnd:
   DivsEnd:
  DivsEnd:
 DivsEnd:
IfEnd:
FullScreen(1)

Navigation(LiTemplate(dashboard_default, LangJS(Citizen)))

Divs(md-12, panel widget elastic center)
    Divs: panel-body text-center
        Divs: row df f-valign
			Divs: col-md-2 mt-sm
            DivsEnd:
			Divs: col-md-4 mt-sm
                Image(StateVal(state_flag), State flag, img-responsive d-inline-block align-middle w-380 h-112)
            DivsEnd:
            Divs: col-md-4 mt-lg mb
                Tag(h1, StateVal(state_name), m0)
            DivsEnd:
			Divs: col-md-2 mt-sm
            DivsEnd:
        DivsEnd:
    DivsEnd:
    Divs: panel-body text-center bg-gray-dark f0
        Divs: row row-table
            Divs: col-xs-4
                
                P(m0 text-muted, Founded)
            DivsEnd:
            Divs: col-xs-4
                Tag(h3,  GetOne(name_tokens, #state_id#_accounts_tokens#, "delete=0"), m0)
                P(m0 text-muted, $tokens$)
            DivsEnd:
            Divs: col-xs-4
                Tag(h3, GetOne(count(*),#state_id#_citizens), m0)
                P(m0 text-muted, $members$)
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:

Divs(md-12)
    Divs: row
        Divs: md-4
            LinkPage(voting_list,
                Divs: panel widget bg-gray
                    Divs: row row-table
                        Divs: col-xs-3 text-center bg-gray-dark pv-lg ico
                            Em(icon-pin fa-3x)
                        DivsEnd:
                        Divs: col-xs-9 pv-lg text
                            Div(h4 m0 text-bold text-uppercase, $voting$)
                            Div("", Voting system )
                            Div("", and decisions taken)
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            ,"",pointer)
        DivsEnd:
        Divs: md-4
            LinkPage(members_list,
                Divs: panel widget bg-gray
                    Divs: row row-table
                        Divs: col-xs-3 text-center bg-gray-dark pv-lg ico
                            Div(icon-user fa-3x)
                        DivsEnd:
                        Divs: col-xs-9 pv-lg text
                            Div(h4 m0 text-bold text-uppercase, LangJS(members))
                            Div("", Managing Members)
                            Div("", and membership requests)
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            ,"vObjectInt:1",pointer)
        DivsEnd:
        Divs:md-4
            LinkPage(roles_list,
                Divs: panel widget bg-gray
                    Divs: row row-table
                        Divs: col-xs-3 text-center bg-gray-dark pv-lg ico
                            Div(icon-list fa-3x)
                        DivsEnd:
                        Divs: col-xs-9 pv-lg text
                            Div(h4 m0 text-bold text-uppercase, $roles$)
                            Div("", Lists of roles)
                            Div("", and their members)
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            ,"vObjectInt:1",pointer)
        DivsEnd:
    DivsEnd:
DivsEnd:

Divs(md-6, panel panel-default elastic data-sweet-alert)
    Div(panel-heading, Div(panel-title, Div(text-bold, $voting$) ))
    Divs: panel-body text-center
        Divs(table-responsive)
            Table {
            	Table: #state_id#_voting_instances
            	Class: table-striped table-hover
            	Order: id
            	Columns: [
            	    [ID, Div(text-center, #id#), text-center h4 align="center" width="50" ],
            		[$name$, Div(text-bold, LinkPage(voting_view, #name#, "vID:#id#",pointer) ), text-center h4 align="center"],
            		[$voting_end$, Div(text-center, DateTime(#enddate#, YYY.MM.DD HH:MI)), text-center h4 align="center"]
            	]
            }
        DivsEnd:
    DivsEnd:
DivsEnd:

Divs(md-6, panel panel-default elastic data-sweet-alert)
    Div(panel-heading, Div(panel-title, Div(text-bold, $roles$) ))
    Divs: panel-body text-center
        Divs(table-responsive)
        Table{
            Table: #state_id#_roles_assign
            Class: table-striped table-hover
            Order: "delete ASC, id ASC"
            Columns:  
            [
                [ ID,  SetVar(style=If(#delete#==0,"text-normal","text-muted")) Div(text-center #style#, #id#), text-center h4 align="center" width="50" ],
                [ $role_name$, Div(text-bold #style#, #role_name# ), text-center h4 align="center"],
                [ $members$, SetVar(citizens_avatar=GetOne(avatar, #state_id#_citizens#, "id",  #member_id#))  Div(text-bold #style#, Image(If(GetVar(citizens_avatar)!=="", #citizens_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30),   #member_name#), text-center h4 align="center"]
            ]
        }
    DivsEnd:
DivsEnd:

PageEnd:

PageEnd:`,
`pc_dashboard_default #= ContractConditions("MainCondition")`,
`p_EditLand #= Title:Edit Land
Navigation(LiTemplate(LandRegistry, $land_registry$),Edit Land)

ValueById(#state_id#_land_registry, #LandId#, "address,area,buildings_use_class,coords,land_use","Address,area,buildings_use_class,Coords,land_use")


Divs(md-6, panel panel-default data-sweet-alert)
    Div(panel-heading, Div(panel-title,))
    Divs(panel-body)
        Form()
            Divs(form-group)
               InputMapPoly(Coords,#Coords#,coords_address,area)
            DivsEnd:
            Divs(form-group)
                Label($area$)
               Input(area,form-control input-sm,"",text,#area#)
            DivsEnd:
            Divs(form-group)
                Label($address$)
               Input(coords_address,form-control input-sm,"",text,#Address#)
            DivsEnd:
            Divs(form-group)
                Label($land_use$)
                Select(land_use,land_use,form-control input-lg,#land_use#)
            DivsEnd:
            Divs(form-group)
                Label($buildings_use_class$)
                Select(buildings_use_class,buildings_use_class,form-control input-lg,#buildings_use_class#)
            DivsEnd:
            

        FormEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs: clearfix
            Divs: pull-right
                
                Input(LandId, "hidden", text, text, #LandId#)
                TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract: EditLand,Name: $Save$, OnSuccess: "template,LandRegistry"}
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:


PageEnd:`,
`pc_EditLand #= ContractConditions("MainCondition")`,
`p_EditProperty #= Title:LangJS(edit_property)
UList(breadcrumb, ol)
    LiTemplate(Property, LangJS(property))
    Li(LangJS(edit))
UListEnd:
PageTitle: LangJS(editing_property)

ValueById(#state_id#_property, #PropertyId#, "name,citizen_id,coords,type,police_inspection", "Name,CitizenId,Coords,PropertyType,police_inspection")
SetVar( CitizenId= Address(#CitizenId#))
TxForm{ Contract: EditProperty}

PageEnd:`,
`pc_EditProperty #= ContractConditions("MainCondition")`,
`p_government #= 
If(StateVal(tokens_accounts_type,1))
Title : Basic Apps
Divs: col-md-12
  Divs: panel panel-default elastic
   Divs: panel-body text-center fill-area flexbox-item-grow
    Divs: flexbox-item-grow flex-center
     Divs: pv-lg
     Image("/static/img/apps/money.png", Basic, center-block img-responsive img-circle img-thumbnail thumb96 )
     DivsEnd:
     P(h4,Application was successfully installed)
    DivsEnd:
   DivsEnd:
   Divs: panel-footer
    Divs: clearfix
     Divs: pull-right
        BtnPage(dashboard_default, Get Started,'',btn btn-primary lang)
     DivsEnd:
    DivsEnd:
   DivsEnd:
  DivsEnd:
 DivsEnd:
IfEnd:
PageEnd:
`,
`pc_government #= ContractConditions("MainCondition")`,
`p_LandHistory #= FullScreen(1)
Title : History of Land Registry 
Navigation(LiTemplate(LandRegistry, Land Registry), History)

    Divs(md-12, panel panel-default panel-body)
                MarkDown : ## History of Land Registry
                Table {
                   Class: table-striped table-hover
             Table: #state_id#_editing_land_registry
             Order: id
             Columns: [[Object ID, #lend_object_id#], [Attribute, $#editing_attribute#$], [New value, If(Or(#editing_attribute#=="land_use",#editing_attribute#=="buildings_use_class"),StateVal(#editing_attribute#,#new_attr_value#),#new_attr_value#)], [Old value,  If(Or(#editing_attribute#=="land_use",#editing_attribute#=="buildings_use_class"),StateVal(#editing_attribute#,#old_attr_value#),#old_attr_value#)], [Name, #person_name#],[Date, DateTime(#date#, YYYY.MM.DD HH:MI)],[Object Info,BtnPage(LandObject, View,"LandId:#lend_object_id#")]]
                }
            
    DivsEnd:

PageEnd:`,
`pc_LandHistory #= ContractConditions("MainCondition")`,
`p_LandObject #= FullScreen(1)
Title :  Land Object
Navigation(LiTemplate(LandRegistry, Land Registry), Land Object)

If(GetVar(LandId))

GetList(owner,#state_id#_land_ownership,"lend_object_id,owner_new_id",lend_object_id=#LandId# and owner_id!=0,id DESC,1)

SetVar(owner_id = ListVal(owner,#LandId#,owner_new_id))

ValueById(#state_id#_citizens, #owner_id#,"id,name,avatar","owner_id,owner_name,owner_avatar")

ValueById(#state_id#_land_registry, #LandId#, "address,area,buildings_use_class,coords,land_use,value")
Divs(md-6, panel panel-default panel-body data-sweet-alert)
Legend(" ", "Map")
 Map(#coords#,maptype=satellite hmap=300)
DivsEnd:
Divs(md-6, panel panel-default panel-body data-sweet-alert)
Legend(" ", "Info")
 P(h4,$land_use$: StateVal(land_use,#land_use#))
 P(h4,$buildings_use_class$: StateVal(buildings_use_class,#buildings_use_class#))
 P(h4,$address$: #address#)
 P(h4,$area$: #area# Sq m)

DivsEnd:
Divs(md-6, panel panel-default panel-body data-sweet-alert)
Legend(" ", "Owner")
P(pclass,#owner_name#)
            Image(If(GetVar(owner_avatar),#owner_avatar#,"/static/img/avatar.svg"), Avatar, media-box-object img-circle img-thumbnail thumb96 center-block)
If(#owner_id#!=#citizen#)
BtnPage(LandObjectContract, $buy$,"LandId:#LandId#,buyer_id:'#citizen#'")
IfEnd:
DivsEnd:


Divs(md-12, panel panel-default panel-body data-sweet-alert)
Legend(" ", "History")
         Table {
             Class: table-striped table-hover
             Table: #state_id#_editing_land_registry
             Order: id
             Where: lend_object_id  = #LandId# 
             Columns: [[Attribute, $#editing_attribute#$], [New value, If(Or(#editing_attribute#=="land_use",#editing_attribute#=="buildings_use_class"),StateVal(#editing_attribute#,#new_attr_value#),#new_attr_value#)], [Old value,  If(Or(#editing_attribute#=="land_use",#editing_attribute#=="buildings_use_class"),StateVal(#editing_attribute#,#old_attr_value#),#old_attr_value#)], [Name, #person_name#],[Date, DateTime(#date#, YYYY.MM.DD HH:MI)]]
         }
DivsEnd:
Else:
    Tag(h2,Incorrect link to page.) 
IfEnd:
PageEnd:`,
`pc_LandObject #= ContractConditions("MainCondition")`,
`p_LandObjectContract #= FullScreen(1)
Title :  Land Object Contract
Navigation( LiTemplate(government,Government) LiTemplate(LandRegistry, Land Registry), Contract)

Include(notification)

If(GetVar(application_id))
SetVar(LandId=#application_id#)
IfEnd:

GetList(owner,#state_id#_land_ownership,"lend_object_id,owner_new_id",lend_object_id=#LandId# and owner_id!=0,id DESC,1)

SetVar(owner_id = ListVal(owner,#LandId#,owner_new_id))

SetVar(contract_id = GetOne(id,#state_id#_land_ownership,lend_object_id=#LandId# and owner_id=0))

If(GetVar(contract_id))
    SetVar(buyer_id = GetOne(owner_new_id,#state_id#_land_ownership,lend_object_id=#LandId# and owner_id=0))
Else:
    SetVar(contract_id = 0)
	SetVar(buyer_id = 0)
IfEnd:

If(!GetVar(owner_id))
    SetVar(owner_id = 0)
IfEnd:

ValueById(#state_id#_citizens, #owner_id#,"id,name,avatar","owner_id,owner_name,owner_avatar")
ValueById(#state_id#_citizens, #buyer_id#,"id,name,avatar","buyer_id,buyer_name,buyer_avatar")


Divs(md-6)
    Divs(panel panel-info data-sweet-alert)
        Div(panel-heading, Div(panel-title,Land owner))
        Divs(panel-body text-center)
            P(pclass,#owner_name#)
            Image(If(GetVar(owner_avatar),#owner_avatar#,"/static/img/avatar.svg"), Avatar, media-box-object img-circle img-thumbnail thumb96 center-block)
                If(#contract_id# > 0) 
                  Form(mt-lg)
                    Input(LandId, "hidden", text, text, #LandId#)
                    Input(owner_id, "hidden", text, text, #owner_id#)
                    Input(contract_id, "hidden", text, text, #contract_id#)
                    Input(notification_id, "hidden", text, text, #notification_id#)
                    
                   
                            Divs(d-inline-block)
                            TxButton{ClassBtn:btn, Contract: LandSaleContract, Name:Owner sign, OnSuccess: "template,LandObject,LandId:#LandId#"}
                            DivsEnd:
                    
                FormEnd: 
                Else:
                    Tag(h4,Waiting for the buyer signature) 
                IfEnd:

        DivsEnd:
        DivsEnd:
        DivsEnd:
    DivsEnd:



Divs(md-6)
    Divs(panel panel-info data-sweet-alert)
        Div(panel-heading, Div(panel-title,Land buyer))
        Divs(panel-body text-center)
            P(pclass,#buyer_name#)
            Image(If(GetVar(buyer_avatar),#buyer_avatar#,"/static/img/avatar.svg"), Avatar, media-box-object img-circle img-thumbnail thumb96 center-block)
                If(#contract_id#==0)
                Form(mt-lg)   
                    
                    Input(buyer_id, "hidden", text, text, #buyer_id#)
                    Input(LandId, "hidden", text, text, #LandId#)
                    Input(owner_id, "hidden", text, text, #owner_id#)

                   
                            Divs(d-inline-block)
                                TxButton{ClassBtn:btn, Contract: LandBuyContract, Name:Buyer sign, OnSuccess: "template,LandObjectContract,LandId:#LandId#,buyer_id:'#buyer_id#'"}
                            DivsEnd:
                FormEnd:
                Else:
                     Tag(h4,The contract is signed by the buyer.)
                IfEnd:

        DivsEnd:
        DivsEnd:
        DivsEnd:
    DivsEnd:

If(GetVar(LandId))

ValueById(#state_id#_land_registry, #LandId#, "address,area,buildings_use_class,coords,land_use,value")
Divs(md-6, panel panel-default panel-body data-sweet-alert)
Legend(" ", "Map")
 Map(#coords#,maptype=satellite hmap=300)
DivsEnd:
Divs(md-6, panel panel-default panel-body data-sweet-alert)
Legend(" ", "Info")
 P(h4,$land_use$: StateVal(land_use,#land_use#))
 P(h4,$buildings_use_class$: StateVal(buildings_use_class,#buildings_use_class#))
 P(h4,$address$: #address#)
 P(h4,$area$: #area# Sq m)
DivsEnd:


Else:
    Tag(h2,Incorrect link to page.) 
IfEnd:

PageEnd:`,
`pc_LandObjectContract #= ContractConditions("MainCondition")`,
`p_LandRegistry #= FullScreen(1)

Title :  $land_registry$
Navigation($land_registry$)

Divs(md-12, panel panel-default data-sweet-alert)
    Divs(panel-body)
        Divs(table-responsive)
            Table {
                Class: table-striped table-bordered table-hover data-role="table"
                Table: #state_id#_land_registry
                Order: id
                Columns: [[ID, #id#], [$land_use$, StateVal(land_use, #land_use#)], [$buildings_use_class$, StateVal(buildings_use_class, #buildings_use_class#)], [$map$, Map(#coords#,maptype=satellite hmap=100), width="200"], [$address$, #address#],[$area$ m³, #area#], [$edit$,BtnPage(EditLand, $edit$,"LandId:#id#")],[$View$,BtnPage(LandObject, $View$,"LandId:#id#")]]
            }
        DivsEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs: clearfix
            Divs: pull-right
                BtnPage(LandHistory,$history$, '',btn btn-pill-left btn-default)
                BtnPage(AddLand, $add_land$, '',btn btn-pill-right btn-primary)
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_LandRegistry #= ContractConditions("MainCondition")`,
`p_MemberEdit #= If(#isChange#==1, Title:会员管理)

ValueById(#state_id#_citizens,#vMemberID#,"newaddress,newcoords","na,nc")

Navigation(会员修改)
Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-success data-sweet-alert)
                Div(panel-heading, Div(panel-title))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(ID)
                            Input(MemberId, "form-control  m-b disabled=''",,text, Address(#vMemberID#))
                        DivsEnd:
                        Divs(form-group)
                            Label(姓)
                            Input(MemberName, "form-control  m-b disabled=''",,text, #vMemberLastName#)
                        DivsEnd:
                        Divs(form-group)
                            Label(名)
                            Input(MemberName, "form-control  m-b disabled=''",,text, #vMemberName#)
                        DivsEnd:
                        
                        
                        Divs(form-group)
                            Label(出生日期)
                            Input(MemberBirthday, "form-control  m-b",请输入生日,text, #vMemberBirthday#)
                        DivsEnd:
                        
                        Divs(form-group)
                            Label(性别)
                            Input(MemberSex, "form-control  m-b",请输入男/女,text, #vMemberSex#)
                        DivsEnd:
                        
                        Divs(form-group)
                        Label(坐标)
                           InputMapPoly(coords,#nc#,coords_address,area)
                        DivsEnd:
                        Divs(form-group)
                           Label(地址)
                           Input(coords_address,form-control input-sm,"",text,#na#)
                        DivsEnd:
                        
                    Divs(panel-footer)
                        Divs: clearfix
                            Divs: pull-right
                                TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract: MemberEdit,Name: 确定修改, OnSuccess: "template,MemberManage"}
                            DivsEnd:
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_MemberEdit #= ContractConditions("MainCondition")`,
`p_MemberManage #= Title:会员管理
Navigation(会员管理) 
Divs(md-12, panel panel-primary)
    Div(panel-heading, Div(panel-title))
        Div(text-bold, <br>)
        Divs(table-responsive)
        Table {
            Table: #state_id#_citizens
            Class: table-striped table-bordered table-hover data-role="table"
            Order: "person_status DESC, name ASC"
            Columns:
            [
                [头像, Div(text-center text-bold, Image(If(GetVar(avatar)!=="", #avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30) ),text-center h4 align="center" width="125"],
                [姓名, Div(text-center, #name_last##name#), text-center h4 align="center" width="125" ],
         
                [出生日期, Div(text-center, #newbirthday# ), text-center h4 align="center" width="125" ],
                [性别, Div(#style# text-center,#newsex# ), text-center h4 align="center" width="125" ],
                [地图, Map(#newcoords#,maptype=satellite hmap=100),text-center h4 align="center" width="200"], 
                [修改, Div(text-center, If(#person_status#<0, text-center h4, BtnPage(MemberEdit, Em(fa fa-edit), "vMemberID:'#id#',vMemberName:'#name#',vMemberLastName:'#name_last#',vMemberSex:'#newsex#',vMemberBirthday:'#newbirthday#',vMemberAddress:'#address#'",  btn btn-primary))), text-center h4 align="center" width="125" ],
            ]
        }
        DivsEnd:
    DivsEnd:
DivsEnd:
PageEnd:`,
`pc_MemberManage #= ContractConditions("MainCondition")`,
`p_members_list #= Title:LangJS(members)
Navigation(LangJS(members)) 

If(#isSearch#==1)
    SetVar(vWhere="name = '#MemberName#'")
Else:
    SetVar(vWhere="id <> 0")
IfEnd:
        
Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, LangJS(members)))
    Divs(panel-body)
        Divs: row df f-valign
			Divs: col-md-1 mt-sm text-right
			    Div(text-bold, LangJS(name))
            DivsEnd:
			Divs: col-md-10 mt-sm text-left
                Input(StrSearch, "form-control  m-b")
            DivsEnd:
            Divs: col-md-1 mt-sm
                TxButton { Contract:roles_Search, Name: $search$, OnSuccess: "template,members_list,MemberName:Val(StrSearch),isSearch:1" }
            DivsEnd:
        DivsEnd:
        Div(text-bold, <br>)
        Divs(table-responsive)
        Table {
            Table: #state_id#_citizens
            Class: table-striped table-bordered table-hover data-role="table"
            Order: "person_status DESC, name ASC"
            Where: #vWhere#
            Columns:
            [
                [ $member$,  SetVar(style=If(#person_status#==-1,"text-muted","text-normal")) Div(#style# text-bold, Image(If(GetVar(avatar)!=="", #avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30)   If(#person_status#==-1, #name#, LinkPage(CitizenInfo, #name#, "citizenId:'#id#',gstate_id:#state_id#",profile-flag text-blue) ) ) , text-center h4 align="center"],
                [ $member_id$,  Div(#style# text-bold, Address(#id#) Em(clipboard fa fa-clipboard id="clipboard" aria-hidden="true" data-clipboard-action="copy" data-clipboard-text=Address(#id#) onClick="CopyToClipboard('#clipboard')", ) ), text-center h4 align="center" width="215"],
                [ $date_accept$, Div(#style# text-center, DateTime(#date_start#, DD.MM.YYYY HH:MI) ), text-center h4 align="center" width="125" ],
                [ $expiration$, Div(#style# text-center, DateTime(#date_expiration#, DD.MM.YYYY HH:MI) ), text-center h4 align="center" width="125" ],
                [ $date_delete$, Div(#style# text-center, DateTime(#date_end#, DD.MM.YYYY HH:MI) ), text-center h4 align="center" width="125" ],
                [ $status$, If(#person_status#>0, Div(#style# text-bold text-center, StateVal(members_request_status,#person_status#)), If(#person_status#==-1, Div(#style# text-bold text-center, "Deleted"))), text-center h4 align="center" width="70" ],
                [ , SetVar(address_m = Address(#id#)) SetVar(date_e = DateTime(#date_expiration#, DD.MM.YYYY HH:MI)) SetVar(isDateExp = If(#date_expiration#,1,0)) Div(text-center, If(#person_status#<0, "", BtnPage(members_request_edit, Em(fa fa-edit), "isChange:1,vMemberID:'#id#',vMemberName:'#name#',vMemberStatus:'#person_status#',vDateExpiration:'#date_e#',isDateExpiration:#isDateExp#",  btn btn-primary))), text-center align="center" width="60" ],
                [ , SetVar(address_m = Address(#id#)) Div(text-center, If(#person_status#>0, BtnContract(members_Delete, Em(fa fa-close),Do you want to delete this member?,"MemberId:'#address_m#'",'btn btn-danger btn-block',template,members_list), If(#person_status#==-1, BtnContract(members_Return, Em(fa fa-reorder), Do you want to return this member?,"MemberId:'#address_m#'",'btn btn-success btn-block',template,members_list)) )), text-center align="center" width="60" ]
            ]
        }
        DivsEnd:
        If(#isSearch#==1)
            Div(h4 m0 text-bold text-left, <br>)
            Divs(text-center)
                    BtnPage(members_list, LangJS(view_all),"isSearch:0",btn btn-primary btn-oval)
            DivsEnd:
        IfEnd:
    DivsEnd:
DivsEnd:

Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, "$membership_request$"))
    Divs(panel-body)
        Divs(table-responsive)
        Table {
            Class: table-striped table-bordered table-hover data-role="table"
            Table: #state_id#_citizenship_requests
            Order: "id DESC"
            Where: "approved=0"
            Columns: 
            [
                [ID, Div(text-center text-bold,#id#), text-center h4 align="center" width="50"],
                [$name$, Div(text-bold,#name#), h4],
                [, BtnPage(members_request_edit, Em(fa fa-check), "isChange:0,vMemberID:'#id#',vMemberName:'#name#',vMemberStatus:1,vDateExpiration:'',isDateExpiration:0",  btn btn-success), width="60"],
                [ , BtnContract(members_Request_Reject,Em(fa fa-close), Reject requests from #name#,"RequestId:#id#",'btn btn-danger'), width="60"]
            ]
        }
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_members_list #= ContractConditions("MainCondition")`,
`p_members_request_edit #= If(#isChange#==1, Title:LangJS(change), Title:LangJS(accept))
Navigation(LiTemplate(members_list,$members$), If(#isChange#==1, LangJS(change), LangJS(accept)))

SetVar(vDateExpiration = If(#vDateExpiration#,#vDateExpiration#,Now(YYYY.MM.DD 00:00,5 days)))

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-success data-sweet-alert)
                Div(panel-heading, Div(panel-title, LangJS(request)))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(LangJS(member_id))
                            If(#isChange#==1, Input(MemberID, "form-control  m-b disabled=''",caption,text, Address(#vMemberID#)), Input(MemberID, "form-control  m-b disabled=''",caption,text, #vMemberID#))
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(member_name))
                            Input(MemberName, "form-control  m-b disabled=''",caption,text, #vMemberName#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(status))
                            Select(MemberStatus,members_request_status,form-control,#vMemberStatus#)
                        DivsEnd:
                        If(#isDateExpiration#==1)
                        
                            If(#vMemberStatus#==1)
                                Divs(form-group)
                                    Label(LangJS(date_expiration))
                                    Divs(input-group)
                                        Input(DateExpiration, "form-control  m-b disabled=''", text, text, "Limit can not be set for a member")
                                	    Input(isDateExpiration, "form-control  m-b hidden disabled=''", text, text, 0)
                                        Divs(input-group-btn)
                                        BtnPage(members_request_edit, Em(fa fa-plus), "isDateExpiration:1,vDateExpiration:'#vDateExpiration#',isChange:#isChange#,vMemberID:'#vMemberID#',vMemberName:'#vMemberName#',vMemberStatus:Val(MemberStatus)", btn btn-default) 
                                        DivsEnd:
                                    DivsEnd:
                                DivsEnd:
                            Else:
                                Divs(form-group)
                                    Label(LangJS(date_expiration))
                                    Divs(input-group)
                                        InputDate(DateExpiration,form-control, #vDateExpiration#)
                                		    Input(isDateExpiration, "form-control  m-b hidden disabled=''", text, text, 1)
                                        Divs(input-group-btn)
                                        BtnPage(members_request_edit, Em(fa fa-minus), "isDateExpiration:0,vDateExpiration:'#vDateExpiration#',isChange:#isChange#,vMemberID:'#vMemberID#',vMemberName:'#vMemberName#',vMemberStatus:Val(MemberStatus)", btn btn-default)
                                        DivsEnd:
                                    DivsEnd:
                                DivsEnd:
                            IfEnd:
                            
                        Else:
                            Divs(form-group)
                                Label(LangJS(date_expiration))
                                Divs(input-group)
                                    Input(DateExpiration, "form-control  m-b disabled=''", text, text, $not_limited$)
                                    Input(isDateExpiration, "form-control  m-b hidden disabled=''", text, text, 0)
                                    Divs(input-group-btn)
                                    BtnPage(members_request_edit, Em(fa fa-plus), "isDateExpiration:1,vDateExpiration:'#vDateExpiration#',isChange:#isChange#,vMemberID:'#vMemberID#',vMemberName:'#vMemberName#',vMemberStatus:Val(MemberStatus)", btn btn-default)
                                    DivsEnd:
                                DivsEnd:
                            DivsEnd:
                        IfEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        If(#isChange#==1)
                            Divs: pull-right
                                BtnPage(members_list, LangJS(back), "", btn btn-default btn-pill-left ml4)
                                BtnContract(members_Change_Status,$change$, Are you sure you want to change the status for #vMemberName#,"MemberId:Val(MemberID),PersonStatus:Val(MemberStatus),DateExpiration:Val(DateExpiration),isDateExpiration:Val(isDateExpiration)",'btn btn-success btn-pill-right',template,members_list)
                            DivsEnd:
                        Else:
                            Divs: pull-right
                                BtnPage(members_list, LangJS(back), "", btn btn-default btn-pill-left ml4)
                                BtnContract(members_Request_Accept,LangJS(change), 确认接受 #vMemberName# 的申请?,"RequestId:Val(MemberID),PersonStatus:Val(MemberStatus),RequestName:Val(MemberName),DateExpiration:Val(DateExpiration),isDateExpiration:Val(isDateExpiration)",'btn btn-success btn-pill-right',template,members_list)
                            DivsEnd:
                        IfEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_members_request_edit #= ContractConditions("MainCondition")`,
`p_MyChats #= Title: LangJS(my_chats)
Navigation(LangJS(my_chats))

AutoUpdate(2)
Include(notification)
AutoUpdateEnd:

Divs(md-12, panel panel-default elastic data-sweet-alert)
    Div(panel-heading, Div(panel-title, LangJS(my_private_chats)))
        Divs(panel-body)
            Divs(table-responsive)
                Table{
                    Table: #state_id#_chat_private_chats
                    Class: table-striped table-bordered table-hover data-role="table"
                    Order: id
                    Where: (#citizen# = #higher_id#) or (#citizen# = #lower_id#)
                    Columns:  [
                        [
                            $name$,
                            If(#citizen# == #receiver_id#, Image(If(#sender_avatar#!=="",#sender_avatar#,"/static/img/avatar.svg"), Avatar, img-circle thumb32) LinkPage(CitizenInfo,#sender_name#,"citizenId:'#sender_id#',gstate_id:#state_id#",pointer), Image(If(#receiver_avatar#!=="",#receiver_avatar#,"/static/img/avatar.svg"), Avatar, img-circle thumb32) LinkPage(CitizenInfo,#receiver_name#,"citizenId:'#receiver_id#',gstate_id:#state_id#",pointer))
                        ],
                        [
                            $message$,
                            Image(If(#sender_avatar#!=="",#sender_avatar#,"/static/img/avatar.svg"), Avatar, img-circle thumb32) #last_message#
                        ]
                    ]
                }
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:

Divs(md-6, panel panel-default elastic data-sweet-alert)
    Div(panel-heading, Div(panel-title, LangJS(my_chats_with_other_roles)))
    Divs: panel-body
        GetList(messages, #state_id#_chat_role_chats, "id,citizen_id,role_id,sender_avatar,sender_name,last_message,last_message_frome_role","citizen_id = #citizen#", "id")
        ForList(messages)
            Divs: list-group-item list-group-item-hover
                Divs: media-box
                    Divs: pull-left
                        Image(If(#sender_avatar#!=="",#sender_avatar#,"/static/img/avatar.svg"), Avatar, img-circle thumb32)
                    DivsEnd:
                    Divs: media-box-body clearfix
                        If(#last_message_frome_role#==1)
                            SetVar(role_name=GetOne(role_name, #state_id#_roles_list, "id", #role_id#))
                            LinkPage(Chat_history,#sender_name# as #role_name#,"vPageValue:-1,citizenId:'0',as_role:'0',to_role:'#role_id#'",pointer)
                            P(small, #last_message#)
                        Else:
                            LinkPage(Chat_history,#sender_name#,"vPageValue:-1,citizenId:'0',as_role:'0',to_role:'#role_id#'",pointer)
                            P(small, #last_message#)                        
                        IfEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        ForListEnd:
    DivsEnd:
DivsEnd:

Divs(md-6, panel panel-default elastic data-sweet-alert)
    Divs: panel-body
        Form()
            Divs(form-group)
                Label(LangJS(role_name))
                Select(RoleID, #state_id#_roles_list.role_name, "form-control m-b", 0)
                Input(RecipientID, "form-control  m-b hidden disabled=''",integer,text,"" )
            DivsEnd:
            Divs(input-group)
                Input(chat_message,form-control,$write_a_message_for_the_role$,text)
                Divs(input-group-btn)
                    SetVar(to=0,as_role=0)
                    TxButton{ClassBtn: fa fa-paper-plane btn btn-default btn-sm bl0 radius-tl-clear radius-bl-clear,Contract:chat_send_private_message, Name: Send, Inputs: "text=chat_message,to_role=RoleID,as_role#=as_role,to#=to", OnSuccess: "template,MyChats"}
                DivsEnd:
            DivsEnd:
            P(h6, <br>)
            BtnPage(chat_IncomingRoleMessages, LangJS(show_role_messages), "roleId:Val(RoleID)", btn btn-default ml4)
        FormEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_MyChats #= ContractConditions("MainCondition")`,
`p_notification #= Divs(notification)
    SetVar(isFlag=0)
    GetList(noti_s, #state_id#_notification, "id,type,page_name,page_value,page_value2,header,text_body,icon","closed=0 and type='single' and recipient_id=#citizen#")
    GetList(noti_r, #state_id#_notification, "id,type,page_name,page_value,page_value2,header,text_body,icon,role_id","closed=0 and type='role' and started_processing_id=0")
    GetList(noti_v, #state_id#_notification, "id,type,page_name,page_value,page_value2,header,text_body,icon,role_id","closed=0 and type='role' and started_processing_id=#citizen#")
    If(noti_s)
        ForList(noti_s)
                SetVar(isFlag=1)
                LinkPage(#page_name#, 
                    Div(media-box, Div(pull-left, Em(fa StateVal(notification_icon,#icon#) fa-2x text-info)) Div(media-box-body clearfix, Div(m0 text-muted, #header#) Div(m0 text-muted, Small('', #text_body#)))), 
                    "vHeader:'#header#',vPageValue:#page_value#,vPageValue2:'#page_value2#',vNotificID:#id#,vType:'#type#'",
                    list-group-item notification-item pointer)
        ForListEnd:
    IfEnd:
    If(noti_r)
        ForList(noti_r)
            SetVar(var_id_role=GetOne(id, #state_id#_roles_assign#, "member_id=#citizen# and role_id=#role_id# and delete=0"))
            If(#var_id_role#>0)
                SetVar(isFlag=1)
                LinkPage(#page_name#, 
                    Div(media-box, Div(pull-left, Em(fa StateVal(notification_icon,#icon#) fa-2x text-info)) Div(media-box-body clearfix, Div(m0 text-muted, #header#) Div(m0 text-muted, Small('', #text_body#)))), 
                    "vHeader:'#header#',vPageValue:#page_value#,vPageValue2:'#page_value2#',vNotificID:#id#,vType:'#type#'",
                    list-group-item notification-item pointer)
            IfEnd:
        ForListEnd:
    IfEnd:
    If(noti_v)
        ForList(noti_v)
            SetVar(var_id_role=GetOne(id, #state_id#_roles_assign#, "member_id=#citizen# and role_id=#role_id# and delete=0"))
            If(#var_id_role#>0)
                SetVar(isFlag=1)
                LinkPage(#page_name#, 
                    Div(media-box, Div(pull-left, Em(fa StateVal(notification_icon,#icon#) fa-2x text-info)) Div(media-box-body clearfix, Div(m0 text-muted, #header#) Div(m0 text-muted, Small('', #text_body#)))), 
                    "vHeader:'#header#',vPageValue:#page_value#,vPageValue2:'#page_value2#',vNotificID:#id#,vType:'#type#'",
                    list-group-item notification-item pointer)
            IfEnd:
        ForListEnd:
    IfEnd:
    If(#isFlag#==0)   
        Div(list-group-item, Small('', No notifications))
    IfEnd:
DivsEnd:`,
`pc_notification #= ContractConditions("MainCondition")`,
`p_notification_send_roles #= Title:Send
Navigation(LiTemplate(notification_view_roles, LangJS(role_notifications)), LangJS(send)) 

If(#vS#!=1)
    SetVar(vS=1)
    SetVar(vNotificHeader="")
    SetVar(vTextBody="")
    SetVar(vPageName="notification_testpage")
    SetVar(vPageValue="0")
    SetVar(vPageValue2="")
    SetVar(vNotificationIcon=1)
IfEnd:

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, LangJS(role_notifications)))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(LangJS(role_name))
                            Select(RoleID, #state_id#_roles_list.role_name, "form-control m-b", #vRoleID#)
                            Input(RecipientID, "form-control  m-b hidden disabled=''",integer,text,"" )
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(notification_closure_type))
                            Select(ClosureType,notification_ClosureType,form-control ,#vClosureType#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(notification_icon))
                            Divs: row df f-valign
                        		Divs: col-md-9 mt-sm text-left
                        		    Select(NotificationIcon,notification_icon,form-control,#vNotificationIcon#)
                                DivsEnd:
                        		Divs: col-md-1 mt-sm text-left
                        		    If(#vS#==1)
                        		        Em(fa StateVal(notification_icon,#vNotificationIcon#) fa-2x text-info)
                        		    IfEnd:
                                DivsEnd:
                        		Divs: col-md-2 mt-sm text-left 
                        		    BtnPage(notification_send_roles, Em(fa fa-search), "vS:1,vRoleID:Val(RoleID),vClosureType:Val(ClosureType),vNotificationIcon:Val(NotificationIcon),vNotificHeader:Val(NotificHeader),vTextBody:Val(TextBody),vPageName:Val(PageName),vPageValue:Val(PageValue),vPageValue2:Val(PageValue2)",  btn btn-default ml4)
                                DivsEnd:
                            DivsEnd:
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(notification_header))
                            Input(NotificHeader, "form-control  m-b ",caption,text, #vNotificHeader#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(body_text_notification))
                            Input(TextBody, "form-control  m-b ",caption,text, #vTextBody#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(name_of_the_page_for_link))
                            Input(PageName, "form-control  m-b ",name,text, #vPageName#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(parameter_value_int_page))
                            Input(PageValue, "form-control  m-b ",integer,text, #vPageValue#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(parameter_value_str_page))
                            Input(PageValue2, "form-control  m-b ",integer,text, #vPageValue2#)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        Divs: pull-right
                            BtnPage(notification_view_roles, LangJS(back), "", btn btn-default btn-pill-left ml4)
                            TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:notification_send ,Name:$send$, OnSuccess: "template,notification_view_roles"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_notification_send_roles #= ContractConditions("MainCondition")`,
`p_notification_send_single #= Title:Send
Navigation(LiTemplate(notification_view_single, LangJS(single_notifications)), LangJS(send))

If(#vS#!=1)
    SetVar(vS=1)
    SetVar(vNotificHeader="")
    SetVar(vTextBody="")
    SetVar(vPageName="notification_testpage")
    SetVar(vPageValue="0")
    SetVar(vPageValue2="")
    SetVar(vNotificationIcon=1)
IfEnd:

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, LangJS(single_notifications)))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(LangJS(recipient_id))
                            InputAddress(RecipientID, "form-control m-b", #vRecipientID#)
                            Input(RoleID, "form-control  m-b hidden disabled=''",integer,text,0 )
                            Input(ClosureType, "form-control  m-b hidden disabled=''",integer,text,0)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(notification_icon))
                            Divs: row df f-valign
                        		Divs: col-md-9 mt-sm text-left
                        		    Select(NotificationIcon,notification_icon,form-control,#vNotificationIcon#)
                                DivsEnd:
                        		Divs: col-md-1 mt-sm text-left
                        		    If(#vS#==1)
                        		        Em(fa StateVal(notification_icon,#vNotificationIcon#) fa-2x text-info)
                            		IfEnd:
                                DivsEnd:
                        		Divs: col-md-2 mt-sm text-left 
                        		    BtnPage(notification_send_single, Em(fa fa-search), "vNotificationIcon:Val(NotificationIcon),vS:1,vRecipientID:Val(RecipientID),vNotificHeader:Val(NotificHeader),vTextBody:Val(TextBody),vPageName:Val(PageName),vPageValue:Val(PageValue),vPageValue2:Val(PageValue2)",  btn btn-default ml4)
                                DivsEnd:
                            DivsEnd:
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(notification_header))
                            Input(NotificHeader, "form-control  m-b ",caption,text, #vNotificHeader#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(body_text_notification))
                            Input(TextBody, "form-control  m-b ",caption,text, #vTextBody#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(name_of_the_page_for_link))
                            Input(PageName, "form-control  m-b ",name,text, #vPageName#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(parameter_value_int_page))
                            Input(PageValue, "form-control  m-b ",integer,text, #vPageValue#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(parameter_value_str_page))
                            Input(PageValue2, "form-control  m-b ",integer,text, #vPageValue2#)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        Divs: pull-right
                            BtnPage(notification_view_single, LangJS(back), "", btn btn-default btn-pill-left ml4)
                            TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:notification_send,Name:$send$,OnSuccess: "template,notification_view_single"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_notification_send_single #= ContractConditions("MainCondition")`,
`p_notification_testpage #= Title:LangJS(test_page)
Navigation(LangJS(test_page))

SetVar(type_str1 = "single")
SetVar(type_str2 = "role")

If(And(#vType#!=#type_str1#,#vType#!=#type_str2#))
    Divs(md-12, panel panel-default data-sweet-alert)
        Divs(panel-footer text-center) 
            Label(LangJS(test_page_attention))
            SetVar(vNotificID = "null")
            SetVar(vPageValue = "null")
            SetVar(vPageValue2 = "null")
            SetVar(vType = "null")
         DivsEnd:   
    DivsEnd:
IfEnd:
    
Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, LangJS(test_page)))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(LangJS(notification_id))
                            Input(NotificID, "form-control  m-b disabled=''",text,text,#vNotificID#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(notification_type))
                            Input(NotificType, "form-control  m-b disabled=''",text,text,#vType#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(page_value_int))
                            Input(PageValue, "form-control  m-b disabled=''",text,text,#vPageValue#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(page_value_str))
                            Input(PageValue2, "form-control  m-b disabled=''",text,text,#vPageValue2#)
                        DivsEnd:
                    FormEnd:    
                DivsEnd:
                
                If(#vType# == #type_str1#)
                    Divs(panel-footer)
                        Divs:clearfix 
                            Divs: pull-left
                            DivsEnd:
                            Divs: pull-right
                                BtnContract(notification_single_close, Close,Do you want to close this notification?,"NotificID:Val(NotificID)",'btn btn-primary btn-block',template,notification_view_single)
                            DivsEnd:
                        DivsEnd:
                    DivsEnd:  
                IfEnd:
                If(#vType# == #type_str2#)                        
                    Divs(panel-footer)
                        Divs:clearfix 
                            Divs: pull-left
                                BtnContract(notification_role_processing, Begin,Do you want to start processing this notification?,"NotificID:Val(NotificID)",'btn btn-primary btn-block',template,notification_view_roles)
                            DivsEnd:
                            Divs: pull-right
                                BtnContract(notification_role_close, Close,Do you want to finish processing this notification?,"NotificID:Val(NotificID)",'btn btn-primary btn-block',template,notification_view_roles)
                            DivsEnd:
                        DivsEnd:
                    DivsEnd:         
                IfEnd:        
                
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_notification_testpage #= ContractConditions("MainCondition")`,
`p_notification_view_roles #= Title:LangJS(role_notifications)
Navigation(LangJS(role_notifications)) 

AutoUpdate(2)
Include(notification)
AutoUpdateEnd:
        
Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, LangJS(role_notifications)))
    Divs(panel-body)
        Divs(table-responsive)
        Table{
            Table: #state_id#_notification
            Class: table-striped table-bordered table-hover data-role="table"
            Order: "closed ASC, id ASC"
            Where: "type = 'role'"
            Columns:  [
                [ ID,  SetVar(style=If(#closed#==0,"text-normal","text-muted")) Div(text-center #style#, #id#), text-center h4 align="center" width="50" ],
                [ Role, Div(text-bold #style# , GetOne(role_name, #state_id#_roles_list#, "id", #role_id#) ),  text-center h4 align="center" ],
                [ Icon, Div(text-center, Em(fa StateVal(notification_icon,#icon#) fa-1x text-info) ), text-center h4 align="center" width="50" ],
                [ Page name, Div(#style# , #page_name# ), h4 ],
                [ Value 1, Div( text-center #style# , #page_value# ), text-center h4 align="center" width="80" ],
                [ Value 2, Div(text-center #style# , #page_value2# ), text-center h4 align="center" width="100"],
                [ Name<br>(started \ closed), GetRow("start", #state_id#_citizens, "id", #started_processing_id#)  GetRow("stop", #state_id#_citizens, "id", #started_processing_id#) If(#started_processing_id#, Div(text-center #style#, #start_name#), "") If(#finished_processing_id#, Div(text-center #style#, #stop_name#), ""), text-center align="center" width="125" ],
                [ Date<br>(started \ closed), Div( text-center #style#, DateTime(#started_processing_time#, YYYY.MM.DD HH:MI)) Div( text-center #style#, DateTime(#finished_processing_time#, YYYY.MM.DD HH:MI)), text-center align="center" width="125"],
                [ Status, Div(text-center text-bold #style#,  If(#closed#==0, If(#started_processing_id#==0, "Active", "Process"), "Closed") ), text-center h4 align="center" width="65" ],
                [ , Div(text-center #style#,  If(#closed#==0, If(#started_processing_id#==0, BtnContract(notification_role_processing, Em(fa fa-edit), Do you want to start processing this notification?,"NotificID:#id#",'btn btn-primary btn-block',template,notification_view_roles), BtnContract(notification_role_close, Em(fa fa-close), Do you want to finish processing this notification?,"NotificID:#id#",'btn btn-danger btn-block',template,notification_view_roles) ), "") ), text-center h4 align="center" width="50" ]
            ]
        }
        DivsEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs:clearfix 
            Divs: pull-left
            DivsEnd:
            Divs: pull-right
                BtnPage(notification_send_roles, $CreateNew$, "",  btn btn-primary)
            DivsEnd:
        DivsEnd:
    DivsEnd:    
DivsEnd:

PageEnd:`,
`pc_notification_view_roles #= ContractConditions("MainCondition")`,
`p_notification_view_single #= Title:LangJS(single_notifications)
Navigation(LangJS(single_notifications))
   
AutoUpdate(2)
Include(notification)
AutoUpdateEnd:
        
Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, LangJS(single_notifications)))
    Divs(panel-body)
        Divs(table-responsive)
        Table{
            Table: #state_id#_notification
            Class: table-striped table-bordered table-hover data-role="table"
            Order: "closed ASC, id ASC"
            Where: "type = 'single'"
            Columns:  [
                [ ID,  SetVar(style=If(#closed#==0,"text-normal","text-muted")) Div(text-center #style#, #id#), text-center h4 align="center" width="50" ],
                [ Recipient, GetRow("recipient", #state_id#_citizens, "id", #recipient_id#) Div(text-bold #style#, Image(If(GetVar(recipient_avatar)!=="", #recipient_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30),   #recipient_name#), text-center h4 align="center" ],
                [ Icon, Div(text-center, Em(fa StateVal(notification_icon,#icon#) fa-1x text-info) ), text-center h4 align="center" width="50" ],
                [ Page name, Div(#style# , #page_name# ), h4 ],
                [ Value 1, Div(text-center #style# , #page_value# ), text-center h4 align="center" width="80"],
                [ Value 2, Div(text-center #style# , #page_value2# ), text-center h4 align="center" width="100"],
                [ Closing date, Div(text-center #style#, DateTime(#finished_processing_time#, YYYY.MM.DD HH:MI)), text-center h4 align="center" width="125"],
                [ Status, If(#closed#==0, Div(text-bold text-center #style#, "Active") ,  Div(text-bold text-center #style#, "Closed") ), text-center h4 align="center" width="65" ],
                [ , If(#closed#==0, BtnContract(notification_single_close, Em(fa fa-close), Do you want to close this notification?,"NotificID:#id#",'btn btn-danger btn-block',template,notification_view_single),""), text-center align="center" width="65" ]
            ]
        }
        DivsEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs:clearfix 
            Divs: pull-left
            DivsEnd:
            Divs: pull-right
                BtnPage(notification_send_single, Send, "",  btn btn-primary)
            DivsEnd:
        DivsEnd:
    DivsEnd:    
DivsEnd:

PageEnd:`,
`pc_notification_view_single #= ContractConditions("MainCondition")`,
`p_Property #= Title : LangJS(property)
UList(breadcrumb, ol)
    Li(LangJS(property))
UListEnd:

Divs(md-12)
    Include(property_list, ownerID=GetVar(ownerID))
DivsEnd:`,
`pc_Property #= ContractConditions("MainCondition")`,
`p_PropertyDetails #= FullScreen(1)
Title: Best country
Navigation(LiTemplate(dashboard_default, Citizen))
SetVar(hmap=350)

GetRow(myproperty, #state_id#_property, "id", #PropertyId#)

Divs(md-8, panel panel-default panel-body)
    Map(#myproperty_coords#)
DivsEnd:


Divs(md-4, panel panel-default panel-body data-sweet-alert)
    Divs(panel-heading)
        Divs(panel-title)
           MarkDown: Sell Price
        DivsEnd:
    DivsEnd:
    
        Input(PropertyId, "hidden", text, text, Param(PropertyId))
        
    Divs(form-group)
            InputMoney(SellPrice, "form-control input-lg ", #myproperty_sell_price#)
            
    DivsEnd:
    
    TxButton{ Contract: SetPropertySellPrice, Name: "Save", Inputs: "Price=SellPrice"}
DivsEnd:


Divs(md-4, panel panel-default panel-body data-sweet-alert)
    Divs(panel-heading)
        Divs(panel-title)
           MarkDown: Rent Price
        DivsEnd:
    DivsEnd:
    
        Input(PropertyId, "hidden", text, text, Param(PropertyId))
        
    Divs(form-group)
            InputMoney(RentPrice, "form-control input-lg ", #myproperty_rent_price#)
    DivsEnd:
    
    TxButton{ Contract: SetPropertyRentPrice, Name: "Save", Inputs: "Price=RentPrice"}
DivsEnd:


Divs(md-12, panel panel-default panel-body)
MarkDown : ## Offers
Table {
    Class: table-striped table-hover
    Table: #state_id#_property_offers
    Where: property_id='#PropertyId#'
    Columns: [[ID, #id#], [price, Money(#price#)], [sender_citizen_id, #sender_citizen_id#], [Type, StateLink(property_prices_types, #type#) ], [Accept, BtnPage(PropertyAcceptOffers, Accept, "OfferId:#id#")] ]
}


PageEnd:`,
`pc_PropertyDetails #= ContractConditions("MainCondition")`,
`p_property_list #= If(GetVar(ownerID))
    SetVar(whereClause = citizen_id='GetVar(ownerID)')
Else:
    SetVar(whereClause = "'1'='1'")
IfEnd:

GetList(ava, #state_id#_citizens, "id,avatar,name", "id!=0")
Divs(md-12, panel panel-default panel-body)
    Divs(table-responsive)
        MarkDown : ## LangJS(property)
        Table {
            Class: table-striped table-bordered table-hover data-role="table"
            Table:  #state_id#_property
            Order: id
            Where:GetVar(whereClause)
            Columns: [[ID, #id#],[Address, #name#], [Type, StateLink(property_types, #type#)],
            [Location on the map , Map(#coords#,maptype=satellite)], 
            [Owner, LinkPage(CitizenInfo, Div("text-center",GetRow("citizens", #state_id#_citizens, "id", GetVar(citizen_id))Div("",Image(If(GetVar(citizens_avatar)!=="",#citizens_avatar#,"/static/img/avatar.svg"), Avatar, img-thumbnail img-circle thumb-full w-40 h-40)Div("text-center", #citizens_name#))),"citizenId:'#citizens_id#',gstate_id:#state_id#",pointer)],
            [Leaser, If(#leaser# != 0, LinkPage(CitizenInfo, Div("text-center",GetRow("leaser", #state_id#_citizens, "id", GetVar(leaser)) Div("",Image(If(GetVar(leaser_avatar)!=="",#leaser_avatar#,"/static/img/avatar.svg"), Avatar, img-thumbnail img-circle thumb-full w-40 h-40)Div("text-center", #leaser_name#))),"citizenId:'#leaser_id#',gstate_id:#state_id#",pointer),"") ],
            [Edit,BtnPage(EditProperty,Edit,"PropertyId:#id#")]]
        }
        BtnPage(AddProperty, LangJS(add_property), '',btn btn-primary) BR()
    DivsEnd:
DivsEnd:`,
`pc_property_list #= ContractConditions("MainCondition")`,
`p_roles_assign #= Title:Assign role
Navigation(LiTemplate(roles_assign, Assign role)) 

If(#vS#==1)
    SetVar(vMemberID=#vMemberID#)
    SetVar(vRoleID=#vRoleID#)
Else:
    SetVar(vS=0)
    SetVar(vMemberID="")
    SetVar(vRoleID=#vID#)
IfEnd:


Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, Assign role))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(Member)
                            Divs(input-group)
                                Select(MemberID, #state_id#_citizens.name, "form-control m-b", #vMemberID#)
                                Divs(input-group-btn)
                                    BtnPage(roles_assign, Em(fa fa-question), "vMemberID:Val(MemberID),vRoleID:Val(RoleID),vS:1",  btn btn-default ml4)
                                DivsEnd:
                            DivsEnd: 
                            If(#vS#==1)
                                GetRow("citizen", #state_id#_citizens, "id", #vMemberID#)
                                Div(text-normal, <br>)
                                Divs: row df f-valign
                            		Divs: col-md-5 mt-sm text-right
                                    Div(h5 text-normal, "Member:")
                                    DivsEnd:
                            		Divs: col-md-7 mt-sm text-left
                                    Div(h5 text-normal, Image(If(GetVar(citizen_avatar)!=="", #citizen_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),   #citizen_name#)
                                    DivsEnd:
                                DivsEnd:
                                Divs: row df f-valign
                            		Divs: col-md-5 mt-sm text-right
                                    Div(h5 text-normal, LangJS(member_id))
                                    DivsEnd:
                            		Divs: col-md-7 mt-sm text-left
                                    Div(h5 text-normal, Address(#citizen_id#))
                                    DivsEnd:
                                DivsEnd:
                            IfEnd:
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(role_name))
                            Select(RoleID, #state_id#_roles_list.role_name, "form-control m-b", #vRoleID#)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        Divs: pull-right
                            BtnPage(roles_view, "Back", "", btn btn-default btn-pill-left ml4)
                            TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:roles_Assign, Name:"Assign", OnSuccess: "template,roles_view"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_roles_assign #= ContractConditions("MainCondition")`,
`p_roles_create #= Title:$new_role$
Navigation(LiTemplate(roles_list, $roles$), $new_role$) 

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, $new_role$))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label("$name$")
                            Input(position_name, "form-control  m-b ",$name$,text)
                        DivsEnd:
                        Divs(form-group)
                            Label("$type$")
                            Select(position_type,roles_types,form-control)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        Divs: pull-right
                            BtnPage(roles_list, "LangJS(back)", "", btn btn-default btn-pill-left ml4)
                            TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:roles_Add,Name:"$create$", OnSuccess: "template,roles_list"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_roles_create #= ContractConditions("MainCondition")`,
`p_roles_list #= Title:$roles$
Navigation($roles$)
   
AutoUpdate(2)
Include(notification)
AutoUpdateEnd:

If(#isSearch#==1)
    SetVar(vWhere="role_name = '#RoleName#'")
Else:
    SetVar(vWhere="id <> 0")
IfEnd:
        
Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, "$roles$"))
    Divs(panel-body)
        Divs: row df f-valign
			Divs: col-md-1 mt-sm text-right
			    Div(text-bold, "$name$:")
            DivsEnd:
			Divs: col-md-10 mt-sm text-left
                Input(StrSearch, "form-control  m-b")
            DivsEnd:
            Divs: col-md-1 mt-sm
                TxButton { Contract:roles_Search, Name: $search$, OnSuccess: "template,roles_list,RoleName:Val(StrSearch),isSearch:1" }
            DivsEnd:
        DivsEnd:
        Div(text-bold, <br>)
        Divs(table-responsive)
        Table{
            Table: #state_id#_roles_list
            Class: table-striped table-bordered table-hover data-role="table"
            Order: "delete ASC, id ASC"
            Where: #vWhere#
            Columns:
            [
                [ ID,  SetVar(style=If(#delete#==0,"text-normal","text-muted")) Div(text-center #style#, #id#), text-center h4 align="center" width="50" ],
                [ $role_name$, If(#delete#==0, Div(#style# text-bold, LinkPage(roles_view, #role_name#, "RoleName:'#role_name#',isSearch:1",profile-flag text-blue) ), Div(#style#, #role_name# )), h4],
                [ $type$, Div(text-center text-bold #style#, StateVal(roles_types,#role_type#)),  text-center h4 align="center" width="80" ],
                [ $creator$, Div(text-center text-bold #style#, #creator_name#), text-center h4 align="center" ],
                [ $date_create$, Div(text-center #style#, DateTime(#date_create#, DD.MM.YYYY HH:MI) ), text-center h4 align="center" width="125" ],
                [ $date_delete$, Div(text-center #style#, DateTime(#date_delete#, DD.MM.YYYY HH:MI) ), text-center h4 align="center" width="125" ],
                [ $status$, If(#delete#==0, Div(text-center text-bold #style#,"Active"), Div(text-center text-bold #style#, "Deleted")), text-center h4 align="center" width="65" ],
                [ , If(#delete#==0, BtnPage(roles_assign, Em(fa fa-plus), "vID:#id#", btn btn-success),""), text-center align="center" width="60" ],
                [ , If(#delete#==0, BtnContract(roles_Del, Em(fa fa-close), Do you want to delete this role?,"IDRole:#id#",'btn btn-danger btn-block',template,roles_list),""), text-center align="center" width="60" ]
            ]
        }
        DivsEnd:
        If(#isSearch#==1)
            Div(h4 m0 text-bold text-left, <br>)
            Divs(text-center)
                    BtnPage(roles_list, <b>$view_all$</b>,"isSearch:0",btn btn-primary btn-oval)
            DivsEnd:
        IfEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs:clearfix 
            Divs: pull-left
            DivsEnd:
            Divs: pull-right
                BtnPage(roles_create, $add_role$, "",  btn btn-primary)
            DivsEnd:
        DivsEnd:
    DivsEnd:    
DivsEnd:

PageEnd:`,
`pc_roles_list #= ContractConditions("MainCondition")`,
`p_roles_view #= If(#isSearch#==1)
    Title:Assigned: #RoleName#
    SetVar(vWhere="role_name = '#RoleName#'")
Else:
    Title:Assigned: all 
    SetVar(vWhere="id <> 0")
IfEnd:

Navigation(LiTemplate(roles_list, $roles$), Assigned) 
        
Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, "Assigned"))
    Divs(panel-body)
        Divs: row df f-valign
			Divs: col-md-1 mt-sm text-right
			    Div(text-bold, "$roles$:")
            DivsEnd:
			Divs: col-md-10 mt-sm text-left
			    If(#isSearch#==1)
                    Input(StrSearch, "form-control  m-b", text, text, #RoleName#)
                Else:
                    Input(StrSearch, "form-control  m-b")
                IfEnd:
            DivsEnd:
            Divs: col-md-1 mt-sm
                TxButton { Contract:roles_Search, Name: $search$, OnSuccess: "template,roles_view,RoleName:Val(StrSearch),isSearch:1" }
            DivsEnd:
        DivsEnd:
        Div(text-bold, <br>)
        Divs(table-responsive)
        Table{
            Table: #state_id#_roles_assign
            Class: table-striped table-bordered table-hover data-role="table"
            Order: "delete ASC, id ASC"
            Where: #vWhere#
            Columns:  
            [
                [ ID,  SetVar(style=If(#delete#==0,"text-normal","text-muted")) Div(text-center #style#, #id#), text-center h4 align="center" width="50" ],
                [ $role_name$, Div(text-bold #style#, #role_name# ), text-center h4 align="center"],
                [ $type$, Div(text-center #style#, SetVar(role_type = GetOne(role_type, #state_id#_roles_list#, "id", #role_id#)) StateVal(roles_types, #role_type# ) ), text-center h4 align="center" width="65"],
                [ $member$, SetVar(citizens_avatar=GetOne(avatar, #state_id#_citizens#, "id",  #member_id#))  Div(text-bold #style#, Image(If(GetVar(citizens_avatar)!=="", #citizens_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30),   #member_name#), text-center h4 align="center" ],
                [ $date_start$, Div(text-center #style#, DateTime(#date_start#, DD.MM.YYYY HH:MI) ), text-center h4 align="center" width="125" ],
                [ $date_end$, Div(text-center #style#, DateTime(#date_end#, DD.MM.YYYY HH:MI) ), text-center h4 align="center" width="125" ],
                [ Appointed, Div(text-center #style#, #appointed_by_name# ), text-center h4 align="center"],
                [ $status$, Div(text-bold text-center #style#, If(#delete#==0, If(#role_type#==1, "Assigned", If(#appointed_by_id# ==0,"Waiting","Elective") ), "Deleted") ), text-center h4 align="center" width="65" ],
                [ , If(#delete#==0, BtnContract(roles_UnAssign, Em(fa fa-close), Are you sure you want to delete this member from the role?,"assignID:#id#",'btn btn-danger btn-block',template,roles_view),""), text-center align="center" width="60" ]    
            ]
        }
        DivsEnd:
        If(#isSearch#==1)
            Div(h4 m0 text-bold text-left, <br>)
            Divs(text-center)
                    BtnPage(roles_view, <b>$view_ all$</b>,"isSearch:0",btn btn-primary btn-oval)
            DivsEnd:
        IfEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_roles_view #= ContractConditions("MainCondition")`,
`p_tokens_accounts_add #= Title:Add account 
Navigation(LiTemplate(tokens_accounts_list, Accounts), Add account) 

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, Add account))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(LangJS(citizen_id))
                            InputAddress(CitizenID, "form-control input-lg m-b")
                        DivsEnd:
                        Divs(form-group)
                            Label(Account type)
                            Select(TypeAccount,tokens_accounts_type,form-control input-lg)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        Divs: pull-right
                            BtnPage(tokens_accounts_list, "Back", "", btn btn-default btn-pill-left ml4)
                            TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:tokens_Account_Add,Name:"Add", Inputs:"TypeAccount=TypeAccount,CitizenID=CitizenID",OnSuccess: "template,tokens_accounts_list"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_tokens_accounts_add #= ContractConditions("MainCondition")`,
`p_tokens_accounts_list #= Title:Accounts 
Navigation(Accounts)
   
If(#isSearch#==1)
    SetVar(vWhere="citizen_id = #citizen_id#")
    SetVar(citizen_id=GetOne(id, #state_id#_citizens#, "name",  #vStrSearch#))
Else:
    SetVar(vWhere="id <> 0")
IfEnd:
        
Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, "Account"))
    Divs(panel-body)
        Divs: row df f-valign
			Divs: col-md-1 mt-sm text-right
			    Div(text-bold, "Member:")
            DivsEnd:
			Divs: col-md-10 mt-sm text-left
                Input(StrSearch, "form-control  m-b")
            DivsEnd:
            Divs: col-md-1 mt-sm
                TxButton { Contract:tokens_SearchCitizen, Name: Search, OnSuccess: "template,tokens_accounts_list,vStrSearch:Val(StrSearch),isSearch:1" }
            DivsEnd:
        DivsEnd:
        Div(text-bold, <br>)
        Divs(table-responsive)
                If(#citizen_id#) 
                    Table{
                        Table: #state_id#_accounts
                        Class: table-striped table-bordered table-hover data-role="table"
                        Order: "onhold ASC, id ASC"
                        Where: #vWhere#
                        Columns:  [
                            [ ID,  SetVar(style=If(#onhold#==0,"text-normal","text-muted")) Div(text-center #style#, #id#), text-center h4 align="center" width="50" ],
                            [ Member, GetRow("citizen", #state_id#_citizens, "id", #citizen_id#) Div(text-bold #style#,Image(If(GetVar(citizen_avatar)!=="", #citizen_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30),   #citizen_name#), text-center h4 align="center" width="215"],
                            [ Member ID,  Div(text-center #style#, Address(#citizen_id#) Em(clipboard fa fa-clipboard id="clipboard" aria-hidden="true" data-clipboard-action="copy" data-clipboard-text=Address(#citizen_id#) onClick="CopyToClipboard('#clipboard')", ) ), text-center h4 align="center" width="230"],
                            [ Type, Div(text-center #style#, StateVal(tokens_accounts_type,#type#) ), text-center h4 align="center" width="130" ],
                            [ Status, If(#onhold#==0, Div(text-center text-bold,"active"), Div(text-center text-bold #style#, "onHold")), text-center h4 align="center" width="80" ],
                            [ Amount, Div(text-right text-bold #style#, Money(#amount#) ), text-center h4 align="center" width="130"],
                            [ , If(#onhold#==0, BtnContract(tokens_Account_Close, Em(fa fa-close),Do you want to close this account?,"idAccount:#id#",'btn btn-danger btn-block',template,tokens_accounts_list),""), text-center align="center" width="60" ]
                        ]
                    }
                Else:
                    Div(h3 m0 text-bold text-center, "No account was found")
                IfEnd:
        DivsEnd:
        If(#isSearch#==1)
            Div(h4 m0 text-bold text-left, <br>)
            Divs(text-center)
                    BtnPage(tokens_accounts_list, <b>View all</b>,"isSearch:0",btn btn-primary btn-oval)
            DivsEnd:
        IfEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs:clearfix 
            Divs: pull-left
            DivsEnd:
            Divs: pull-right
                    BtnPage(tokens_accounts_add, Add account, "",  btn btn-primary)
            DivsEnd:
        DivsEnd:
    DivsEnd:    
DivsEnd:

PageEnd:`,
`pc_tokens_accounts_list #= ContractConditions("MainCondition")`,
`p_tokens_create #= Title:LangJS(create_tokens)
Navigation(LiTemplate(tokens_list, LangJS(tokens)), LangJS(create_tokens)) 

If(#isDateExpiration#==1)
    SetVar(isDateExpiration=1)
Else:
    SetVar(isDateExpiration=0)
IfEnd:

If(#vAmount#>0)
    SetVar(vAmount=#vAmount#)
Else:
    SetVar(vAmount=1000.00)
IfEnd:

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, LangJS(create_tokens)))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(LangJS(name))
                            Input(NameTokens, "form-control  m-b ",text,text)
                        DivsEnd:
                        If(#isDateExpiration#==1)
                            Divs(form-group)
                                Label(LangJS(date_expiration))
                                Divs(input-group)
                                    InputDate(DateExpiration,form-control,Now(YYYY.MM.DD 00:00,5 days))
                                    Divs(input-group-btn)
                                        BtnPage(tokens_create, Em(fa fa-minus), "isDateExpiration:0,vNameTokens:Val(NameTokens),vTypeEmission:Val(TypeEmission),vRollbackTokens:Val(RollbackTokens),vAmount:Val(Amount)",  btn btn-default ml4)
                                    DivsEnd:
                                DivsEnd:
                            DivsEnd:  
                        Else:
                            Divs(form-group)
                                Label(LangJS(date_expiration))
                                Divs(input-group)
                                    Input(NotLimited, "form-control  m-b disabled=''", text, text, $not_limited$)
                                    Divs(input-group-btn)
                                        BtnPage(tokens_create, Em(fa fa-plus), "isDateExpiration:1,vTypeEmission:Val(TypeEmission),vRollbackTokens:Val(RollbackTokens),vAmount:Val(Amount)",  btn btn-default ml4)
                                    DivsEnd:
                                DivsEnd:
                            DivsEnd:  
                        IfEnd:
                        Divs(form-group)
                            Label(LangJS(type_emission))
                            Select(TypeEmission,tokens_type_emission,form-control, #vTypeEmission#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(rollback_tokens))
                            Select(RollbackTokens,tokens_rollback_tokens,form-control, #vRollbackTokens#)
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(amount))
                            Input(Amount, "form-control  m-b ",text,text,#vAmount#)
                        DivsEnd:
                        Input(isDateExpiration, "form-control  m-b hidden disabled=''", text, text, #isDateExpiration#)
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        If(#isDateExpiration#==1)
                            Divs: pull-right
                                BtnPage(tokens_list, LangJS(back), "", btn btn-default btn-pill-left ml4)
                                TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:tokens_Emission,Name:"Execute", Inputs:"TypeEmission=TypeEmission,RollbackTokens=RollbackTokens,Amount=Amount,isDateExpiration=isDateExpiration,DateExpiration=DateExpiration",OnSuccess: "template,tokens_list"}
                            DivsEnd:
                        Else:
                            Divs: pull-right
                                BtnPage(tokens_list, LangJS(back), "", btn btn-default btn-pill-left ml4)
                                TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:tokens_Emission,Name:"$execute$", Inputs:"NameTokens=NameTokens,TypeEmission=TypeEmission,RollbackTokens=RollbackTokens,Amount=Amount,isDateExpiration=isDateExpiration,DateExpiration=isDateExpiration",OnSuccess: "template,tokens_list"}
                            DivsEnd:
                        IfEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_tokens_create #= ContractConditions("MainCondition")`,
`p_tokens_emission #= Title:Emission
Navigation(LiTemplate(tokens_list, Tokens), Emission) 

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, Emission))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(LangJS(account))
                            Input(InputAccount, "form-control  m-b disabled=''",text,text,StateVal(tokens_accounts_type,1))
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(amount))
                            Input( Amount, "form-control  m-b ",text,text,100.00)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        Divs: pull-right
                            BtnPage(tokens_list, "Back", "", btn btn-default btn-pill-left ml4)
                            TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:tokens_EmissionAdd,Name:"Execute", Inputs:"Amount=Amount",OnSuccess: "template,tokens_list"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_tokens_emission #= ContractConditions("MainCondition")`,
`p_tokens_list #= Title:LangJS(tokens)
Navigation(LangJS(tokens))
   
SetVar(smName="tokens_Close")   
Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, LangJS(tokens)))
    Divs(panel-body)
        Divs(table-responsive)
            Table{
                Table: #state_id#_accounts_tokens
                Class: table-striped table-bordered table-hover data-role="table"
                Order: #delete#
                Columns:  [ 
                    [ ID,  SetVar(style=If(#delete#==0,"text-normal","text-muted")) Div(text-center #style#, #id#), text-center h4 align="center" width="50" ],
                    [ $name$,  Div(text-left text-bold #style#, #name_tokens#), h4 ],
                    [ $rollback_tokens$, Div(text-bold #style#, StateVal(tokens_rollback_tokens,#flag_rollback_tokens#) ), h4 ],
                    [ $date_create$,  Div(#style# text-center, DateTime(#date_create#, YYYY.MM.DD HH:MI) ), text-center h4 align="center" width="130" ],
                    [ $expiration$, If(#date_expiration#, Div(#style# text-center, DateTime(#date_expiration#, YYYY.MM.DD HH:MI)), Div(#style# text-center, LangJS(not_limited))), text-center h4 align="center" width="130"],
                    [ $status$, If(#delete#==0, Div(text-bold text-center #style#, "Active") ,  Div(text-bold text-center #style#, "Closed") ), text-center h4 align="center" width="80" ],
                    [ $emission$, Div(text-bold text-center #style#, If(#delete#==0, If(#type_emission#==2, BtnPage(tokens_emission, Em(fa fa-plus), "",  btn btn-success),StateVal(tokens_type_emission,#type_emission#)), StateVal(tokens_type_emission,#type_emission#)) ), text-center h4 align="center" width="130" ],
                    [ $amount$,  Div(text-right text-bold #style#, Money(#amount#) ), text-center h4 align="center" width="130" ],
                    [ , If(#delete#==0, BtnContract(tokens_Close, Em(fa fa-close),Do you want to close this token?,"tokens_id:#id#",'btn btn-danger btn-block',template,tokens_list),""), text-center align="center" width="60" ]
                ]
            }
        DivsEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs:clearfix 
            Divs: pull-left
                BtnContract(tokens_CheckingClose, LangJS(check_to_close),Do you want to check to close the token?,"",'btn btn-danger btn-block',template,tokens_list)
            DivsEnd:
            Divs: pull-right
                BtnPage(tokens_create, LangJS(create_new), "",  btn btn-primary)
            DivsEnd:
        DivsEnd:
    DivsEnd:    
DivsEnd:

PageEnd:`,
`pc_tokens_list #= ContractConditions("MainCondition")`,
`p_tokens_money_rollback #= Title:LangJS(money_rollback)
Navigation(LangJS(money_rollback))

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, LangJS(money_rollback)))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(LangJS(account_id_for_rollback))
                            Divs(input-group)
                                Select(SenderAccountID, #state_id#_accounts.id, "form-control m-b",#vSenderAccID#)
                                Divs(input-group-btn)
                                    BtnPage(tokens_money_rollback, Em(fa fa-search), "vSenderAccID:Val(SenderAccountID),vS:1",  btn btn-default ml4)
                                DivsEnd:
                            DivsEnd:
                            If(#vS#==1)
                            
                                GetRow("acc", #state_id#_accounts, "id", #vSenderAccID#)
                                GetRow("citizen", #state_id#_citizens, "id", #acc_citizen_id#)
                                Div(text-normal, <br>)
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		        Div(h5 text-normal, LangJS(balance))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		        Div(h5 text-normal,  Money(#acc_amount#))
                                    DivsEnd:
                                DivsEnd:
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		        Div(h5 text-normal, LangJS(account_type))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		        Div(h5 text-normal, StateVal(tokens_accounts_type,#acc_type#) )
                                    DivsEnd:
                                DivsEnd:
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		        Div(h5 text-normal, LangJS(status))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		        Div(h5 text-normal, If(#acc_onhold#==0,"active","onHold"))
                                    DivsEnd:
                                DivsEnd:

                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                                        Div(h5 text-normal, LangJS(citizen_word))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                                        Div(h5 text-normal, Image(If(GetVar(citizen_avatar)!=="", #citizen_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),   #citizen_name#)
                                    DivsEnd:
                                DivsEnd:
                            IfEnd:
                        DivsEnd: 
                        Divs(form-group)
                            Label(LangJS(amount))
                            Input(Amount, "form-control  m-b ",text,text,50.00)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        Divs: pull-right
                            TxButton{ClassBtn:btn btn-primary, Contract:tokens_Money_Rollback,Name:"$rollback_tokens$", Inputs:"AccountID=SenderAccountID,Amount=Amount",OnSuccess: "template,tokens_accounts_list"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_tokens_money_rollback #= ContractConditions("MainCondition")`,
`p_tokens_money_transfer #= Title:LangJS(money_transfer)
Navigation(LangJS(money_transfer)) 

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, LangJS(money_transfer)))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(Sender account ID)
                            Divs(input-group)
                                Select(SenderAccountID, #state_id#_accounts.id, "form-control m-b",#vSenderAccID#)
                                Divs(input-group-btn)
                                    BtnPage(tokens_money_transfer, Em(fa fa-search), "vSenderAccID:Val(SenderAccountID),vRecipientAccID:Val(RecipientAccountID),vS:1,vR:0",  btn btn-default ml4)
                                DivsEnd:
                            DivsEnd:
                            If(#vS#==1)
                            
                                GetRow("acc", #state_id#_accounts, "id", #vSenderAccID#)
                                GetRow("citizen", #state_id#_citizens, "id", #acc_citizen_id#)
                                Div(text-normal, <br>)
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(balance))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, Money(#acc_amount#))
                                    DivsEnd:
                                DivsEnd:
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(account_type))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, StateVal(tokens_accounts_type,#acc_type#))
                                    DivsEnd:
                                DivsEnd:

                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(status))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, If(#acc_onhold#==0,"active","onHold"))
                                    DivsEnd:
                                DivsEnd:

                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                                    Div(h5 text-normal, LangJS(citizen_word))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                                    Div(h5 text-normal, Image(If(GetVar(citizen_avatar)!=="", #citizen_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),   #citizen_name#)
                                    DivsEnd:
                                DivsEnd:
                                
                            IfEnd:
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(recipient_account_id))
                            Divs(input-group)
                                Select(RecipientAccountID, #state_id#_accounts.id, "form-control m-b",#vRecipientAccID#)
                                Divs(input-group-btn)
                                    BtnPage(tokens_money_transfer, Em(fa fa-search), "vSenderAccID:Val(SenderAccountID),vRecipientAccID:Val(RecipientAccountID),vS:0,vR:1",  btn btn-default ml4)
                                DivsEnd:
                            DivsEnd: 
                            If(#vR#==1)
                                GetRow("acc", #state_id#_accounts, "id", #vRecipientAccID#)
                                GetRow("citizen", #state_id#_citizens, "id", #acc_citizen_id#)
                                Div(text-normal, <br>)
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(balance))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, Money(#acc_amount#))
                                    DivsEnd:
                                DivsEnd:
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(account_type))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, StateVal(tokens_accounts_type,#acc_type#))
                                    DivsEnd:
                                DivsEnd:

                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(status))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, If(#acc_onhold#==0,"active","onHold"))
                                    DivsEnd:
                                DivsEnd:

                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                                    Div(h5 text-normal, LangJS(citizen_word))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                                    Div(h5 text-normal, Image(If(GetVar(citizen_avatar)!=="", #citizen_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),   #citizen_name#)
                                    DivsEnd:
                                DivsEnd:
                            IfEnd:
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(amount))
                            Input(Amount, "form-control  m-b ",text,text,12.50)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        Divs: pull-right
                            TxButton{ClassBtn:btn btn-primary, Contract:tokens_Money_Transfer,Name:"Send", Inputs:"SenderAccountID=SenderAccountID,RecipientAccountID=RecipientAccountID,Amount=Amount",OnSuccess: "template,tokens_accounts_list"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_tokens_money_transfer #= ContractConditions("MainCondition")`,
`p_tokens_money_transfer_agency #= Title:LangJS(money_transfer_for_agency)
Navigation(LangJS(money_transfer))

SetVar(person_acc=3)
SetVar(agency_acc=4)  
SetVar(company_acc=5)  

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, LangJS(money_transfer)))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(LangJS(recipient_account_id))
                            Divs(input-group)
                                Select(RecipientAccountID, #state_id#_accounts.id, "form-control m-b",#vRecipientAccID#)
                                Divs(input-group-btn)
                                    BtnPage(tokens_money_transfer_agency, Em(fa fa-search), "vSenderAccID:Val(SenderAccountID),vRecipientAccID:Val(RecipientAccountID),vS:0,vR:1",  btn btn-default ml4)
                                DivsEnd:
                            DivsEnd:
                            If(#vR#==1)
                                GetRow("acc", #state_id#_accounts, "id", #vRecipientAccID#)
                                GetRow("citizen", #state_id#_citizens, "id", #acc_citizen_id#)
                                Div(text-normal, <br>)
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(balance))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, Money(#acc_amount#))
                                    DivsEnd:
                                DivsEnd:
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(account_type))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, StateVal(tokens_accounts_type,#acc_type#))
                                    DivsEnd:
                                DivsEnd:

                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(status))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, If(#acc_onhold#==0,"active","onHold"))
                                    DivsEnd:
                                DivsEnd:

                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                                    Div(h5 text-normal, LangJS(citizen_word))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                                    Div(h5 text-normal, Image(If(GetVar(citizen_avatar)!=="", #citizen_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),   #citizen_name#)
                                    DivsEnd:
                                DivsEnd:
                            IfEnd:
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(amount))
                            Input(Amount, "form-control  m-b ",text,text,12.50)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs:clearfix 
                        Divs: pull-left
                        DivsEnd:
                        Divs: pull-right
                            TxButton{ClassBtn:btn btn-primary, Contract:tokens_Money_Transfer_extra,Name:"Send", Inputs:"SenderAccountType#=agency_acc,RecipientAccountID=RecipientAccountID,Amount=Amount",OnSuccess: "template,tokens_accounts_list"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:  
            DivsEnd:
                
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_tokens_money_transfer_agency #= ContractConditions("MainCondition")`,
`p_tokens_money_transfer_company #= Title:LangJS(money_transfer_for_company)
Navigation(LangJS(money_transfer))

SetVar(person_acc=3)
SetVar(agency_acc=4)  
SetVar(company_acc=5)  

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, LangJS(money_transfer)))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(LangJS(recipient_account_id))
                            Divs(input-group)
                                Select(RecipientAccountID, #state_id#_accounts.id, "form-control m-b",#vRecipientAccID#)
                                Divs(input-group-btn)
                                    BtnPage(tokens_money_transfer_company, Em(fa fa-search), "vSenderAccID:Val(SenderAccountID),vRecipientAccID:Val(RecipientAccountID),vS:0,vR:1",  btn btn-default ml4)
                                DivsEnd:
                            DivsEnd:
                            If(#vR#==1)
                                GetRow("acc", #state_id#_accounts, "id", #vRecipientAccID#)
                                GetRow("citizen", #state_id#_citizens, "id", #acc_citizen_id#)
                                Div(text-normal, <br>)
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(balance))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, Money(#acc_amount#))
                                    DivsEnd:
                                DivsEnd:
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(account_type))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, StateVal(tokens_accounts_type,#acc_type#))
                                    DivsEnd:
                                DivsEnd:

                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(status))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, If(#acc_onhold#==0,"active","onHold"))
                                    DivsEnd:
                                DivsEnd:

                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                                    Div(h5 text-normal, LangJS(citizen_word))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                                    Div(h5 text-normal, Image(If(GetVar(citizen_avatar)!=="", #citizen_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),   #citizen_name#)
                                    DivsEnd:
                                DivsEnd:
                            IfEnd:
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(amount))
                            Input(Amount, "form-control  m-b ",text,text,12.50)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs:clearfix 
                        Divs: pull-left
                        DivsEnd:
                        Divs: pull-right
                            TxButton{ClassBtn:btn btn-primary, Contract:tokens_Money_Transfer_extra,Name:"Send", Inputs:"SenderAccountType#=company_acc,RecipientAccountID=RecipientAccountID,Amount=Amount",OnSuccess: "template,tokens_accounts_list"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:  
            DivsEnd:

        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_tokens_money_transfer_company #= ContractConditions("MainCondition")`,
`p_tokens_money_transfer_person #= Title:LangJS(money_transfer)
Navigation(LangJS(money_transfer))

SetVar(person_acc=3)
SetVar(agency_acc=4)  
SetVar(company_acc=5)  

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, LangJS(money_transfer)))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label(LangJS(recipient_account_id))
                            Divs(input-group)
                                Select(RecipientAccountID, #state_id#_accounts.id, "form-control m-b",#vRecipientAccID#)
                                Divs(input-group-btn)
                                    BtnPage(tokens_money_transfer_person, Em(fa fa-search), "vSenderAccID:Val(SenderAccountID),vRecipientAccID:Val(RecipientAccountID),vS:0,vR:1",  btn btn-default ml4)
                                DivsEnd:
                            DivsEnd:
                            If(#vR#==1)
                                GetRow("acc", #state_id#_accounts, "id", #vRecipientAccID#)
                                GetRow("citizen", #state_id#_citizens, "id", #acc_citizen_id#)
                                Div(text-normal, <br>)
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(balance))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, Money(#acc_amount#))
                                    DivsEnd:
                                DivsEnd:
                                
                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(account_type))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, StateVal(tokens_accounts_type,#acc_type#))
                                    DivsEnd:
                                DivsEnd:

                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                         		    Div(h5 text-normal, LangJS(status))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                         		    Div(h5 text-normal, If(#acc_onhold#==0,"active","onHold"))
                                    DivsEnd:
                                DivsEnd:

                                Divs: row df f-valign
                            		Divs: col-md-6 mt-sm text-right
                                    Div(h5 text-normal, LangJS(citizen_word))
                                    DivsEnd:
                            		Divs: col-md-6 mt-sm text-left
                                    Div(h5 text-normal, Image(If(GetVar(citizen_avatar)!=="", #citizen_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),   #citizen_name#)
                                    DivsEnd:
                                DivsEnd:
                            IfEnd:
                        DivsEnd:
                        Divs(form-group)
                            Label(LangJS(amount))
                            Input(Amount, "form-control  m-b ",text,text,12.50)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs:clearfix 
                        Divs: pull-left
                        DivsEnd:
                        Divs: pull-right
                            TxButton{ClassBtn:btn btn-primary, Contract:tokens_Money_Transfer_extra,Name:"$send$", Inputs:"SenderAccountType#=person_acc,RecipientAccountID=RecipientAccountID,Amount=Amount",OnSuccess: "template,tokens_accounts_list"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:  
            DivsEnd:
            
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_tokens_money_transfer_person #= ContractConditions("MainCondition")`,
`p_voting_create #= Title: $NewVoting$
Navigation(LiTemplate(voting_list, $voting$), $NewVoting$)

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, $NewVoting$))
                Form()
                    Divs(list-group-item)
                        Divs(form-group)
                            Label("$name$")
                            Input(voting_name, "form-control  m-b ",Name,text, $NewVoting$)
                        DivsEnd: 
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label($voting_description$)
                            Textarea(description, form-control, " ")
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label($voting_voting_participants$)
                            Select(typeParticipants,type_voting_participants,form-control)
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label($voting_decision$)
                            Select(typeDecision,type_voting_decisions,form-control)
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label($voting_start$)
                            P(form-text text-muted, $voting_start_desc$)
                            Input(nowDate, "form-control hidden m-b  disabled=''",text,text,Now(YYYY/MM/DD MM:SS))
                            InputDate(startDate,form-control,Now(YYYY/MM/DD 00:00, 3 days))
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label($voting_end$)
                            P(form-text text-muted, $voting_end_desc$)
                            InputDate(endDate,form-control,Now(YYYY/MM/DD 00:00, 13 days))
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label($voting_volume$)
                            P(form-text text-muted, $voting_volume_desc$)
                            Input(volume,form-control, "", number, 75)
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label($voting_quorum$)
                            P(form-text text-muted, $voting_quorum_desc$)
                            Input(quorum,form-control, "", number, 50)
                        DivsEnd:
                    DivsEnd:
                FormEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        Divs: pull-right
                            BtnPage(voting_list, LangJS(back), "Status:1",btn btn-default btn-pill-left ml4)
                            TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract: votingCreateNew, Name: Create, OnSuccess: "template,voting_list"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
        DivsEnd:
        Divs: col-md-3 mt-sm text-left
        DivsEnd:
    DivsEnd:
DivsEnd:  
            

PageEnd:`,
`pc_voting_create #= ContractConditions("MainCondition")`,
`p_voting_decision_candidates #= Title: $voting_decision$

If(GetVar(vID))
    ValueById(#state_id#_voting_instances, #vID#, "name,typedecision,typeparticipants,optional_role_id,optional_role_vacancies", "votingName,typeDecision,typeParticipants,roleID,roleVacancies")
    
    Navigation(LiTemplate(voting_list, Voting), LiTemplate(voting_view, GetVar(votingName), "vID:#vID#"), Subject)
    
    Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-2 mt-sm text-left 
        DivsEnd:
		Divs: col-md-8 mt-sm text-left
		
            Divs(md-8, panel panel-primary data-sweet-alert)
                Form()
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(LangJS(role_name))
                            P(form-text text-muted, Select a role for voting)
                            Divs(input-group)
                                Select(roleID, #state_id#_roles_list.role_name, "form-control m-b", #roleID#)
                                Divs(input-group-btn)
                                    TxButton{ClassBtn:btn btn-primary, Contract:votingSubjectRole, Name:"Change", OnSuccess: "template,voting_view,vID:Val(votingID)"}
                                DivsEnd:
                            DivsEnd:
                            Input(votingID, "form-control  m-b hidden disabled=''",text,text,#vID#)
                        DivsEnd:
                    DivsEnd: 
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(Vacancies)
                            P(form-text text-muted, Number of vacancies for roles)
                            Divs(input-group)
                                Input(Vacancies,form-control, "", number, #roleVacancies#)
                                Divs(input-group-btn)
                                    TxButton{ClassBtn:btn btn-primary, Contract:votingSubjectVacancies, Name:"Change", OnSuccess: "template,voting_view,vID:Val(votingID)"}
                                DivsEnd:
                            DivsEnd:
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(Candidates)
                            Divs: row df f-valign
                        		Divs: col-md-6 mt-sm text-left
                        		    P(form-text text-muted, You can apply for voting)
                                DivsEnd:
                        		Divs: col-md-6 mt-sm text-right
                        		    TxButton{ClassBtn:btn btn-primary, Contract:votingSubjectApply, Name:"Apply for voting", OnSuccess: "template,voting_decision_candidates,vID:Val(votingID)"}
                        		DivsEnd:
                        	DivsEnd:
                        	Div(, <br>)
                            P(form-text text-muted, List of all candidates who are already voting)
                            Divs(table-responsive)
                                Table 
                                {
                                	Table: #state_id#_voting_subject
                                	Class: table-striped table-hover
                                	Order: id
                                	Where: "voting_id = '#vID#'"
                    				Columns: [
                    				    [ID, Div(text-center, #id#), text-center h5 align="center" width="50"],
                    				    [ Member, GetRow("member", #state_id#_citizens, "id", #member_id#) Div(text-bold,Image(If(GetVar(member_avatar)!=="", #member_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30),   #member_name#), h5],
                    				    [Member ID, Div(text-center, Address(#member_id#)), text-center h5 align="center"]
                    				]
                    			}
                    		DivsEnd:
                        DivsEnd:
                    DivsEnd:
                FormEnd:
                Divs(panel-footer)
                    Divs:clearfix 
                        Divs: pull-left
                        DivsEnd:
                        Divs: pull-right
                            BtnPage(voting_view, Back, "vID:#vID#",  btn btn-default)
                        DivsEnd:
                    DivsEnd:
                DivsEnd: 
            DivsEnd:
            
        DivsEnd:
        Divs: col-md-2 mt-sm text-left
        DivsEnd:
    DivsEnd:
    DivsEnd:
    
Else:
    Navigation(LiTemplate(voting_list, Voting), Subject)
    Divs: md-12
        Divs: alert alert-danger
            Strong("", $voting_error$)
            Div("", $voting_error_not_exists$)
        DivsEnd:
    DivsEnd:
IfEnd:

PageEnd:`,
`pc_voting_decision_candidates #= ContractConditions("MainCondition")`,
`p_voting_decision_document #= Title: $voting_decision$

If(GetVar(vID))
    ValueById(#state_id#_voting_instances, #vID#, "name,typedecision,typeparticipants,optional_role_id,optional_role_vacancies", "votingName,typeDecision,typeParticipants,roleID,roleVacancies")
    
    Navigation(LiTemplate(voting_list, Voting), LiTemplate(voting_view, GetVar(votingName), "vID:#vID#"), Subject)
    
    Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-2 mt-sm text-left 
        DivsEnd:
		Divs: col-md-8 mt-sm text-left
    
            Divs(md-8, panel panel-primary data-sweet-alert)
                Form()
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(Text of the document)
                            GetRow("doc", #state_id#_voting_subject, "voting_id", #vID#)
                            If(#doc_id#>0)
                                Source(text_document, #doc_text_document#)
                            Else:
                                Source(text_document)
                            IfEnd:
                            Input(votingID, "form-control  m-b hidden disabled=''",text,text,#vID#)
                        DivsEnd:
                    DivsEnd:
                FormEnd:
                Divs(panel-footer)
                    Divs:clearfix 
                        Divs: pull-left
                        DivsEnd:
                        Divs: pull-right
                            BtnPage(voting_view, Back, "vID:#vID#",  btn btn-default btn-pill-left)
                            TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract: votingSubjectDocument, Name:Save, OnSuccess: "template,voting_view,vID:#vID#"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd: 
            DivsEnd:
            
        DivsEnd:
        Divs: col-md-2 mt-sm text-left
        DivsEnd:
    DivsEnd:
    DivsEnd:
    
Else:
    Navigation(LiTemplate(voting_list, $voting$), $voting_decision$)
    Divs: md-12
        Divs: alert alert-danger
            Strong("", $voting_error$)
            Div("", $voting_error_not_exists$)
        DivsEnd:
    DivsEnd:
IfEnd:

PageEnd:`,
`pc_voting_decision_document #= ContractConditions("MainCondition")`,
`p_voting_decision_election #= Title: $voting_decision$

If(GetVar(vID))
    ValueById(#state_id#_voting_instances, #vID#, "name,typedecision,typeparticipants,optional_role_id,optional_role_vacancies", "votingName,typeDecision,typeParticipants,roleID,roleVacancies")
    
    Navigation(LiTemplate(voting_list, Voting), LiTemplate(voting_view, GetVar(votingName), "vID:#vID#"), Subject)
    
    Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-2 mt-sm text-left 
        DivsEnd:
		Divs: col-md-8 mt-sm text-left
		
            Divs(md-8, panel panel-primary data-sweet-alert)
                Form()
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(LangJS(role_name))
                            P(form-text text-muted, Select a role for voting)
                            Divs(input-group)
                                Select(roleID, #state_id#_roles_list.role_name, "form-control m-b", #roleID#)
                                Divs(input-group-btn)
                                    TxButton{ClassBtn:btn btn-primary, Contract:votingSubjectRole, Name:"Change", OnSuccess: "template,voting_view,vID:Val(votingID)"}
                                DivsEnd:
                            DivsEnd:
                            Input(votingID, "form-control  m-b hidden disabled=''",text,text,#vID#)
                        DivsEnd:
                    DivsEnd: 
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(Vacancies)
                            P(form-text text-muted, Number of vacancies for roles)
                            Divs(input-group)
                                Input(Vacancies,form-control, "", number, #roleVacancies#)
                                Divs(input-group-btn)
                                    TxButton{ClassBtn:btn btn-primary, Contract:votingSubjectVacancies, Name:"Change", OnSuccess: "template,voting_view,vID:Val(votingID)"}
                                DivsEnd:
                            DivsEnd:
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(Candidates)
                    		P(form-text text-muted, Select candidates to add)
                            Divs(input-group)
                                Select(memberID, #state_id#_citizens.name, "form-control m-b", #vMemberID#)
                                Divs(input-group-btn)
                                    TxButton{ClassBtn:btn btn-primary, Contract:votingSubjectCandidates, Name:"Add new", OnSuccess: "template,voting_decision_election,vID:Val(votingID)"}
                                DivsEnd:
                            DivsEnd:
                            Div(, <br>)
                            P(form-text text-muted, List of all candidates who are already voting)
                            Divs(table-responsive)
                                Table 
                                {
                                	Table: #state_id#_voting_subject
                                	Class: table-striped table-hover
                                	Order: id
                                	Where: "voting_id = '#vID#'"
                    				Columns: [
                    				    [ID, Div(text-center, #id#), text-center h5 align="center" width="50"],
                    				    [ Member, GetRow("member", #state_id#_citizens, "id", #member_id#) Div(text-bold,Image(If(GetVar(member_avatar)!=="", #member_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30),   #member_name#), h5],
                    				    [Member ID, Div(text-center, Address(#member_id#)), text-center h5 align="center"]
                    				]
                    			}
                    		DivsEnd:
                        DivsEnd:
                    DivsEnd:
                FormEnd:
                Divs(panel-footer)
                    Divs:clearfix 
                        Divs: pull-left
                        DivsEnd:
                        Divs: pull-right
                            BtnPage(voting_view, Back, "vID:#vID#",  btn btn-default)   
                        DivsEnd:
                    DivsEnd:
                DivsEnd: 
            DivsEnd:
            
        DivsEnd:
        Divs: col-md-2 mt-sm text-left
        DivsEnd:
    DivsEnd:
    DivsEnd:
    
Else:
    Navigation(LiTemplate(voting_list, Voting), Subject)
    Divs: md-12
        Divs: alert alert-danger
            Strong("", $voting_error$)
            Div("", $voting_error_not_exists$)
        DivsEnd:
    DivsEnd:
IfEnd:

PageEnd:`,
`pc_voting_decision_election #= ContractConditions("MainCondition")`,
`p_voting_decision_formal #= Title: $voting_decision$

If(GetVar(vID))
    ValueById(#state_id#_voting_instances, #vID#, "name,typedecision,typeparticipants,optional_role_id,optional_role_vacancies", "votingName,typeDecision,typeParticipants,roleID,roleVacancies")
    
    Navigation(LiTemplate(voting_list, Voting), LiTemplate(voting_view, GetVar(votingName), "vID:#vID#"), Subject)

    Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-2 mt-sm text-left 
        DivsEnd:
		Divs: col-md-8 mt-sm text-left
		
            Divs(md-8, panel panel-primary data-sweet-alert)
                
                GetRow("des", #state_id#_voting_subject, "voting_id", #vID#)
                If(#des_id#>0)
                    SetVar(vDescription = #des_formal_decision_description#)
                    SetVar(vTable = #des_formal_decision_table#)
                    SetVar(vTableId = #des_formal_decision_tableid#)
                    SetVar(vColumn = #des_formal_decision_column#)
                    SetVar(vColValue = #des_formal_decision_colvalue#)
                Else:
                    SetVar(vDescription = "no")
                    SetVar(vTable = "")
                    SetVar(vTableId = "")
                    SetVar(vColumn = "")
                    SetVar(vColValue = "")
                IfEnd:

                Form()
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(Description)
                            P(form-text text-muted, Text description of the subject of voting)
                            Textarea(decisionDescription, form-control, GetVar(vDescription))
                            Input(votingID, "form-control  m-b hidden disabled=''",text,text,#vID#)
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(Table name)
                            P(form-text text-muted, Table to which will be added voting decision)
                            Input(decisionTable, form-control, "", text, GetVar(vTable))
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(Table ID)
                            P(form-text text-muted, Row ID to which will be added voting decision)
                            Input(decisionId, form-control, "", number, GetVar(vTableId))
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(Column name)
                            P(form-text text-muted, Column to which will be added voting decision)
                            Input(decisionColumn, form-control, "", text, GetVar(vColumn))
                        DivsEnd:
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label(Voting decision)
                            P(form-text text-muted, Value of the voting decision)
                            Input(decisionValue,form-control, "", text, GetVar(vColValue))
                        DivsEnd:
                    DivsEnd:
                FormEnd:
                Divs(panel-footer)
                    Divs:clearfix 
                        Divs: pull-left
                        DivsEnd:
                        Divs: pull-right
                            BtnPage(voting_view, Back, "vID:#vID#",  btn btn-default btn-pill-left)
                            TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract: votingSubjectFormal, Name:Save, OnSuccess: "template,voting_view,vID:#vID#"}
                        DivsEnd:
                    DivsEnd:
                DivsEnd: 
            DivsEnd:
            
        DivsEnd:
        Divs: col-md-2 mt-sm text-left
        DivsEnd:
    DivsEnd:
    DivsEnd:
    
Else:
    Navigation(LiTemplate(voting_list, $voting$), $voting_decision$)
    Divs: md-12
        Divs: alert alert-danger
            Strong("", $voting_error$)
            Div("", $voting_error_not_exists$)
        DivsEnd:
    DivsEnd:
IfEnd:

PageEnd:`,
`pc_voting_decision_formal #= ContractConditions("MainCondition")`,
`p_voting_invite #= Title: $voting_invite$

If(GetVar(vID))
    ValueById(#state_id#_voting_instances, #vID#, "name,typedecision,typeparticipants,optional_role_id,optional_role_vacancies", "votingName,typeDecision,typeParticipants,roleID,roleVacancies")
    
    Navigation(LiTemplate(voting_list, Voting), LiTemplate(voting_view, GetVar(votingName), "vID:#vID#"), Participants)
    
    Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-2 mt-sm text-left 
        DivsEnd:
		Divs: col-md-8 mt-sm text-left
            Divs(md-8, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, Voting participants))
                Form()
                    Divs(list-group-item)
                        Divs(form-group)

                            Divs(table-responsive)
                                Table 
                                {
                                	Table: #state_id#_voting_participants
                                	Class: table-striped table-hover
                                	Order: id
                                	Where: voting_id=#vID#
                                	Columns: [
                                	    [ID, Div(text-center, #id#), text-center h4 align="center" width="50" ],
                                		[Member, Div("text-left",GetRow("citizens", #state_id#_citizens, "id", GetVar(member_id)) Div("",Image(If(GetVar(citizens_avatar)!=="",#citizens_avatar#,"/static/img/avatar.svg"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),    #citizens_name#)), h4],
                                	    [, If(Or(#typeDecision#==1,#typeDecision#==2), If(#decision#==0, Div(text-muted h6, "Did not vote"), Div(text-success h6, Vote for the candidate GetOne(name, #state_id#_citizens#, "id",  #decision#)  at DateTime(#decision_date#, YYYY/MM/DD HH:MI))) ) If(#typeDecision#==3, If(#decision#==0, Div(text-muted h6, "Did not vote")) If(#decision#==1, Div(text-success h6, "Document accept at " DateTime(#decision_date#, YYYY/MM/DD HH:MI))) If(#decision#==-1, Div(text-danger h6, "Document reject at " DateTime(#decision_date#, YYYY/MM/DD HH:MI))))  If(#typeDecision#==4, If(#decision#==0, Div(text-muted h6, "Did not vote")) If(#decision#==1, Div(text-success h6, "Decision accept at " DateTime(#decision_date#, YYYY/MM/DD HH:MI))) If(#decision#==-1, Div(text-danger h6, "Decision reject at " DateTime(#decision_date#, YYYY/MM/DD HH:MI))))]
                                	]
                                }
                            DivsEnd: 
                            
                            Div(, <br>)
                            Input(votingID, "form-control  m-b hidden disabled=''",text,text,#vID#)
                            
                            If(#typeParticipants# == 1)
                                Input(varID, "form-control  m-b hidden disabled=''",text,text,0)
                            IfEnd:
                            If(#typeParticipants# == 2)
                                P(form-text text-muted, Select a member to add)
                                Divs(input-group)
                                    Select(varID, #state_id#_citizens.name, "form-control m-b", #vMemberID#)
                                    Divs(input-group-btn)
                                    If(#vS#==1)
                                        BtnPage(voting_invite, Em(fa fa-minus), "vMemberID:Val(varID),vID:#vID#,vS:0",  btn btn-default ml4)
                                    Else:
                                        BtnPage(voting_invite, Em(fa fa-question), "vMemberID:Val(varID),vID:#vID#,vS:1",  btn btn-default ml4)
                                    IfEnd:
                                    DivsEnd:
                                DivsEnd: 
                                If(#vS#==1)
                                    GetRow("citizen", #state_id#_citizens, "id", #vMemberID#)
                                    Div(text-normal, <br>)
                                    Divs: row df f-valign
                                		Divs: col-md-5 mt-sm text-right
                                        Div(h5 text-normal, "Member:")
                                        DivsEnd:
                                		Divs: col-md-7 mt-sm text-left
                                        Div(h5 text-normal, Image(If(GetVar(citizen_avatar)!=="", #citizen_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),   #citizen_name#)
                                        DivsEnd:
                                    DivsEnd:
                                    Divs: row df f-valign
                                		Divs: col-md-5 mt-sm text-right
                                        Div(h5 text-normal, LangJS(member_id))
                                        DivsEnd:
                                		Divs: col-md-7 mt-sm text-left
                                        Div(h5 text-normal, Address(#citizen_id#))
                                        DivsEnd:
                                    DivsEnd:
                                IfEnd:
                            IfEnd:
                            If(#typeParticipants# == 3)
                                P(form-text text-muted, Select a role to add all members of this role)
                                Select(varID, #state_id#_roles_list.role_name, "form-control m-b")
                            IfEnd:
                            
                        DivsEnd:
                    DivsEnd:
                FormEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        If(#typeParticipants# == 1)
                            Divs: pull-right
                                BtnPage(voting_view, Back, "vID:#vID#",  btn btn-default)
                            DivsEnd:
                        IfEnd:
                        If(#typeParticipants# == 2)
                            Divs: pull-right
                                BtnPage(voting_view, Back, "vID:#vID#",  btn btn-default btn-pill-left)
                                TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:votingInvite, Name:"Add member", OnSuccess: "template,voting_invite,vID:Val(votingID)"}  
                            DivsEnd:
                        IfEnd:
                        If(#typeParticipants# == 3)
                            Divs: pull-right
                                BtnPage(voting_view, Back, "vID:#vID#",  btn btn-default btn-pill-left)
                                TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:votingInvite, Name:"Add role", OnSuccess: "template,voting_invite,vID:Val(votingID)"}  
                            DivsEnd:
                        IfEnd:
                    DivsEnd:
                DivsEnd:
            DivsEnd:
            
        DivsEnd:
        Divs: col-md-2 mt-sm text-left
        DivsEnd:
    DivsEnd:
    DivsEnd:
    
Else:
    Navigation(LiTemplate(voting_list, Voting), $voting_invite$)
    Divs: md-12
        Divs: alert alert-danger
            Strong("", $voting_error$)
            Div("", $voting_error_not_exists$)
        DivsEnd:
    DivsEnd:
IfEnd:

PageEnd:`,
`pc_voting_invite #= ContractConditions("MainCondition")`,
`p_voting_list #= Title: $voting$
Navigation($voting$)

AutoUpdate(2)
Include(notification)
AutoUpdateEnd:

If(#isSearch#==1)
    SetVar(vWhere="name = '#StrSearch#' and delete = 0")
Else:
    SetVar(vWhere="delete = 0")
IfEnd:

Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, "$voting$"))
    Divs(panel-body)
        Divs: row df f-valign
			Divs: col-md-1 mt-sm text-right
			    Div(text-bold, "$name$:")
            DivsEnd:
			Divs: col-md-10 mt-sm text-left
                Input(StrSearch, "form-control  m-b")
            DivsEnd:
            Divs: col-md-1 mt-sm
                TxButton { Contract:votingSearch, Name: $search$, OnSuccess: "template,voting_list,StrSearch:Val(StrSearch),isSearch:1" }
            DivsEnd:
        DivsEnd:
        Div(text-bold, <br>)
        Divs(table-responsive)
            Table {
            	Table: #state_id#_voting_instances
            	Class: table-striped table-bordered table-hover data-role="table"
            	Order: id
            	Where: #vWhere#
            	Columns: [
            	    [ID, Div(text-center, #id#) Div(, SetVar(vDateNow=Now(YYYY/MM/DD HH:MI)) SetVar(vStartDate=DateTime(#startdate#, YYYY/MM/DD HH:MI)) SetVar(vEndDate=DateTime(#enddate#, YYYY/MM/DD HH:MI)) SetVar(vCmpStartDate=CmpTime(#vStartDate#,#vDateNow#)) SetVar(vCmpEndDate=CmpTime(#vEndDate#,#vDateNow#) ) ), text-center h5 align="center" width="50" ],
            		[$name$, Div(text-bold, LinkPage(voting_view, #name#, "vID:#id#",pointer) ), h5],
            		[$subject_of_voting$,  If(#vCmpStartDate#<0, StateVal("type_voting_decisions",#typedecision#), If(#typedecision#==1,LinkPage(voting_decision_candidates,StateVal("type_voting_decisions",#typedecision#),"vID:#id#",pointer)) If(#typedecision#==2,LinkPage(voting_decision_election,StateVal("type_voting_decisions",#typedecision#),"vID:#id#",pointer)) If(#typedecision#==3,LinkPage(voting_decision_document,StateVal("type_voting_decisions",#typedecision#),"vID:#id#",pointer)) If(#typedecision#==4,LinkPage(voting_decision_formal,StateVal("type_voting_decisions",#typedecision#),"vID:#id#",pointer)) ), text-center align="center" h5 width="220"],
                    [$participants$, Div(text-center, If(#vCmpStartDate#<0, StateVal("type_voting_participants", #typeparticipants#), LinkPage(voting_invite, StateVal("type_voting_participants", #typeparticipants#), "vID:#id#",pointer) ) ), text-center h5 align="center" width="70"],
            		[$notifics$,  Div(text-center, If(#flag_notifics#==1, Div(text-center, "yes"), If(And(#flag_success#!=1,#vCmpEndDate#>0,#vCmpStartDate#<0,#creator_id#==#citizen#), BtnContract(votingSendNotifics,LangJS(send), Do you want to send a notification to all the voters?,"votingID:'#id#'",'btn btn-primary',template,voting_list), Div(text-center, "no") ) ) ), text-center h5 align="center" width="70"],
            		[$creator$, Div("text-left",GetRow("citizens", #state_id#_citizens, "id", GetVar(creator_id)) Div("",Image(If(GetVar(citizens_avatar)!=="",#citizens_avatar#,"/static/img/avatar.svg"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),    #citizens_name#)), text-center h5 align="center"],
            		[$start_end_date$, If(#vCmpStartDate#<0, Div(text-muted text-center, DateTime(#startdate#, DD.MM.YYYY HH:MI) ), Div(text-bold text-center, DateTime(#startdate#, DD.MM.YYYY HH:MI) ) ) If(#vCmpEndDate#<0, Div(text-muted text-center, DateTime(#enddate#, DD.MM.YYYY HH:MI)), Div(text-bold text-center, DateTime(#enddate#, DD.MM.YYYY HH:MI))), text-center h5 align="center" width="125"],
            		[$success$, Div(text-center text-bold, #percent_success#  %), text-center h5 align="center" width="70"],
            		[$decision$, Div(text-center text-bold, If(#flag_decision#==0, If(And(#vCmpEndDate#<0,#creator_id#==#citizen#), BtnContract(votingCheckDecision,Decision, Do you want to check decision?,"votingID:'#id#'",'btn btn-primary',template,voting_list), Div(text-muted,"no")) ) If(#flag_decision#==-2, Div(text-muted,"not enough votes") ) If(#flag_decision#==1, Div(text-success,"accepted") ), If(#flag_decision#==-1, Div(text-danger,"rejected") ) ), text-center h5 align="center" width="90"],
            		[$status$,  Div(text-center text-bold, If(#flag_success#==1, Div(text-success,"success"),  If(#vCmpEndDate#<0, Div(text-muted, "finished"), If(#vCmpStartDate#<0, BtnPage(voting_view, LangJS(go), "vID:#id#",  btn btn-primary), Div(text-warning,"waiting") ) ) ) ), text-center h5 align="center" width="70"],
            		[ , BtnContract(votingDelete, Em(fa fa-close),$do_you_want_to_delete_this_voting?$,"votingID:#id#",'btn btn-danger',template,voting_list), text-center align="center" width="60" ]
            	]
            }
        DivsEnd:
        If(#isSearch#==1)
            Div(h4 m0 text-bold text-left, <br>)
            Divs(text-center)
                    BtnPage(voting_list, <b>$view_all$</b>,"isSearch:0",btn btn-primary btn-oval)
            DivsEnd:
        IfEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs:clearfix 
            Divs: pull-left
            DivsEnd:
            Divs: pull-right
                BtnPage(voting_create, $add_voting$, "",  btn btn-primary)
            DivsEnd:
        DivsEnd:
    DivsEnd:    
DivsEnd:

PageEnd:`,
`pc_voting_list #= ContractConditions("MainCondition")`,
`p_voting_view #= Title: Voting

SetVar(type_str1="single")
If(#vType#==#type_str1#)
     SetVar(vID = #vPageValue#)
IfEnd:

AutoUpdate(2)
Include(notification)
AutoUpdateEnd:

If(GetVar(vID))
    ValueById(#state_id#_voting_instances, #vID#, "name,typedecision,typeparticipants,optional_role_id,optional_role_vacancies,volume,quorum,startdate,enddate,number_participants,optional_number_cands,number_voters,percent_voters,percent_success,flag_success,flag_decision,flag_fulldata,flag_notifics", "votingName,typeDecision,typeParticipants,roleID,roleVacancies,volume,quorum,startdate,enddate,number_participants,optional_number_cands,number_voters,percent_voters,percent_success,flag_success,flag_decision,flag_fulldata,flag_notifics")
    
    Navigation(LiTemplate(voting_list, Voting), GetVar(votingName))
    
    
    SetVar(vDateNow=Now(YYYY/MM/DD HH:MI)) 
    SetVar(vStartDate=DateTime(#startdate#, YYYY/MM/DD HH:MI)) 
    SetVar(vEndDate=DateTime(#enddate#, YYYY/MM/DD HH:MI)) 
    SetVar(vCmpStartDate=CmpTime(#vStartDate#,#vDateNow#)) 
    SetVar(vCmpEndDate=CmpTime(#vEndDate#,#vDateNow#) )    
    

    SetVar(isParticipant = GetOne(id, #state_id#_voting_participants#, "voting_id=#vID# and member_id=#citizen# and decision=0") )
    If(And(#flag_fulldata#==1,Or(#isParticipant#>0,#isParticipant#<0),#flag_decision#==0,#vCmpStartDate#<0,#vCmpEndDate#>0))
        SetVar(vOpportunityVote = 1)
    Else:
        SetVar(vOpportunityVote = 0)
    IfEnd:
    
    
    Divs:content-wrapper 
    Divs: row
		Divs: col-md-2 mt-sm text-left 
        DivsEnd:
		Divs: col-md-8 mt-sm text-left
            Divs(md-8, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title,  Voting )  )

                Form()
                
                    Divs(list-group-item)
                        Divs: text-center
                            P(h6, "")
                            P(h2 text-bold, #votingName#)
                            P(h4 text-muted, StateVal("type_voting_decisions",#typeDecision#))
                            P(h6, "")
                        DivsEnd:
                        Divs: row df f-valign
                    		Divs: col-md-6 mt-sm text-right
                 		        Div(h4 text-normal, "Filled:")
                            DivsEnd:
                    		Divs: col-md-6 mt-sm text-left
                 		        If(#flag_fulldata#==1, Div(h4 text-success,"yes"), Div(h4 text-danger,"no") )
                            DivsEnd:
                        DivsEnd:
                        If(Or(#typeDecision#==1,#typeDecision#==2))
                            Divs: row df f-valign
                        		Divs: col-md-6 mt-sm text-right
                     		        Div(h4 text-normal, LangJS(role_name))
                                DivsEnd:
                        		Divs: col-md-6 mt-sm text-left
                     		        Div(h4 text-normal, If(#roleID#>0, GetOne(role_name, #state_id#_roles_list#, "id=#roleID#"), "[no]") )
                                DivsEnd:
                            DivsEnd:
                            Divs: row df f-valign
                        		Divs: col-md-6 mt-sm text-right
                     		        Div(h4 text-normal, "Vacancies:")
                                DivsEnd:
                        		Divs: col-md-6 mt-sm text-left
                     		        Div(h4 text-normal, If(#roleVacancies#>0,#roleVacancies#,"[no]"))
                                DivsEnd:
                            DivsEnd:
                            Divs: row df f-valign
                        		Divs: col-md-6 mt-sm text-right
                     		        Div(h4 text-normal, "Candidates:")
                                DivsEnd:
                        		Divs: col-md-6 mt-sm text-left
                     		        Div(h4 text-normal, #optional_number_cands#)
                                DivsEnd:
                            DivsEnd:
                            Divs: row
                        		Divs: col-md-2 mt-sm text-right
                                DivsEnd:
                        		Divs: col-md-8 mt-sm text-left
                                    Divs(form-group)
                                    Divs(table-responsive)
                                    Table 
                                    {
                                	Table: #state_id#_voting_subject
                                	Class: table-striped table-hover
                                	Order: id
                                	Where: voting_id=#vID#
                                	Columns: 
                                	[
                            		[, Div("text-left",GetRow("citizens", #state_id#_citizens, "id", GetVar(member_id)) Div("",Image(If(GetVar(citizens_avatar)!=="",#citizens_avatar#,"/static/img/avatar.svg"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),   #citizens_name#)), h4],
                            		[,If(#vOpportunityVote#==1, BtnContract(votingAcceptCandidates, "Vote", Are you sure you want to vote for this candidate?,"votingID:#vID#,candidateID:'#member_id#',flag_notifics:#flag_notifics#,'btn btn-success',template,voting_view, "vID:#vID#") ), width="80"]
                                	]
                                    }
                                    DivsEnd: 
                                    DivsEnd:
                                DivsEnd:
                        		Divs: col-md-2 mt-sm text-right
                                DivsEnd:
                            DivsEnd:
                            Divs: row df f-valign
                        		Divs: col-md-12 mt-sm text-right
                        		     If(#vCmpStartDate#>0)
                            		     If(#typeDecision#==1)
                         		            Div(text-center, LinkPage(voting_decision_candidates, Edit subject of voting, "vID:'#vID#'",pointer) ) 
                         		         IfEnd:
                            		     If(#typeDecision#==2)
                         		            Div(text-center, LinkPage(voting_decision_election, Edit subject of voting, "vID:'#vID#'",pointer) ) 
                         		         IfEnd:
                         		         P(h6, "<br>")
                     		         IfEnd:
                                DivsEnd:
                            DivsEnd:
                        IfEnd:
                        
                        
                        If(#typeDecision#==3)
                            Divs: row
                        		Divs: col-md-12 mt-sm text-left
                        		    Div(text-center,  Div(h4, "Hash:" Small(,GetOne(text_doc_hash, #state_id#_voting_subject#, "voting_id", #vID#) ) ) )
                                DivsEnd:
                            DivsEnd:
                            Divs: row
                        		Divs: col-md-1
                                DivsEnd:
                        		Divs: col-md-10 mt-sm text-left
                        		    GetOne(text_document, #state_id#_voting_subject#, "voting_id", #vID#)
                                DivsEnd:
                        		Divs: col-md-1
                                DivsEnd:
                            DivsEnd:
                            Divs: row
                        		Divs: col-md-12
                        		    P(h6, "<br>")
                        		    If(#vCmpStartDate#>0)
                        		        Div(text-center, LinkPage(voting_decision_document, Edit subject of voting, "vID:'#vID#'",pointer) )
                        		        P(h6, "<br>")
                        		    IfEnd:
                        		DivsEnd:
                        	DivsEnd:
                            Divs: row
                        		Divs: col-md-1
                                DivsEnd:
                        		Divs: col-md-10 mt-sm text-left
                        		    If(#vOpportunityVote#==1)
                                        Divs:clearfix
                                        Divs: pull-left
                                            BtnContract(votingRejectDocument, "Reject document", Are you sure you want to reject document?,"votingID:#vID#,flag_notifics:#flag_notifics#",'btn btn-danger',template,voting_view, "vID:#vID#")
                                        DivsEnd:
                                        Divs: pull-right
                                            BtnContract(votingAcceptDocument, "Accept document", Are you sure you want to accept document?,"votingID:#vID#,flag_notifics:#flag_notifics#",'btn btn-success',template,voting_view, "vID:#vID#")
                                        DivsEnd:
                                        DivsEnd:
                                        P(h6, "<br>")
                                    IfEnd:
                                DivsEnd:
                        		Divs: col-md-1
                                DivsEnd:
                            DivsEnd:
                        IfEnd:
                        
                        If(#typeDecision#==4)
                            Divs: row df f-valign
                        		Divs: col-md-1
                                DivsEnd:
                        		Divs: col-md-5 mt-sm text-right
                     		        Div(h4 text-normal, "Description:")
                                DivsEnd:
                        		Divs: col-md-5 mt-sm text-left
                        		    GetRow("des", #state_id#_voting_subject, "voting_id", #vID#)
                        		    If(#des_id#>0, Div(h4 text-normal, #des_formal_decision_description#), Div(h4 text-normal, [no]))
                                DivsEnd:
                        		Divs: col-md-1
                                DivsEnd:
                            DivsEnd:
                            Divs: row df f-valign
                        		Divs: col-md-1
                                DivsEnd:
                        		Divs: col-md-5 mt-sm text-right
                     		        Div(h4 text-normal, "Table:")
                                DivsEnd:
                        		Divs: col-md-5 mt-sm text-left
                     		        If(#des_id#>0, Div(h4 text-normal, #des_formal_decision_table#), Div(h4 text-normal, [no]))
                                DivsEnd:
                        		Divs: col-md-1
                                DivsEnd:
                            DivsEnd:
                            Divs: row df f-valign
                        		Divs: col-md-1
                                DivsEnd:
                        		Divs: col-md-5 mt-sm text-right
                     		        Div(h4 text-normal, "Table ID:")
                                DivsEnd:
                        		Divs: col-md-5 mt-sm text-left
                     		        If(#des_id#>0, Div(h4 text-normal, #des_formal_decision_tableid#), Div(h4 text-normal, [no]))
                                DivsEnd:
                        		Divs: col-md-1
                                DivsEnd:
                            DivsEnd:
                            Divs: row df f-valign
                        		Divs: col-md-1
                                DivsEnd:
                        		Divs: col-md-5 mt-sm text-right
                     		        Div(h4 text-normal, "Column name:")
                                DivsEnd:
                        		Divs: col-md-5 mt-sm text-left
                     		        If(#des_id#>0, Div(h4 text-normal, #des_formal_decision_column#), Div(h4 text-normal, [no]))
                                DivsEnd:
                        		Divs: col-md-1
                                DivsEnd:
                            DivsEnd:
                            Divs: row df f-valign
                        		Divs: col-md-1
                                DivsEnd:
                        		Divs: col-md-5 mt-sm text-right
                     		        Div(h4 text-normal, "Column value:")
                                DivsEnd:
                        		Divs: col-md-5 mt-sm text-left
                     		        If(#des_id#>0, Div(h4 text-normal, #des_formal_decision_colvalue#), Div(h4 text-normal, [no]))
                                DivsEnd:
                        		Divs: col-md-1
                                DivsEnd:
                            DivsEnd:
                            Divs: row df f-valign
                        		Divs: col-md-12
                        		    P(h6, "<br>")
                        		    If(#vCmpStartDate#>0)
                        		        Div(text-center, LinkPage(voting_decision_formal, Edit subject of voting, "vID:'#vID#'",pointer) )
                        		        P(h6, "<br>")
                        		    IfEnd:      
                        		DivsEnd:
                        	DivsEnd:
                            Divs: row df f-valign
                        		Divs: col-md-1
                                DivsEnd:
                        		Divs: col-md-10 mt-sm text-left
                        		    If(#vOpportunityVote#==1)
                                        Divs:clearfix
                                        Divs: pull-left
                                            BtnContract(votingRejectDecision, "Reject decision", Are you sure you want to reject decision?,"votingID:#vID#,flag_notifics:#flag_notifics#",'btn btn-danger',template,voting_view, "vID:#vID#")
                                        DivsEnd:
                                        Divs: pull-right
                                            BtnContract(votingAcceptDecision, "Accept decision", Are you sure you want to accept decision?,"votingID:#vID#,flag_notifics:#flag_notifics#",'btn btn-success',template,voting_view, "vID:#vID#")
                                        DivsEnd:
                                        DivsEnd:
                                        P(h6, "<br>")
                                    IfEnd:
                                DivsEnd:
                        		Divs: col-md-1
                                DivsEnd:
                            DivsEnd:
                        IfEnd: 
  
                    DivsEnd:
                
                    Divs(list-group-item)
                        Divs: row df f-valign
                    		Divs: col-md-6 mt-sm text-right
                 		        Div(h4 text-normal, "Status:")
                            DivsEnd:
                    		Divs: col-md-6 mt-sm text-left
                 		        If(#flag_success#==1, Div(h4 text-success,"success"),  If(#vCmpEndDate#<0, Div(h4 text-muted, "finished"), If(#vCmpStartDate#<0, Div(h4 text-success,"started"), Div(h4 text-warning,"waiting") ) ) )
                            DivsEnd:
                        DivsEnd:
                        Divs: row df f-valign
                    		Divs: col-md-6 mt-sm text-right
                 		        Div(h4 text-normal, "Start date:")
                            DivsEnd:
                    		Divs: col-md-6 mt-sm text-left
                 		        If(#vCmpStartDate#<0, Div(h4 text-muted, DateTime(#startdate#, DD.MM.YYYY HH:MI)), Div(h4 text-bold, DateTime(#startdate#, DD.MM.YYYY HH:MI)) )
                            DivsEnd:
                        DivsEnd:
                        Divs: row df f-valign
                    		Divs: col-md-6 mt-sm text-right
                 		        Div(h4 text-normal, "End date:")
                            DivsEnd:
                    		Divs: col-md-6 mt-sm text-left
                 		        If(#vCmpEndDate#<0, Div(h4 text-muted, DateTime(#enddate#, DD.MM.YYYY HH:MI)), Div(h4 text-bold, DateTime(#enddate#, DD.MM.YYYY HH:MI)) )
                            DivsEnd:
                        DivsEnd:
                        Divs: row df f-valign
                    		Divs: col-md-6 mt-sm text-right
                 		        Div(h4 text-normal, "Decision:")
                            DivsEnd:
                    		Divs: col-md-6 mt-sm text-left
                 		        Div(h4, If(#flag_decision#==-2, Div(text-muted,"not enough votes") ) If(#flag_decision#==0, Div(text-muted,"no")) If(#flag_decision#==1, Div(text-success,"accepted")) If(#flag_decision#==-1, Div(text-danger,"rejected")) )
                            DivsEnd:
                        DivsEnd:
                        Divs: row df f-valign
                    		Divs: col-md-6 mt-sm text-right
                 		        Div(h4 text-normal, "Volume:")
                            DivsEnd:
                    		Divs: col-md-6 mt-sm text-left
                 		        Div(h4 text-normal, #volume#)
                            DivsEnd:
                        DivsEnd:
                        Divs: row df f-valign
                    		Divs: col-md-6 mt-sm text-right
                 		        Div(h4 text-normal, "Quorum:")
                            DivsEnd:
                    		Divs: col-md-6 mt-sm text-left
                 		        Div(h4 text-normal, #quorum#)
                            DivsEnd:
                        DivsEnd:
                        Divs: row df f-valign
                    		Divs: col-md-6 mt-sm text-right
                 		        Div(h4 text-normal, "Notifications:")
                            DivsEnd:
                    		Divs: col-md-6 mt-sm text-left
                 		        If(#flag_notifics#==1, Div(h4 text-normal, "yes"), Div(h4 text-normal, "no") )
                            DivsEnd:
                        DivsEnd:
                        Divs: row df f-valign
                    		Divs: col-md-6 mt-sm text-right
                 		        Div(h4 text-normal, "Participants:")
                            DivsEnd:
                    		Divs: col-md-6 mt-sm text-left
                    		    Div(h4 text-normal, #number_participants#)
                            DivsEnd:
                        DivsEnd:

                        Divs: row
                    		Divs: col-md-2 mt-sm text-right
                            DivsEnd:
                    		Divs: col-md-8 mt-sm text-left
                                Divs(form-group)
                                    Divs(table-responsive)
                                        Table 
                                        {
                                        	Table: #state_id#_voting_participants
                                        	Class: table-striped table-hover
                                        	Order: id
                                        	Where: voting_id=#vID#
                                        	Columns: [
                                        		[, Div("text-left",GetRow("citizens", #state_id#_citizens, "id", GetVar(member_id)) Div("",Image(If(GetVar(citizens_avatar)!=="",#citizens_avatar#,"/static/img/avatar.svg"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30),   #citizens_name#)), h4],
                                        		[, If(Or(#typeDecision#==1,#typeDecision#==2), If(#decision#==0, Div(text-muted h6, "Did not vote"), Div(text-success h6, Vote for the candidate GetOne(name, #state_id#_citizens#, "id",  #decision#)  at DateTime(#decision_date#, YYYY/MM/DD HH:MI))) ) If(#typeDecision#==3, If(#decision#==0, Div(text-muted h6, "Did not vote")) If(#decision#==1, Div(text-success h6, "Document accept at " DateTime(#decision_date#, YYYY/MM/DD HH:MI))) If(#decision#==-1, Div(text-danger h6, "Document reject at " DateTime(#decision_date#, YYYY/MM/DD HH:MI))))  If(#typeDecision#==4, If(#decision#==0, Div(text-muted h6, "Did not vote")) If(#decision#==1, Div(text-success h6, "Decision accept at " DateTime(#decision_date#, YYYY/MM/DD HH:MI))) If(#decision#==-1, Div(text-danger h6, "Decision reject at " DateTime(#decision_date#, YYYY/MM/DD HH:MI))))]
                                        	]
                                        }
                                    DivsEnd:
                                DivsEnd:
                            DivsEnd:
                    		Divs: col-md-2 mt-sm text-right
                            DivsEnd:
                        DivsEnd:
                        
                        Divs: row
                    		Divs: col-md-12
                    		If(#vCmpStartDate#>0, Div(text-center, LinkPage(voting_invite, Add participants, "vID:'#vID#'",pointer) ) )
                    		    Div(h4 text-normal, "<br>")
                    		DivsEnd:
                    	DivsEnd:
                        
                        Divs: row
                    		Divs: col-md-1 mt-sm text-right
                            DivsEnd:
                    		Divs: col-md-5 mt-sm text-right
                                P(h3 text-center, Voted)
                                P(h6 text-center text-muted, Graph of the proportion of voters from the total number of participants)
                 		        Ring(#number_voters#, 32, #percent_voters#, 2, "5d9cec", "656565", 100)
                 		        Div(h4 text-normal, "<br>")
                            DivsEnd:
                    		Divs: col-md-5 mt-sm text-left
                    		    P(h3 text-center, Success)
                    		    P(h6 text-center text-muted, Graph of the percentages of votes needed to make a decision)
                 		        Ring(#percent_success#, 32, #percent_success#, 2, "5d9cec", "656565", 100)
                 		        Div(h4 text-normal, "<br>")
                            DivsEnd:
                    		Divs: col-md-1 mt-sm text-right
                            DivsEnd:
                        DivsEnd:
                        
                    DivsEnd:
                
                FormEnd:

            DivsEnd:
            
        DivsEnd:
        Divs: col-md-2 mt-sm text-left
        DivsEnd:
    DivsEnd:
    DivsEnd:
    
Else:
    Navigation(LiTemplate(voting_list, Voting), Subject)
    Divs: md-12
        Divs: alert alert-danger
            Strong("", $voting_error$)
            Div("", $voting_error_not_exists$)
        DivsEnd:
    DivsEnd:
IfEnd:

PageEnd:`,
`pc_voting_view #= ContractConditions("MainCondition")`)
TextHidden( p_AddLand, pc_AddLand, p_AddProperty, pc_AddProperty, p_Chat_history, pc_Chat_history, p_chat_IncomingRoleMessages, pc_chat_IncomingRoleMessages, p_CitizenInfo, pc_CitizenInfo, p_citizen_profile, pc_citizen_profile, p_dashboard_default, pc_dashboard_default, p_EditLand, pc_EditLand, p_EditProperty, pc_EditProperty, p_government, pc_government, p_LandHistory, pc_LandHistory, p_LandObject, pc_LandObject, p_LandObjectContract, pc_LandObjectContract, p_LandRegistry, pc_LandRegistry, p_MemberEdit, pc_MemberEdit, p_MemberManage, pc_MemberManage, p_members_list, pc_members_list, p_members_request_edit, pc_members_request_edit, p_MyChats, pc_MyChats, p_notification, pc_notification, p_notification_send_roles, pc_notification_send_roles, p_notification_send_single, pc_notification_send_single, p_notification_testpage, pc_notification_testpage, p_notification_view_roles, pc_notification_view_roles, p_notification_view_single, pc_notification_view_single, p_Property, pc_Property, p_PropertyDetails, pc_PropertyDetails, p_property_list, pc_property_list, p_roles_assign, pc_roles_assign, p_roles_create, pc_roles_create, p_roles_list, pc_roles_list, p_roles_view, pc_roles_view, p_tokens_accounts_add, pc_tokens_accounts_add, p_tokens_accounts_list, pc_tokens_accounts_list, p_tokens_create, pc_tokens_create, p_tokens_emission, pc_tokens_emission, p_tokens_list, pc_tokens_list, p_tokens_money_rollback, pc_tokens_money_rollback, p_tokens_money_transfer, pc_tokens_money_transfer, p_tokens_money_transfer_agency, pc_tokens_money_transfer_agency, p_tokens_money_transfer_company, pc_tokens_money_transfer_company, p_tokens_money_transfer_person, pc_tokens_money_transfer_person, p_voting_create, pc_voting_create, p_voting_decision_candidates, pc_voting_decision_candidates, p_voting_decision_document, pc_voting_decision_document, p_voting_decision_election, pc_voting_decision_election, p_voting_decision_formal, pc_voting_decision_formal, p_voting_invite, pc_voting_invite, p_voting_list, pc_voting_list, p_voting_view, pc_voting_view)
SetVar(`m_government #= MenuItem(Member dashboard, dashboard_default)
MenuItem(Ecosystem dashboard, government)
MenuGroup(Admin tools,admin)
MenuItem(Tables,sys-listOfTables)
MenuItem(Smart contracts, sys-contracts)
MenuItem(Interface, sys-interface)
MenuItem(App List, sys-app_catalog)
MenuItem(Export, sys-export_tpl)
MenuItem(Wallet,  sys-edit_wallet)
MenuItem(Languages, sys-languages)
MenuItem(Signatures, sys-signatures)
MenuEnd:
MenuBack(Welcome)`,
`mc_government #= ContractConditions("MainCondition")`,
`m_menu_default #= MenuItem(dashboard, dashboard_default,, "fa pull-left icon-home") 
MenuItem(profile, CitizenInfo, "", "fa pull-left icon-user")
MenuGroup(membersandroles,members_list,icon-user)
    MenuItem(members, members_list,, "fa pull-left icon-user")
    MenuItem(roles, roles_list,, "fa pull-left icon-list")
    MenuItem(singlenotifications, notification_view_single,, "fa pull-left icon-bell")
    MenuItem(rolenotifications, notification_view_roles,, "fa pull-left icon-bell")
    MenuItem(testpage, notification_testpage,, "fa pull-left icon-settings")
MenuEnd:
MenuGroup(systemtokens,tokens_accounts_list,icon-energy)
    MenuItem(accounts,  tokens_accounts_list,, "fa pull-left icon-wallet")
    MenuItem(tokens,  tokens_list,, "fa pull-left icon-energy")
    MenuItem(moneytransfer,  tokens_money_transfer_person,, "fa pull-left icon-action-redo")
    MenuItem(moneyrollback,  tokens_money_rollback,, "fa pull-left icon-trash")
MenuEnd:
MenuItem(voting, voting_list,, "fa pull-left icon-pin")
MenuItem(my_chats, MyChats,, "fa pull-left icon-bubble")
MenuItem(land_registry, LandRegistry,, "fa pull-left icon-globe")
MenuItem(property_registry, Property,, "fa pull-left fa-home")
MenuGroup(admin_tools,admin, icon-settings)
    MenuItem(tables,sys-listOfTables)
    MenuItem(smart_contracts, sys-contracts)
    MenuItem(interface, sys-interface)
    MenuItem(app_list, sys-app_catalog)
    MenuItem(export, sys-export_tpl)
    MenuItem(wallet,  sys-edit_wallet)
    MenuItem(languages, sys-languages)
    MenuItem(signatures, sys-signatures)
    MenuItem(gen_keys, sys-gen_keys)
    MenuItem(MemberManage, MemberManage)
MenuEnd:`,
`mc_menu_default #= ContractConditions("MainCondition")`)
TextHidden( m_government, mc_government, m_menu_default, mc_menu_default)
SetVar(`pa_buildings_use_class #= Shops, Financial and professional services, Restaurants and cafes, Business, Hotels, Dwellinghouses, Non-residential institutions, No`,
`pac_buildings_use_class #= ContractConditions("MainCondition")`,
`pa_changing_language #= ContractConditions(``MainCondition``)`,
`pac_changing_language #= ContractConditions("MainCondition")`,
`pa_changing_menu #= ContractConditions(``MainCondition``)`,
`pac_changing_menu #= ContractConditions("MainCondition")`,
`pa_changing_page #= ContractConditions(``MainCondition``)`,
`pac_changing_page #= ContractConditions("MainCondition")`,
`pa_changing_signature #= ContractConditions(``MainCondition``)`,
`pac_changing_signature #= ContractConditions("MainCondition")`,
`pa_changing_smart_contracts #= ContractConditions(``MainCondition``)`,
`pac_changing_smart_contracts #= ContractConditions("MainCondition")`,
`pa_changing_tables #= ContractConditions(``MainCondition``)`,
`pac_changing_tables #= ContractConditions("MainCondition")`,
`pa_citizenship_price #= 1000000`,
`pac_citizenship_price #= ContractConditions("MainCondition")`,
`pa_currency_name #= SZCG`,
`pac_currency_name #= ContractConditions("MainCondition")`,
`pa_dlt_spending #= -6226217056134548457`,
`pac_dlt_spending #= ContractConditions("MainCondition")`,
`pa_gender_list #= male,female`,
`pac_gender_list #= ContractConditions("MainCondition")`,
`pa_gov_account #= -6226217056134548457`,
`pac_gov_account #= ContractConditions("MainCondition")`,
`pa_land_use #= Agriculture, Forestry, Fishing, Mining and quarrying, Hunting, Energy production, Industry and manufacturing, Transport - communication networks - storage and protective works, Water and waste treatment, Construction, Commerce finance and business, Community services, Recreational - leisure - sport, Residential, Unused`,
`pac_land_use #= ContractConditions("MainCondition")`,
`pa_members_request_status #= $member$,$visitor$,$visitor_sr$`,
`pac_members_request_status #= ContractConditions("MainCondition")`,
`pa_money_digit #= 0`,
`pac_money_digit #= ContractConditions("MainCondition")`,
`pa_new_column #= ContractConditions(``MainCondition``)`,
`pac_new_column #= ContractConditions("MainCondition")`,
`pa_new_table #= ContractConditions(``MainCondition``)`,
`pac_new_table #= ContractConditions("MainCondition")`,
`pa_notification_ClosureType #= Single,Multiple`,
`pac_notification_ClosureType #= ContractConditions("MainCondition")`,
`pa_notification_icon #= fa-bell,fa-comment,fa-envelope,fa-bookmark,fa-check,fa-exclamation-triangle,fa-info-circle`,
`pac_notification_icon #= ContractConditions("MainCondition")`,
`pa_property_types #= $residential$,$commercial$,$land$`,
`pac_property_types #= ContractConditions("MainCondition")`,
`pa_restore_access_condition #= ContractConditions(``MainCondition``)`,
`pac_restore_access_condition #= ContractConditions("MainCondition")`,
`pa_roles_types #= Assigned,Elective`,
`pac_roles_types #= ContractConditions("MainCondition")`,
`pa_state_name #= 深圳市城管局`,
`pac_state_name #= ContractConditions("MainCondition")`,
`pa_tokens_accounts_type #= $sys_emission$,$sys_trash$,$person$,$agency$,$company$`,
`pac_tokens_accounts_type #= ContractConditions("MainCondition")`,
`pa_tokens_rollback_tokens #= $impossible$,$possible$`,
`pac_tokens_rollback_tokens #= ContractConditions("MainCondition")`,
`pa_tokens_type_emission #= $limited$,$unlimited$`,
`pac_tokens_type_emission #= ContractConditions("MainCondition")`,
`pa_tx_fiat_limit #= 10`,
`pac_tx_fiat_limit #= ContractConditions("MainCondition")`,
`pa_type_voting #= voting_type_candidate_manual,voting_type_candidate_requests,voting_type_document,voting_type_table`,
`pac_type_voting #= ContractConditions("MainCondition")`,
`pa_type_voting_decisions #= voting_decisions_candidate_requests,voting_decisions_candidate_manual,voting_decisions_document,voting_decisions_db`,
`pac_type_voting_decisions #= ContractConditions("MainCondition")`,
`pa_type_voting_participants #= voting_participants_everybody,voting_participants_manual,voting_participants_role`,
`pac_type_voting_participants #= ContractConditions("MainCondition")`)
TextHidden( pa_buildings_use_class, pac_buildings_use_class, pa_changing_language, pac_changing_language, pa_changing_menu, pac_changing_menu, pa_changing_page, pac_changing_page, pa_changing_signature, pac_changing_signature, pa_changing_smart_contracts, pac_changing_smart_contracts, pa_changing_tables, pac_changing_tables, pa_citizenship_price, pac_citizenship_price, pa_currency_name, pac_currency_name, pa_dlt_spending, pac_dlt_spending, pa_gender_list, pac_gender_list, pa_gov_account, pac_gov_account, pa_land_use, pac_land_use, pa_members_request_status, pac_members_request_status, pa_money_digit, pac_money_digit, pa_new_column, pac_new_column, pa_new_table, pac_new_table, pa_notification_ClosureType, pac_notification_ClosureType, pa_notification_icon, pac_notification_icon, pa_property_types, pac_property_types, pa_restore_access_condition, pac_restore_access_condition, pa_roles_types, pac_roles_types, pa_state_name, pac_state_name, pa_tokens_accounts_type, pac_tokens_accounts_type, pa_tokens_rollback_tokens, pac_tokens_rollback_tokens, pa_tokens_type_emission, pac_tokens_type_emission, pa_tx_fiat_limit, pac_tx_fiat_limit, pa_type_voting, pac_type_voting, pa_type_voting_decisions, pac_type_voting_decisions, pa_type_voting_participants, pac_type_voting_participants)
SetVar(`d_Export0_citizens #= contract Export0_citizens {
func action {
	var tblname, fields string
	tblname = Table("citizens")
	fields = "block_id,name_last,person_status,date_expiration,address,newaddress,public_key_0,avatar,name,birthday,sex,gender,date_end,date_start,newcoords,newbirthday,newsex,coords,test"
	DBInsert(tblname, fields, "0","万","1","NULL","","广东省深圳市宝安区海秀路","`#+:;?T?vH6??Ϝ)_[F|SS??????huiDId ?'1Ô {??F\7?????1??`","data:image/png;base64,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","麟","NULL","0","1","NULL","2017-11-28T04:50:16Z","{\"center_point\":[\"22.556080\",\"113.896294\"], \"zoom\":\"19\", \"cords\":[[\"22.555734\",\"113.895971\"],[\"22.555755\",\"113.895966\"],[\"22.555776\",\"113.896029\"],[\"22.555700\",\"113.896128\"],[\"22.555650\",\"113.896070\"]]}","1993/1/1","男","","")
	DBInsert(tblname, fields, "0","","1","NULL","","","","","","NULL","0","0","NULL","2017-11-28T02:35:45Z","","","","","")
	DBInsert(tblname, fields, "27484","深圳市城管局","1","NULL","","广东省深圳市福田区农园路22","","data:image/jpeg;base64,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","环卫科","NULL","0","1","NULL","2017-11-28T09:56:56Z","{\"center_point\":[\"22.546054\",\"114.025974\"], \"zoom\":\"15\", \"cords\":[[\"22.544919\",\"114.029854\"]]}","1983/08/21","男","","")
	}
}`,
`d_Export0_citizenship_requests #= contract Export0_citizenship_requests {
func action {
	var tblname, fields string
	tblname = Table("citizenship_requests")
	fields = "dlt_wallet_id,name,approved,block_id,public_key_0"
	DBInsert(tblname, fields, "-6226217056134548457","test","0","14849","")
	DBInsert(tblname, fields, "8069703358274709561","环卫科","1","26496","")
	}
}`,
`d_Export0_editing_land_registry #= contract Export0_editing_land_registry {
func action {
	var tblname, fields string
	tblname = Table("editing_land_registry")
	fields = "lend_object_id,person_id,old_attr_value,editing_attribute,date,person_name,new_attr_value"
	DBInsert(tblname, fields, "1","-6226217056134548457","1","land_use","2017-11-30T18:32:28Z","麟","3")
	DBInsert(tblname, fields, "1","-6226217056134548457","1","buildings_use_class","2017-11-30T18:33:10Z","麟","3")
	}
}`,
`d_Export0_land_ownership #= contract Export0_land_ownership {
func action {
	var tblname, fields string
	tblname = Table("land_ownership")
	fields = "owner_id,date_creat,owner_type,owner_new_id,price,date_signing,lend_object_id"
	DBInsert(tblname, fields, "-6226217056134548457","2017-11-28T06:23:37Z","0","-6226217056134548457","0","2017-11-28T06:23:37Z","1")
	DBInsert(tblname, fields, "8069703358274709561","2017-11-29T17:14:02Z","0","8069703358274709561","0","2017-11-29T17:14:02Z","2")
	}
}`,
`d_Export0_land_registry #= contract Export0_land_registry {
func action {
	var tblname, fields string
	tblname = Table("land_registry")
	fields = "value,land_registry_number,coords,area,date_last_edit,address,date_insert,buildings_use_class,land_use"
	DBInsert(tblname, fields, "0","0","{\"center_point\":[\"22.546054\",\"114.025974\"], \"zoom\":\"15\", \"cords\":[[\"22.545119\",\"114.026836\"]]}","1111","NULL","广东省深圳市福田区农轩路41号","2017-11-28T06:23:37Z","3","3")
	DBInsert(tblname, fields, "0","0","{\"center_point\":[\"30.672127\",\"111.120996\"], \"zoom\":\"19\", \"cords\":[[\"30.672092\",\"111.120794\"],[\"30.671801\",\"111.120623\"],[\"30.671859\",\"111.120960\"]]}","1157","NULL","湖北省宜昌市点军区","2017-11-29T17:14:02Z","1","1")
	}
}`,
`d_Export0_roles_assign #= contract Export0_roles_assign {
func action {
	var tblname, fields string
	tblname = Table("roles_assign")
	fields = "role_title,delete,date_end,role_name,date_start,appointed_by_id,appointed_by_name,member_id,member_name,role_id"
	DBInsert(tblname, fields, "","0","NULL","科长","2017-11-30T15:26:33Z","-6226217056134548457","麟","8069703358274709561","环卫科","1")
	}
}`,
`d_Export0_roles_list #= contract Export0_roles_list {
func action {
	var tblname, fields string
	tblname = Table("roles_list")
	fields = "date_create,date_delete,delete,role_name,creator_id,creator_name,role_type"
	DBInsert(tblname, fields, "2017-11-30T15:25:51Z","NULL","0","科长","-6226217056134548457","麟","1")
	}
}`)
TextHidden( d_Export0_citizens, d_Export0_citizenship_requests, d_Export0_editing_land_registry, d_Export0_land_ownership, d_Export0_land_registry, d_Export0_roles_assign, d_Export0_roles_list)
SetVar(`l_lang #= {" ResultSoon":"{\"en\": \" Result will be soon\", \"hk\": \"結果即將揭曉\", \"nl\": \" Result will be soon\", \"ru\": \"Результат будет скоро\", \"zh\": \"结果即将揭晓\"}","$date_end$":"{\"en\": \"Date end\", \"hk\": \"結束日期\", \"zh\": \"结束日期\"}","$voting_entry_number":"{\"en\": \"Poll #\", \"hk\": \"投票序號\", \"ru\": \"Poll #\", \"zh\": \"投票序号\"}","Actn":"{\"en\": \"Actions\", \"hk\": \"動作\", \"nl\": \"Acties\", \"ru\": \"Действия\", \"zh\": \"动作\"}","Actual":"{\"en\": \"Actual\", \"nl\": \"Actueel\", \"ru\": \"Текущие\"}","Anonym":"{\"en\": \"Anonymous\", \"hk\": \"匿名\", \"zh\": \"匿名\"}","Ans":"{\"en\": \"Answer\", \"hk\": \"答案\", \"nl\": \"Antwoord\", \"ru\": \"Ответить\", \"zh\": \"答案\"}","Apps":"{\"en\": \"Applications\", \"hk\": \"應用程式\", \"ru\": \"Приложения\", \"zh\": \"应用程序\"}","Cancel":"{\"en\": \"Cancel\", \"hk\": \"取消\", \"nl\": \"Annuleer\", \"ru\": \"Отменить\", \"zh\": \"取消\"}","Chng":"{\"en\": \"Change\", \"hk\": \"更改\", \"nl\": \"Wijzigen\", \"ru\": \"Изменить\", \"zh\": \"更改\"}","Confirm":"{\"en\": \"Confirm\", \"hk\": \"確認\", \"nl\": \"Bevestig\", \"ru\": \"Подтвердить\", \"zh\": \"确认\"}","Contin":"{\"en\": \"Continues\", \"nl\": \"Doorgaan\", \"ru\": \"Продолжаются\", \"zh\": \"继续\"}","Continues":"{\"en\": \"Continues\", \"hk\": \"繼續\", \"nl\": \"Doorgaan\", \"ru\": \"Продолжаются\", \"zh\": \"继续\"}","CreateNew":"{\"en\": \"Create new\", \"hk\": \"新建\", \"ru\": \"Создать новое\", \"zh\": \"新建\"}","DateFinishVoting":"{\"en\": \"Date Finish Voting\", \"hk\": \"投票結束日期\", \"nl\": \"Eind datum stem vraag\", \"ru\": \"Дата завершения голосования\", \"zh\": \"投票结束日期\"}","DateStartVoting":"{\"en\": \"Date Start Voting\", \"hk\": \"投票開始日期\", \"nl\": \"Begin datum stem vraag\", \"ru\": \"Дата начала голосования\", \"zh\": \"投票开始日期\"}","Del":"{\"en\": \"Delete\", \"hk\": \"刪除\", \"nl\": \"Verwijdering\", \"ru\": \"Удалить\", \"zh\": \"删除\"}","EnterIssue":"{\"en\": \"Enter Issue\", \"hk\": \"輸入問題\", \"nl\": \"Onderwerp\", \"ru\": \"Введите вопрос\", \"zh\": \"输入问题\"}","Finish":"{\"en\": \"Finish\", \"hk\": \"結束\", \"nl\": \"Einde\", \"ru\": \"Окончание\", \"zh\": \"结束\"}","Finished":"{\"en\": \"Finished\", \"hk\": \"已結束\", \"nl\": \"Einde\", \"ru\": \"Завершено\", \"zh\": \"已结束\"}","FinishedVotings":"{\"en\": \"Finished Votings\", \"hk\": \"已結束的投票\", \"nl\": \"Einde Stemmen\", \"ru\": \"Завершенные\", \"zh\": \"已结束的投票\"}","Fnsh":"{\"en\": \"Finish\", \"hk\": \"結束\", \"nl\": \"Einde\", \"ru\": \"Окончание\", \"zh\": \"结束\"}","Fnshd":"{\"en\": \"Finished\", \"hk\": \"已結束\", \"nl\": \"Einde\", \"ru\": \"Завершено\", \"zh\": \"已结束\"}","Gender":"{\"en\": \"Gender\", \"hk\": \"性別\", \"ru\": \"Пол\", \"zh\": \"性别\"}","GetResult":"{\"en\": \"Get Result\", \"hk\": \"獲取結果\", \"nl\": \"Haa resultaat op\", \"ru\": \"Получить результат\", \"zh\": \"获取结果\"}","GovernmentDashboard":"{\"en\": \"Government dashboard\", \"hk\": \"政務控制檯\", \"nl\": \"Land overzicht\", \"ru\": \"Панель государства\", \"zh\": \"政务控制台\"}","ID":"{\"en\": \"ID\", \"hk\": \"編號\", \"ru\": \"Номер\", \"zh\": \"编号\"}","Inf":"{\"en\": \"Info\", \"hk\": \"信息\", \"nl\": \"Info\", \"ru\": \"Информация\", \"zh\": \"信息\"}","Info":"{\"en\": \"Info\", \"hk\": \"信息\", \"nl\": \"Info\", \"ru\": \"Информация\", \"zh\": \"信息\"}","Iss":"{\"en\": \"Issue\", \"hk\": \"問題\", \"nl\": \"Onderwerp\", \"ru\": \"Вопрос\", \"zh\": \"问题\"}","Issue":"{\"en\": \"Issue\", \"hk\": \"問題\", \"nl\": \"Onderwerp\", \"ru\": \"Вопрос\", \"zh\": \"问题\"}","ListVotings":"{\"en\": \"List of Polling\", \"hk\": \"投票項目列表\", \"nl\": \"Stemlijst\", \"ru\": \"Опросы\", \"zh\": \"投票项目列表\"}","ListofApps":"{\"en\": \"List of applications:\", \"hk\": \"應用程式列表\", \"ru\": \"Список приложений:\", \"zh\": \"应用程序列表\"}","N":"{\"en\": \"No\", \"hk\": \"否\", \"nl\": \"Nee\", \"ru\": \"Нет\", \"zh\": \"否\"}","Name":"{\"en\": \"Name\", \"hk\": \"名稱\", \"ru\": \"Название\", \"zh\": \"名称\"}","NewVoting":"{\"en\": \"New Polling\", \"hk\": \"新投票\", \"nl\": \"Nieuwe vraag\", \"ru\": \"Новый опрос\", \"zh\": \"新投票\"}","Next":"{\"en\": \"Next\", \"hk\": \"下一個\", \"nl\": \"Naast\", \"ru\": \"Дальше\", \"zh\": \"下一个\"}","No":"{\"en\": \"No\", \"hk\": \"否\", \"nl\": \"Nee\", \"ru\": \"Нет\", \"zh\": \"否\"}","NoAvailablePolls":"{\"en\": \"No Available Polls\", \"hk\": \"暫無有效的投票項目\", \"nl\": \"Geen beschikbare vragen\", \"ru\": \"Нет доступных голосований\", \"zh\": \"暂无有效的投票项目\"}","Owner":"{\"en\": \"Owner\", \"hk\": \"所有權人\", \"zh\": \"所有权人\"}","QuestionList":"{\"en\": \"Questions List\", \"hk\": \"問題列表\", \"nl\": \"Lijst van vragen\", \"ru\": \"Список вопросов\", \"zh\": \"问题列表\"}","Referendapartij":"{\"en\": \"Referendapartij\", \"hk\": \"全員投票選舉\", \"nl\": \"stemNLwijzer.nl - directe democratie\", \"ru\": \"Referendapartij\", \"zh\": \"全员投票\"}","Res":"{\"en\": \"Result\", \"hk\": \"結果\", \"nl\": \"Resultaat\", \"ru\": \"Результат\", \"zh\": \"结果\"}","Result":"{\"en\": \"Result\", \"hk\": \"結果\", \"nl\": \"Resultaat\", \"ru\": \"Результат\", \"zh\": \"结果\"}","ResultSoon":"{\"en\": \" Result will be soon\", \"hk\": \"結果即將揭曉\", \"nl\": \" Result will be soon\", \"ru\": \"Результат будет скоро\", \"zh\": \"结果即将揭晓\"}","Save":"{\"en\": \"Save\", \"hk\": \"保存\", \"nl\": \"Bewaren\", \"ru\": \"Сохранить\", \"zh\": \"保存\"}","Search":"{\"en\": \"Search\", \"hk\": \"搜索\", \"ru\": \"Поиск\", \"zh\": \"搜索\"}","SearchAppbyName":"{\"en\": \"Search applications by name:\", \"hk\": \"通過名稱搜索應用程式\", \"ru\": \"Поиск приложения по названию:\", \"zh\": \"通过名称搜索应用程序\"}","ShowAll":"{\"en\": \"Show all\", \"hk\": \"顯示所有\", \"ru\": \"Показать все\", \"zh\": \"显示所有\"}","Start":"{\"en\": \"Start\", \"hk\": \"開始\", \"nl\": \"Sart\", \"ru\": \"Начало\", \"tw\": \"开始\"}","StartVote":"{\"en\": \"Start Vote\", \"hk\": \"開始投票\", \"nl\": \"Begin stemmen\", \"ru\": \"Начать голосование\", \"zh\": \"开始投票\"}","Stp":"{\"en\": \"Stop\", \"hk\": \"停止\", \"nl\": \"Stop\", \"ru\": \"Стоп\", \"zh\": \"停止\"}","Strt":"{\"en\": \"Start\", \"hk\": \"開始\", \"nl\": \"Sart\", \"ru\": \"Начало\", \"zh\": \"开始\"}","Synonym":"{\"en\": \"Synonym\", \"hk\": \"同義\", \"ru\": \"Синоним\", \"zh\": \"同义\"}","TEST_WARNING":"{\"en\": \"LOCALIZED_TEST\", \"hk\": \"測試報警\", \"zh\": \"测试报警\"}","TotalVoted":"{\"en\": \"Total voted\", \"hk\": \"總票數\", \"nl\": \"Aantal stemmen\", \"ru\": \"Всего проголосовало\", \"zh\": \"总票数\"}","TypeIssue":"{\"en\": \"Type\", \"hk\": \"類型\", \"nl\": \"Type\", \"ru\": \"Тип опроса\", \"zh\": \"类型\"}","View":"{\"en\": \"View\", \"hk\": \"顯示\", \"nl\": \"Uitzicht\", \"ru\": \"Смотреть\", \"zh\": \"显示\"}","Vote":"{\"en\": \"Vote\", \"hk\": \"投票\", \"nl\": \"Stemmen\", \"ru\": \"Голосовать\", \"zh\": \"投票\"}","Voting":"{\"en\": \"Voting\", \"hk\": \"投票/民調\", \"nl\": \"Stemmen\", \"ru\": \"Голосование\", \"zh\": \"投票/民调\"}","VotingFinished":"{\"en\": \" Voting finished\", \"hk\": \"該投票項目已結束\", \"nl\": \"Ende stemmen\", \"ru\": \"Голосование закончено\", \"zh\": \"该投票项目已结束\"}","Vw":"{\"en\": \"View\", \"hk\": \"顯示\", \"nl\": \"Uitzicht\", \"ru\": \"Смотреть\", \"zh\": \"显示\"}","Welcome":"{\"en\": \"Welcome\", \"hk\": \"歡迎您\", \"nl\": \"Welkom\", \"ru\": \"Добро пожаловать\", \"zh\": \"欢迎您\"}","Y":"{\"en\": \"Yes\", \"hk\": \"是\", \"nl\": \"Ja\", \"ru\": \"Да\", \"zh\": \"是\"}","Yes":"{\"en\": \"Yes\", \"hk\": \"是\", \"nl\": \"Ja\", \"ru\": \"Да\", \"zh\": \"是\"}","YouVoted":"{\"en\": \"You voted for all available issues\", \"hk\": \"您已對全部有效議題進行了投票\", \"nl\": \"U stemt op alle beschikbare onderwerpen\", \"ru\": \"Вы проголосовали за все доступные вопросы\", \"zh\": \"您已对全部有效议题进行了投票\"}","YourAnswer":"{\"en\": \"Your Answer\", \"hk\": \"您的答複\", \"nl\": \"Uw antwoord\", \"ru\": \"Ваш ответ\", \"zh\": \"您的答复\"}","accounts":"{\"en\": \"Accounts\", \"hk\": \"賬戶信息\", \"zh\": \"账户信息\"}","add_land":"{\"en\": \"Add Land\", \"hk\": \"新增土地\", \"zh\": \"新增土地\"}","add_role":"{\"en\": \"Add role\", \"hk\": \"增加職位身份\", \"zh\": \"增加职位身份\"}","add_voting":"{\"en\": \"Add voting\", \"hk\": \"新增投票/民調\", \"zh\": \"新增投票/民调\"}","address":"{\"en\": \"Address\", \"hk\": \"地址\", \"zh\": \"地址\"}","admin_tools":"{\"en\": \"Admin tools\", \"hk\": \"管理員工具\", \"zh\": \"管理员工具\"}","amount":"{\"en\": \"Amount\", \"hk\": \"數量\", \"zh\": \"数量\"}","app_list":"{\"en\": \"App List\", \"hk\": \"應用程式列表\", \"zh\": \"应用程序列表\"}","area":"{\"en\": \"Area\", \"hk\": \"面積\", \"zh\": \"面积\"}","buildings_use_class":"{\"en\": \"Buildings use class\", \"hk\": \"建築物類型\", \"zh\": \"建筑物类型\"}","change":"{\"en\": \"Change\", \"hk\": \"變更\", \"zh\": \"变更\"}","coords":"{\"en\": \"Coords\", \"hk\": \"座標\", \"zh\": \"座标\"}","create":"{\"en\": \"Create\", \"hk\": \"創建\", \"zh\": \"创建\"}","creator":"{\"en\": \"Creator\", \"hk\": \"創建人\", \"zh\": \"创建人\"}","dashboard":"{\"en\": \"Dashboard\", \"hk\": \"儀錶板\", \"zh\": \"仪表板\"}","date_accept":"{\"en\": \"Date Accept\", \"hk\": \"審批日期\", \"zh\": \"审批日期\"}","date_create":"{\"en\": \"Date create\", \"hk\": \"創建日期\", \"zh\": \"创建日期\"}","date_delete":"{\"en\": \"Date Delete\", \"hk\": \"刪除日期\", \"zh\": \"删除日期\"}","date_start":"{\"en\": \"Date start\", \"hk\": \"開始日期\", \"zh\": \"开始日期\"}","dateformat":"{\"en\": \"YYYY-MM-DD\", \"hk\": \"YYYY年MM月DD日\", \"ru\": \"DD.MM.YYYY\", \"zh\": \"YYYY年MM月DD日\"}","decision":"{\"en\": \"Decision\", \"hk\": \"表決\", \"zh\": \"表决\"}","description":"{\"en\": \"Description\", \"hk\": \"描述\", \"zh\": \"描述\"}","do_you_want_to_delete_this_voting?":"{\"en\": \"Do you want to delete this voting?\", \"hk\": \"確認刪除該投票/民調項目？\", \"zh\": \"确认删除该投票/民调项目？\"}","edit":"{\"en\": \"Edit\", \"hk\": \"編輯\", \"zh\": \"编辑\"}","editing_profile":"{\"en\": \"Editing profile\", \"hk\": \"編輯會員信息\", \"zh\": \"编辑会员信息\"}","emission":"{\"en\": \"Emission\", \"hk\": \"發行\", \"zh\": \"发行\"}","execute":"{\"en\": \"Execute\", \"hk\": \"執行\", \"zh\": \"执行\"}","expiration":"{\"en\": \"Expiration\", \"hk\": \"過期日期\", \"zh\": \"过期日期\"}","export":"{\"en\": \"Export\", \"hk\": \"導出\", \"zh\": \"导出\"}","female":"{\"en\": \"Female\", \"hk\": \"女\", \"ru\": \"Женский\", \"zh\": \"女\"}","gen_keys":"{\"en\": \"Gen Keys\", \"hk\": \"生成密鈅\", \"zh\": \"生成密钥\"}","history":"{\"en\": \"History\", \"hk\": \"歷史紀錄\", \"zh\": \"历史纪录\"}","impossible":"{\"en\": \"Impossible\", \"hk\": \"不可回收\", \"zh\": \"不可回收\"}","interface":"{\"en\": \"Interface\", \"hk\": \"接口界面\", \"zh\": \"接口界面\"}","land_registry":"{\"en\": \"Land Registry\", \"hk\": \"土地登記註冊\", \"zh\": \"土地登记注册\"}","land_use":"{\"en\": \"Land use\", \"hk\": \"土地用途\", \"zh\": \"土地用途\"}","languages":"{\"en\": \"Languages\", \"hk\": \"多語言資源\", \"zh\": \"多语言资源\"}","limited":"{\"en\": \"Limited\", \"hk\": \"有限\", \"zh\": \"有限\"}","male":"{\"en\": \"Male\", \"hk\": \"男\", \"ru\": \"Мужской\", \"zh\": \"男\"}","map":"{\"en\": \"Map\", \"hk\": \"地圖\", \"zh\": \"地图\"}","member":"{\"en\": \"Member\", \"hk\": \"成員\", \"zh\": \"成员\"}","member_id":"{\"en\": \"Member ID\", \"hk\": \"成員ID\", \"zh\": \"成员ID\"}","members":"{\"en\": \"Members\", \"hk\": \"成員\", \"zh\": \"成员\"}","membersandroles":"{\"en\": \"Members and Roles\", \"hk\": \"成員和職務身份\", \"zh\": \"成员和职务身份\"}","membership_request":"{\"en\": \"Membership Request\", \"hk\": \"待審批的會員列表\", \"zh\": \"待审批的会员列表\"}","message":"{\"en\": \"Message\", \"hk\": \"信息\", \"zh\": \"信息\"}","moneyrollback":"{\"en\": \"Money rollback\", \"hk\": \"資產回收\", \"zh\": \"资产回收\"}","moneytransfer":"{\"en\": \"Money transfer\", \"hk\": \"資產轉賬\", \"zh\": \"资产转账\"}","my_chats":"{\"en\": \"My Chats\", \"hk\": \"我的交流窗口\", \"zh\": \"我的交流窗口\"}","name":"{\"en\": \"Name\", \"hk\": \"名稱\", \"zh\": \"名称\"}","name_first":"{\"en\": \"First name\", \"hk\": \"名字\", \"ru\": \"Имя\", \"zh\": \"名字\"}","name_last":"{\"en\": \"Last name\", \"hk\": \"姓氏\", \"ru\": \"Фамилия\", \"zh\": \"姓氏\"}","new_role":"{\"en\": \"New role\", \"hk\": \"新增職務身份\", \"zh\": \"新增职务身份\"}","not_limited":"{\"en\": \"Not Limited\", \"hk\": \"無限制\", \"zh\": \"无限制\"}","notifics":"{\"en\": \"Notifics\", \"hk\": \"通告\", \"zh\": \"通告\"}","participants":"{\"en\": \"Participants\", \"hk\": \"參與人\", \"zh\": \"参与人\"}","photo":"{\"en\": \"Photo\", \"hk\": \"照片\", \"zh\": \"照片\"}","possible":"{\"en\": \"Possible\", \"hk\": \"可回收\", \"zh\": \"可回收\"}","profile":"{\"en\": \"Profile\", \"hk\": \"用戶信息\", \"zh\": \"用户信息\"}","property_registry":"{\"en\": \"Property Registry\", \"hk\": \"房產註冊\", \"zh\": \"房产注册\"}","qes1":"{\"en\": \"the first question \", \"hk\": \"首要問題\", \"nl\": \"De eerste vraag\", \"zh\": \"首要问题\"}","ques1":"{\"en\": \"the first question \", \"hk\": \"首要問題\", \"nl\": \"De eerste vraag\", \"zh\": \"首要问题\"}","role_messages":"{\"en\": \"Role messages\", \"hk\": \"職務類信息\", \"zh\": \"职务类信息\"}","role_name":"{\"en\": \"Role name\", \"hk\": \"職務身份名稱\", \"zh\": \"职务身份名称\"}","rolenotifications":"{\"en\": \"Role notifications\", \"hk\": \"工作通知\", \"zh\": \"工作通知\"}","roles":"{\"en\": \"Roles\", \"hk\": \"職務身份\", \"zh\": \"职务身份\"}","rollback_tokens":"{\"en\": \"Rollback Tokens\", \"hk\": \"回收代幣\", \"zh\": \"回收代币\"}","search":"{\"en\": \"Search\", \"hk\": \"搜索\", \"zh\": \"搜索\"}","send":"{\"en\": \"Send\", \"hk\": \"發送\", \"zh\": \"发送\"}","signatures":"{\"en\": \"Signatures\", \"hk\": \"數字簽名\", \"zh\": \"数字签名\"}","singlenotifications":"{\"en\": \"Single notifications\", \"hk\": \"個人通知\", \"zh\": \"个人通知\"}","smart_contracts":"{\"en\": \"Smart contracts\", \"hk\": \"智能合約\", \"zh\": \"智能合约\"}","start_end_date":"{\"en\": \"Start \\\\ end date\", \"hk\": \"開始 / 結束日期\", \"zh\": \"开始 / 结束日期\"}","status":"{\"en\": \"Status\", \"hk\": \"狀態\", \"zh\": \"状态\"}","subject_of_voting":"{\"en\": \"Subject of voting\", \"hk\": \"投票/民調主題\", \"zh\": \"投票/民调主题\"}","success":"{\"en\": \"Success\", \"hk\": \"成功與否\", \"zh\": \"成功与否\"}","systemtokens":"{\"en\": \"System tokens\", \"hk\": \"系統代幣\", \"zh\": \"系统代币\"}","tables":"{\"en\": \"Tables\", \"hk\": \"數據表\", \"zh\": \"数据表\"}","testpage":"{\"en\": \"Test page\", \"hk\": \"測試頁面\", \"zh\": \"测试页面\"}","timeformat":"{\"en\": \"YYYY-MM-DD HH:MI:SS\", \"hk\": \"YYYY年MM月DD日 HH:MI:SS\", \"ru\": \"DD.MM.YYYY HH:MI:SS\", \"zh\": \"YYYY年MM月DD日 HH:MI:SS\"}","tokens":"{\"en\": \"Tokens\", \"hk\": \"代幣\", \"zh\": \"代币\"}","type":"{\"en\": \"Type\", \"hk\": \"類型\", \"zh\": \"类型\"}","unlimited":"{\"en\": \"Unlimited\", \"hk\": \"無限\", \"zh\": \"无限\"}","view_all":"{\"en\": \"View all\", \"hk\": \"顯示所有\", \"zh\": \"显示所有\"}","visitor":"{\"en\": \"Visitor\", \"hk\": \"訪客（僅瀏覽）\", \"zh\": \"访客（仅浏览）\"}","visitor_sr":"{\"en\": \"Visitor (SR)\", \"hk\": \"嘉賓（部分權限）\", \"zh\": \"嘉宾（部分权限）\"}","voting":"{\"en\": \"Voting\", \"hk\": \"投票/民調\", \"ru\": \"voting\", \"zh\": \"投票/民调\"}","voting_actions":"{\"en\": \"Actions\", \"hk\": \"動作\", \"ru\": \"Actions\", \"zh\": \"动作\"}","voting_create":"{\"en\": \"Create new\", \"hk\": \"新建投票項目\", \"ru\": \"Create new\", \"zh\": \"新建投票项目\"}","voting_creator":"{\"en\": \"Creator\", \"hk\": \"創建者\", \"ru\": \"Creator\", \"zh\": \"创建者\"}","voting_decision":"{\"en\": \"Subject of voting\", \"hk\": \"投票項目的主題\", \"ru\": \"Subject of voting\", \"zh\": \"投票项目的主题\"}","voting_decisions_candidate_manual":"{\"en\": \"Role candidates with manual registration of participants\", \"hk\": \"按要求人工登記的候選人\", \"ru\": \"Role candidates with manual registration of participants\", \"zh\": \"按要求人工登记的候选人\"}","voting_decisions_candidate_requests":"{\"en\": \"Role candidates with registration of participants by request\", \"hk\": \"按要求自動登記的候選人\", \"ru\": \"Role candidates with registration of participants by request\", \"zh\": \"按要求自动登记的候选人\"}","voting_decisions_db":"{\"en\": \"Formal decision\", \"hk\": \"正式決議\", \"ru\": \"Formal decision\", \"zh\": \"正式决议\"}","voting_decisions_document":"{\"en\": \"Document approval\", \"hk\": \"文件審批\", \"ru\": \"Document approval\", \"zh\": \"文件审批\"}","voting_decisions_set":"{\"en\": \"Set goal\", \"hk\": \"設定投票目標\", \"ru\": \"Set goal\", \"zh\": \"设定投票目标\"}","voting_description":"{\"en\": \"Description\", \"hk\": \"投票項目簡介\", \"ru\": \"Description\", \"zh\": \"投票项目简介\"}","voting_end":"{\"en\": \"End date\", \"hk\": \"結束日期\", \"ru\": \"End date\", \"zh\": \"结束日期\"}","voting_end_desc":"{\"en\": \"End date for voting\", \"hk\": \"投票結束日期\", \"ru\": \"End date for voting\", \"zh\": \"投票结束日期\"}","voting_error":"{\"en\": \"Error\", \"hk\": \"投票錯誤\", \"ru\": \"Error\", \"zh\": \"投票错误\"}","voting_error_not_exists":"{\"en\": \"Requested entry does not exist\", \"hk\": \"該投票項目不存在\", \"ru\": \"Requested entry does not exist\", \"zh\": \"该投票项目不存在\"}","voting_invite":"{\"en\": \"Invite\", \"hk\": \"投票邀請\", \"ru\": \"Invite\", \"zh\": \"投票邀请\"}","voting_list":"{\"en\": \"voting list\", \"hk\": \"投票項目列表\", \"ru\": \"voting list\", \"zh\": \"投票项目列表\"}","voting_participant_id":"{\"en\": \"Citizen ID\", \"hk\": \"投票參與者 ID\", \"ru\": \"Citizen ID\", \"zh\": \"投票参与者 ID\"}","voting_participants":"{\"en\": \"Invited participants\", \"hk\": \"受邀投票參與者\", \"ru\": \"Invited participants\", \"zh\": \"受邀投票参与者\"}","voting_participants_everybody":"{\"en\": \"Anybody\", \"hk\": \"所有人\", \"ru\": \"Anybody\", \"zh\": \"所有人\"}","voting_participants_manual":"{\"en\": \"Choose manually\", \"hk\": \"手動選擇\", \"ru\": \"Choose manually\", \"zh\": \"手动选择\"}","voting_participants_role":"{\"en\": \"By role\", \"hk\": \"按職務和身份\", \"ru\": \"By role\", \"zh\": \"按职务和身份\"}","voting_prestart":"{\"en\": \"Start date for applications\", \"hk\": \"應用程式的開始日期\", \"ru\": \"Start date for applications\", \"zh\": \"应用程序的开始日期\"}","voting_quorum":"{\"en\": \"Quorum\", \"hk\": \"法定人數\", \"ru\": \"Quorum\", \"zh\": \"法定人数\"}","voting_quorum_desc":"{\"en\": \"Percentage value of total participiants to fulfill requirements of this poll (from 5 to 100)\", \"hk\": \"滿足本次投票要求的參與人數百分比（5〜100）\", \"ru\": \"Percentage value of total participiants to fulfill requirements of this poll (from 5 to 100)\", \"zh\": \"满足本次投票要求的参与人数百分比（5〜100）\"}","voting_start":"{\"en\": \"Start date\", \"hk\": \"開始日期\", \"ru\": \"Start date\", \"zh\": \"开始日期\"}","voting_start_desc":"{\"en\": \"Start date for voting\", \"hk\": \"開始投票日期\", \"ru\": \"Start date for voting\", \"zh\": \"开始投票日期\"}","voting_view":"{\"en\": \"View\", \"hk\": \"顯示詳情\", \"ru\": \"View\", \"zh\": \"显示详情\"}","voting_volume":"{\"en\": \"Volume\", \"hk\": \"投票通過率\", \"ru\": \"Volume\", \"zh\": \"投票通过率\"}","voting_volume_desc":"{\"en\": \"Percentage value of votes to fulfill requirements of this poll (from 50 to 100)\", \"hk\": \"符合投票要求的票數百分比（50〜100）\", \"ru\": \"Percentage value of votes to fulfill requirements of this poll (from 50 to 100)\", \"zh\": \"符合投票要求的票数百分比（50〜100）\"}","voting_voting_participants":"{\"en\": \"Voting participants\", \"hk\": \"投票參與者\", \"ru\": \"Voting participants\", \"zh\": \"投票参与者\"}","wallet":"{\"en\": \"Wallet\", \"hk\": \"錢包信息\", \"zh\": \"钱包信息\"}","write_a_message_for_the_role":"{\"en\": \"Write a message for the role\", \"hk\": \"發送信息給該職位身份的所有成員\", \"zh\": \"发送信息给该职位身份的所有成员\"}"}`)
TextHidden(l_lang)
Json(`Head: "",
Desc: "",
		Img: "/static/img/apps/ava.png",
		OnSuccess: {
			script: 'template',
			page: 'government',
			parameters: {}
		},
		TX: [{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "accounts",
			columns: '[["onhold", "int64", "1"],["citizen_id", "int64", "1"],["type", "int64", "1"],["amount", "money", "0"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_accounts",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractAccess(\"tokens_Account_Add\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_accounts",
			column_name: "type",
			permissions: "ContractAccess(\"tokens_Account_Add\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_accounts",
			column_name: "amount",
			permissions: "ContractAccess(\"tokens_Money_Transfer\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_accounts",
			column_name: "onhold",
			permissions: "ContractAccess(\"tokens_Account_Close\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_accounts",
			column_name: "citizen_id",
			permissions: "ContractAccess(\"tokens_Account_Add\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "accounts_tokens",
			columns: '[["delete", "int64", "1"],["date_create", "time", "1"],["name_tokens", "hash", "1"],["type_emission", "int64", "1"],["date_expiration", "time", "1"],["flag_rollback_tokens", "int64", "1"],["amount", "int64", "1"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_accounts_tokens",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractAccess(\"tokens_Emission\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_accounts_tokens",
			column_name: "type_emission",
			permissions: "ContractAccess(\"tokens_Emission\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_accounts_tokens",
			column_name: "date_expiration",
			permissions: "ContractAccess(\"tokens_Emission\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_accounts_tokens",
			column_name: "flag_rollback_tokens",
			permissions: "ContractAccess(\"tokens_Emission\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_accounts_tokens",
			column_name: "amount",
			permissions: "ContractAccess(\"tokens_Emission\",\"tokens_EmissionAdd\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_accounts_tokens",
			column_name: "delete",
			permissions: "ContractAccess(\"tokens_Emission\",\"tokens_Close\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_accounts_tokens",
			column_name: "date_create",
			permissions: "ContractAccess(\"tokens_Emission\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_accounts_tokens",
			column_name: "name_tokens",
			permissions: "ContractAccess(\"tokens_Emission\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "chat_private_chats",
			columns: '[["lower_id", "int64", "1"],["higher_id", "int64", "1"],["last_message", "text", "0"],["sender_avatar", "text", "0"],["receiver_avatar", "text", "0"],["sender_id", "int64", "1"],["receiver_id", "int64", "1"],["sender_name", "text", "0"],["receiver_name", "text", "0"],["last_message_id", "int64", "0"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_chat_private_chats",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractConditions(\"CitizenCondition\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_chats",
			column_name: "higher_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_chats",
			column_name: "sender_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_chats",
			column_name: "sender_name",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_chats",
			column_name: "receiver_name",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_chats",
			column_name: "lower_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_chats",
			column_name: "receiver_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_chats",
			column_name: "last_message",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_chats",
			column_name: "sender_avatar",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_chats",
			column_name: "last_message_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_chats",
			column_name: "receiver_avatar",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "chat_private_messages",
			columns: '[["message", "text", "0"],["receiver", "int64", "0"],["sender_name", "text", "0"],["sender_role_id", "int64", "1"],["sender", "int64", "0"],["sender_avatar", "text", "0"],["receiver_avatar", "text", "0"],["receiver_role_id", "int64", "1"],["receiver_name", "text", "0"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_chat_private_messages",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractConditions(\"CitizenCondition\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_messages",
			column_name: "receiver_avatar",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_messages",
			column_name: "receiver_role_id",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_messages",
			column_name: "sender_avatar",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_messages",
			column_name: "message",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_messages",
			column_name: "receiver",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_messages",
			column_name: "sender_name",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_messages",
			column_name: "receiver_name",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_messages",
			column_name: "sender_role_id",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_private_messages",
			column_name: "sender",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "chat_role_chats",
			columns: '[["role_id", "int64", "1"],["citizen_id", "int64", "1"],["sender_name", "text", "0"],["last_message", "text", "0"],["sender_avatar", "text", "0"],["last_message_frome_role", "int64", "0"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_chat_role_chats",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractConditions(\"CitizenCondition\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_role_chats",
			column_name: "role_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_role_chats",
			column_name: "citizen_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_role_chats",
			column_name: "sender_name",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_role_chats",
			column_name: "last_message",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_role_chats",
			column_name: "sender_avatar",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_chat_role_chats",
			column_name: "last_message_frome_role",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "citizens",
			columns: '[["name", "hash", "1"],["public_key_0", "hash", "0"],["test", "text", "0"],["avatar", "text", "0"],["coords", "hash", "0"],["newcoords", "text", "0"],["date_expiration", "time", "1"],["newsex", "hash", "0"],["address", "hash", "0"],["date_end", "time", "1"],["date_start", "time", "1"],["person_status", "int64", "1"],["sex", "int64", "0"],["gender", "int64", "1"],["birthday", "time", "0"],["name_last", "hash", "1"],["newaddress", "text", "0"],["newbirthday", "hash", "0"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_citizens",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractConditions(\"MainCondition\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "newaddress",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "date_expiration",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "sex",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "name",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "test",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "newsex",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "name_last",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "coords",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "date_start",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "person_status",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "avatar",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "gender",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "address",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "newcoords",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "birthday",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "date_end",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "newbirthday",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizens",
			column_name: "public_key_0",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "citizenship_requests",
			columns: '[["dlt_wallet_id", "int64", "1"],["name", "hash", "1"],["approved", "int64", "1"],["block_id", "int64", "1"],["public_key_0", "text", "0"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_citizenship_requests",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "true",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizenship_requests",
			column_name: "name",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizenship_requests",
			column_name: "approved",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizenship_requests",
			column_name: "block_id",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizenship_requests",
			column_name: "public_key_0",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_citizenship_requests",
			column_name: "dlt_wallet_id",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "editing_land_registry",
			columns: '[["new_attr_value", "text", "0"],["old_attr_value", "text", "0"],["editing_attribute", "hash", "1"],["date", "time", "0"],["person_id", "int64", "1"],["person_name", "hash", "1"],["lend_object_id", "int64", "1"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_editing_land_registry",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "true",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_editing_land_registry",
			column_name: "person_name",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_editing_land_registry",
			column_name: "lend_object_id",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_editing_land_registry",
			column_name: "new_attr_value",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_editing_land_registry",
			column_name: "old_attr_value",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_editing_land_registry",
			column_name: "editing_attribute",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_editing_land_registry",
			column_name: "date",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_editing_land_registry",
			column_name: "person_id",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "land_ownership",
			columns: '[["date_signing", "time", "1"],["owner_new_id", "int64", "1"],["lend_object_id", "int64", "1"],["price", "money", "1"],["owner_id", "int64", "1"],["date_creat", "time", "0"],["owner_type", "int64", "1"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_land_ownership",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "true",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_ownership",
			column_name: "price",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_ownership",
			column_name: "owner_id",
			permissions: "ContractAccess(\"LandSaleContract\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_ownership",
			column_name: "date_creat",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_ownership",
			column_name: "owner_type",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_ownership",
			column_name: "date_signing",
			permissions: "ContractAccess(\"LandSaleContract\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_ownership",
			column_name: "owner_new_id",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_ownership",
			column_name: "lend_object_id",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "land_registry",
			columns: '[["area", "int64", "1"],["coords", "text", "0"],["date_last_edit", "time", "1"],["value", "money", "1"],["address", "text", "0"],["land_use", "int64", "1"],["date_insert", "time", "1"],["buildings_use_class", "int64", "1"],["land_registry_number", "int64", "1"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_land_registry",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "true",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_registry",
			column_name: "date_insert",
			permissions: "true",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_registry",
			column_name: "date_last_edit",
			permissions: "true",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_registry",
			column_name: "buildings_use_class",
			permissions: "true",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_registry",
			column_name: "land_registry_number",
			permissions: "true",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_registry",
			column_name: "value",
			permissions: "true",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_registry",
			column_name: "address",
			permissions: "true",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_registry",
			column_name: "land_use",
			permissions: "true",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_registry",
			column_name: "area",
			permissions: "true",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_land_registry",
			column_name: "coords",
			permissions: "true",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "member_info",
			columns: '[["user_id", "hash", "1"],["birthday", "hash", "0"],["address_map", "text", "0"],["sex", "hash", "0"],["name", "text", "0"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_member_info",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractConditions(\"MainCondition\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_member_info",
			column_name: "sex",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_member_info",
			column_name: "name",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_member_info",
			column_name: "user_id",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_member_info",
			column_name: "birthday",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_member_info",
			column_name: "address_map",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "notification",
			columns: '[["closed", "int64", "1"],["header", "hash", "0"],["started_processing_id", "int64", "1"],["finished_processing_id", "int64", "1"],["icon", "int64", "0"],["role_id", "int64", "1"],["page_name", "hash", "1"],["page_value", "int64", "1"],["finished_processing_time", "time", "0"],["type", "hash", "1"],["recipient_id", "int64", "1"],["started_processing_time", "time", "0"],["page_value2", "hash", "1"],["text_body", "text", "0"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_notification",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractAccess(\"notification_single_send\",\"notification_roles_send\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "text_body",
			permissions: "ContractAccess(\"notification_single_send\",\"notification_roles_send\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "page_value2",
			permissions: "ContractAccess(\"notification_single_send\",\"notification_roles_send\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "started_processing_id",
			permissions: "ContractAccess(\"notification_role_processing\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "finished_processing_id",
			permissions: "ContractAccess(\"notification_single_close\",\"notification_role_close\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "type",
			permissions: "ContractAccess(\"notification_single_send\",\"notification_roles_send\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "closed",
			permissions: "ContractAccess(\"notification_single_close\",\"notification_role_close\",\"roles_Del\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "header",
			permissions: "ContractAccess(\"notification_single_send\",\"notification_roles_send\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "recipient_id",
			permissions: "ContractAccess(\"notification_single_send\",\"notification_roles_send\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "started_processing_time",
			permissions: "ContractAccess(\"notification_role_processing\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "finished_processing_time",
			permissions: "ContractAccess(\"notification_single_close\",\"notification_role_close\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "icon",
			permissions: "ContractAccess(\"notification_single_send\",\"notification_roles_send\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "role_id",
			permissions: "ContractAccess(\"notification_roles_send\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "page_name",
			permissions: "ContractAccess(\"notification_single_send\",\"notification_roles_send\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_notification",
			column_name: "page_value",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "property",
			columns: '[["sell_price", "money", "1"],["area", "int64", "0"],["type", "int64", "1"],["coords", "text", "0"],["sewerage", "int64", "0"],["rent_price", "money", "1"],["police_inspection", "int64", "1"],["business_suitability", "int64", "1"],["name", "text", "0"],["leaser", "int64", "1"],["offers", "int64", "0"],["citizen_id", "int64", "1"],["waste_solutions", "int64", "0"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_property",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractConditions(\"MainCondition\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "citizen_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "sell_price",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "waste_solutions",
			permissions: "ContractAccess(\"PropertyRegistryChange\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "type",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "coords",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "leaser",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "offers",
			permissions: "ContractAccess(\"PropertyRegistryChange\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "sewerage",
			permissions: "ContractAccess(\"PropertyRegistryChange\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "police_inspection",
			permissions: "ContractAccess(\"PropertyRegistryChange\",\"EditProperty\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "area",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "name",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "rent_price",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_property",
			column_name: "business_suitability",
			permissions: "ContractAccess(\"PropertyRegistryChange\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "roles_assign",
			columns: '[["appointed_by_id", "int64", "1"],["appointed_by_name", "hash", "1"],["delete", "int64", "1"],["role_id", "int64", "1"],["member_id", "int64", "1"],["date_start", "time", "1"],["role_title", "hash", "1"],["date_end", "time", "1"],["role_name", "hash", "1"],["member_name", "hash", "1"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_roles_assign",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractAccess(\"roles_Assign\",\"votingDecideCandidates\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_assign",
			column_name: "date_end",
			permissions: "ContractAccess(\"roles_Del\",\"roles_UnAssign\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_assign",
			column_name: "member_id",
			permissions: "ContractAccess(\"roles_Assign\",\"votingDecideCandidates\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_assign",
			column_name: "role_name",
			permissions: "ContractAccess(\"roles_Assign\",\"votingDecideCandidates\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_assign",
			column_name: "role_title",
			permissions: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_assign",
			column_name: "appointed_by_id",
			permissions: "ContractAccess(\"roles_Assign\",\"votingDecideCandidates\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_assign",
			column_name: "delete",
			permissions: "ContractAccess(\"roles_Del\",\"roles_UnAssign\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_assign",
			column_name: "role_id",
			permissions: "ContractAccess(\"roles_Assign\",\"votingDecideCandidates\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_assign",
			column_name: "date_start",
			permissions: "ContractAccess(\"roles_Assign\",\"votingDecideCandidates\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_assign",
			column_name: "member_name",
			permissions: "ContractAccess(\"roles_Assign\",\"votingDecideCandidates\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_assign",
			column_name: "appointed_by_name",
			permissions: "ContractAccess(\"roles_Assign\",\"votingDecideCandidates\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "roles_list",
			columns: '[["creator_name", "hash", "1"],["delete", "int64", "1"],["role_name", "hash", "1"],["role_type", "int64", "1"],["creator_id", "int64", "1"],["date_create", "time", "1"],["date_delete", "time", "1"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_roles_list",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractAccess(\"roles_Add\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_list",
			column_name: "role_name",
			permissions: "ContractAccess(\"roles_Add\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_list",
			column_name: "role_type",
			permissions: "ContractAccess(\"roles_Add\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_list",
			column_name: "creator_id",
			permissions: "ContractAccess(\"roles_Add\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_list",
			column_name: "date_create",
			permissions: "ContractAccess(\"roles_Add\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_list",
			column_name: "date_delete",
			permissions: "ContractAccess(\"roles_Del\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_list",
			column_name: "creator_name",
			permissions: "ContractAccess(\"roles_Add\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_roles_list",
			column_name: "delete",
			permissions: "ContractAccess(\"roles_Del\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "voting_instances",
			columns: '[["description", "text", "0"],["flag_success", "int64", "1"],["number_participants", "int64", "1"],["name", "hash", "1"],["enddate", "time", "1"],["creator_id", "int64", "1"],["number_voters", "int64", "1"],["delete", "int64", "0"],["quorum", "int64", "0"],["volume", "int64", "0"],["flag_decision", "int64", "0"],["flag_fulldata", "int64", "0"],["percent_voters", "int64", "0"],["percent_success", "int64", "0"],["typeparticipants", "int64", "0"],["optional_number_cands", "int64", "1"],["startdate", "time", "1"],["typedecision", "int64", "0"],["flag_notifics", "int64", "0"],["optional_role_id", "int64", "1"],["optional_role_vacancies", "int64", "1"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_voting_instances",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractConditions(\"CitizenCondition\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "optional_number_cands",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "optional_role_vacancies",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "delete",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "volume",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "enddate",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "percent_voters",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "percent_success",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "description",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "flag_success",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "flag_fulldata",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "typeparticipants",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "number_participants",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "flag_notifics",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "number_voters",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "optional_role_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "name",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "quorum",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "creator_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "typedecision",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "flag_decision",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_instances",
			column_name: "startdate",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "voting_participants",
			columns: '[["decision_date", "time", "1"],["decision", "int64", "1"],["member_id", "int64", "1"],["voting_id", "int64", "1"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_voting_participants",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractConditions(\"CitizenCondition\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_participants",
			column_name: "decision",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_participants",
			column_name: "member_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_participants",
			column_name: "voting_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_participants",
			column_name: "decision_date",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "voting_subject",
			columns: '[["formal_decision_colvalue", "hash", "1"],["formal_decision_description", "text", "0"],["number_accept", "int64", "1"],["text_doc_hash", "text", "0"],["text_document", "text", "0"],["formal_decision_column", "hash", "1"],["formal_decision_tableid", "int64", "1"],["member_id", "int64", "1"],["voting_id", "int64", "1"],["formal_decision_table", "hash", "1"]]'
			}
	   },
{
		Forsign: 'table_name,general_update,insert,new_column',
		Data: {
			type: "EditTable",
			typeid: #type_edit_table_id#,
			table_name : "#state_id#_voting_subject",
			general_update: "ContractConditions(\"MainCondition\")",
			insert: "ContractConditions(\"CitizenCondition\")",
			new_column: "ContractConditions(\"MainCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_subject",
			column_name: "formal_decision_table",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_subject",
			column_name: "formal_decision_tableid",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_subject",
			column_name: "formal_decision_colvalue",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_subject",
			column_name: "formal_decision_description",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_subject",
			column_name: "voting_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_subject",
			column_name: "number_accept",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_subject",
			column_name: "text_doc_hash",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_subject",
			column_name: "text_document",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_subject",
			column_name: "formal_decision_column",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'table_name,column_name,permissions',
		Data: {
			type: "EditColumn",
			typeid: #type_edit_column_id#,
			table_name : "#state_id#_voting_subject",
			column_name: "member_id",
			permissions: "ContractConditions(\"CitizenCondition\")",
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_accounts",
			value: $("#d_Export0_accounts").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_accounts"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_accounts"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_accounts_tokens",
			value: $("#d_Export0_accounts_tokens").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_accounts_tokens"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_accounts_tokens"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_chat_private_chats",
			value: $("#d_Export0_chat_private_chats").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_chat_private_chats"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_chat_private_chats"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_chat_private_messages",
			value: $("#d_Export0_chat_private_messages").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_chat_private_messages"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_chat_private_messages"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_chat_role_chats",
			value: $("#d_Export0_chat_role_chats").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_chat_role_chats"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_chat_role_chats"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_citizens",
			value: $("#d_Export0_citizens").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_citizens"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_citizens"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_citizenship_requests",
			value: $("#d_Export0_citizenship_requests").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_citizenship_requests"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_citizenship_requests"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_editing_land_registry",
			value: $("#d_Export0_editing_land_registry").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_editing_land_registry"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_editing_land_registry"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_land_ownership",
			value: $("#d_Export0_land_ownership").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_land_ownership"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_land_ownership"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_land_registry",
			value: $("#d_Export0_land_registry").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_land_registry"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_land_registry"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_member_info",
			value: $("#d_Export0_member_info").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_member_info"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_member_info"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_notification",
			value: $("#d_Export0_notification").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_notification"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_notification"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_property",
			value: $("#d_Export0_property").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_property"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_property"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_roles_assign",
			value: $("#d_Export0_roles_assign").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_roles_assign"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_roles_assign"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_roles_list",
			value: $("#d_Export0_roles_list").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_roles_list"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_roles_list"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_voting_instances",
			value: $("#d_Export0_voting_instances").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_voting_instances"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_voting_instances"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_voting_participants",
			value: $("#d_Export0_voting_participants").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_voting_participants"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_voting_participants"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "Export0_voting_subject",
			value: $("#d_Export0_voting_subject").val(),
			conditions: "ContractConditions(\"MainCondition\")"
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "Export0_voting_subject"
			}
	   },
{
				Forsign: '',
				Data: {
					type: "Contract",
					global: 0,
					name: "Export0_voting_subject"
					}
			},
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "CitizenCondition",
			value: $("#sc_CitizenCondition").val(),
			conditions: $("#scc_CitizenCondition").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "CitizenCondition"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "LandBuyContract",
			value: $("#sc_LandBuyContract").val(),
			conditions: $("#scc_LandBuyContract").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "LandBuyContract"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "chat_send_private_message",
			value: $("#sc_chat_send_private_message").val(),
			conditions: $("#scc_chat_send_private_message").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "chat_send_private_message"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingDelete",
			value: $("#sc_votingDelete").val(),
			conditions: $("#scc_votingDelete").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingDelete"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "AddProperty",
			value: $("#sc_AddProperty").val(),
			conditions: $("#scc_AddProperty").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "AddProperty"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "chat_reply_to_message",
			value: $("#sc_chat_reply_to_message").val(),
			conditions: $("#scc_chat_reply_to_message").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "chat_reply_to_message"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "LandSaleContract",
			value: $("#sc_LandSaleContract").val(),
			conditions: $("#scc_LandSaleContract").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "LandSaleContract"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "MainCondition",
			value: $("#sc_MainCondition").val(),
			conditions: $("#scc_MainCondition").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "MainCondition"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "MemberEdit",
			value: $("#sc_MemberEdit").val(),
			conditions: $("#scc_MemberEdit").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "MemberEdit"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "members_Change_Status",
			value: $("#sc_members_Change_Status").val(),
			conditions: $("#scc_members_Change_Status").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "members_Change_Status"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "members_Request_Reject",
			value: $("#sc_members_Request_Reject").val(),
			conditions: $("#scc_members_Request_Reject").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "members_Request_Reject"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "members_Delete",
			value: $("#sc_members_Delete").val(),
			conditions: $("#scc_members_Delete").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "members_Delete"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "EditProperty",
			value: $("#sc_EditProperty").val(),
			conditions: $("#scc_EditProperty").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "EditProperty"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingIncAcceptOther",
			value: $("#sc_votingIncAcceptOther").val(),
			conditions: $("#scc_votingIncAcceptOther").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingIncAcceptOther"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "chat_notification_close",
			value: $("#sc_chat_notification_close").val(),
			conditions: $("#scc_chat_notification_close").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "chat_notification_close"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "EditLand",
			value: $("#sc_EditLand").val(),
			conditions: $("#scc_EditLand").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "EditLand"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "members_Request_Accept",
			value: $("#sc_members_Request_Accept").val(),
			conditions: $("#scc_members_Request_Accept").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "members_Request_Accept"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingInvite",
			value: $("#sc_votingInvite").val(),
			conditions: $("#scc_votingInvite").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingInvite"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "notification_roles_send",
			value: $("#sc_notification_roles_send").val(),
			conditions: $("#scc_notification_roles_send").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "notification_roles_send"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingSubjectRole",
			value: $("#sc_votingSubjectRole").val(),
			conditions: $("#scc_votingSubjectRole").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingSubjectRole"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingSubjectApply",
			value: $("#sc_votingSubjectApply").val(),
			conditions: $("#scc_votingSubjectApply").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingSubjectApply"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "tokens_Close",
			value: $("#sc_tokens_Close").val(),
			conditions: $("#scc_tokens_Close").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "tokens_Close"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "notification_role_processing",
			value: $("#sc_notification_role_processing").val(),
			conditions: $("#scc_notification_role_processing").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "notification_role_processing"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "members_Return",
			value: $("#sc_members_Return").val(),
			conditions: $("#scc_members_Return").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "members_Return"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "tokens_Emission",
			value: $("#sc_tokens_Emission").val(),
			conditions: $("#scc_tokens_Emission").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "tokens_Emission"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "PropertyAcceptOffers",
			value: $("#sc_PropertyAcceptOffers").val(),
			conditions: $("#scc_PropertyAcceptOffers").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "PropertyAcceptOffers"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingDecideDecision",
			value: $("#sc_votingDecideDecision").val(),
			conditions: $("#scc_votingDecideDecision").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingDecideDecision"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "tokens_Money_Transfer_extra",
			value: $("#sc_tokens_Money_Transfer_extra").val(),
			conditions: $("#scc_tokens_Money_Transfer_extra").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "tokens_Money_Transfer_extra"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "tokens_SearchCitizen",
			value: $("#sc_tokens_SearchCitizen").val(),
			conditions: $("#scc_tokens_SearchCitizen").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "tokens_SearchCitizen"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "notification_single_send",
			value: $("#sc_notification_single_send").val(),
			conditions: $("#scc_notification_single_send").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "notification_single_send"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingSearch",
			value: $("#sc_votingSearch").val(),
			conditions: $("#scc_votingSearch").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingSearch"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "PropertyRegistryChange",
			value: $("#sc_PropertyRegistryChange").val(),
			conditions: $("#scc_PropertyRegistryChange").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "PropertyRegistryChange"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "notification_single_close",
			value: $("#sc_notification_single_close").val(),
			conditions: $("#scc_notification_single_close").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "notification_single_close"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingDecideDocument",
			value: $("#sc_votingDecideDocument").val(),
			conditions: $("#scc_votingDecideDocument").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingDecideDocument"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "notification_role_close",
			value: $("#sc_notification_role_close").val(),
			conditions: $("#scc_notification_role_close").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "notification_role_close"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingSubjectDocument",
			value: $("#sc_votingSubjectDocument").val(),
			conditions: $("#scc_votingSubjectDocument").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingSubjectDocument"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingCreateNew",
			value: $("#sc_votingCreateNew").val(),
			conditions: $("#scc_votingCreateNew").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingCreateNew"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingIncAcceptCandidate",
			value: $("#sc_votingIncAcceptCandidate").val(),
			conditions: $("#scc_votingIncAcceptCandidate").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingIncAcceptCandidate"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingDecideCandidates",
			value: $("#sc_votingDecideCandidates").val(),
			conditions: $("#scc_votingDecideCandidates").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingDecideCandidates"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "notification_send",
			value: $("#sc_notification_send").val(),
			conditions: $("#scc_notification_send").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "notification_send"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "TXEditProfile",
			value: $("#sc_TXEditProfile").val(),
			conditions: $("#scc_TXEditProfile").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "TXEditProfile"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingUpdateDataForGraphs",
			value: $("#sc_votingUpdateDataForGraphs").val(),
			conditions: $("#scc_votingUpdateDataForGraphs").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingUpdateDataForGraphs"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingAcceptDecision",
			value: $("#sc_votingAcceptDecision").val(),
			conditions: $("#scc_votingAcceptDecision").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingAcceptDecision"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "tokens_EmissionAdd",
			value: $("#sc_tokens_EmissionAdd").val(),
			conditions: $("#scc_tokens_EmissionAdd").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "tokens_EmissionAdd"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingCheckDecision",
			value: $("#sc_votingCheckDecision").val(),
			conditions: $("#scc_votingCheckDecision").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingCheckDecision"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "tokens_Money_Rollback",
			value: $("#sc_tokens_Money_Rollback").val(),
			conditions: $("#scc_tokens_Money_Rollback").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "tokens_Money_Rollback"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "PropertySendOffer",
			value: $("#sc_PropertySendOffer").val(),
			conditions: $("#scc_PropertySendOffer").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "PropertySendOffer"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "tokens_Money_Transfer",
			value: $("#sc_tokens_Money_Transfer").val(),
			conditions: $("#scc_tokens_Money_Transfer").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "tokens_Money_Transfer"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingAcceptCandidates",
			value: $("#sc_votingAcceptCandidates").val(),
			conditions: $("#scc_votingAcceptCandidates").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingAcceptCandidates"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "TXCitizenRequest",
			value: $("#sc_TXCitizenRequest").val(),
			conditions: $("#scc_TXCitizenRequest").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "TXCitizenRequest"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingAcceptDocument",
			value: $("#sc_votingAcceptDocument").val(),
			conditions: $("#scc_votingAcceptDocument").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingAcceptDocument"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "roles_Add",
			value: $("#sc_roles_Add").val(),
			conditions: $("#scc_roles_Add").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "roles_Add"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingRejectDecision",
			value: $("#sc_votingRejectDecision").val(),
			conditions: $("#scc_votingRejectDecision").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingRejectDecision"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "roles_Assign",
			value: $("#sc_roles_Assign").val(),
			conditions: $("#scc_roles_Assign").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "roles_Assign"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingRejectDocument",
			value: $("#sc_votingRejectDocument").val(),
			conditions: $("#scc_votingRejectDocument").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingRejectDocument"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "roles_Del",
			value: $("#sc_roles_Del").val(),
			conditions: $("#scc_roles_Del").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "roles_Del"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingSendNotifics",
			value: $("#sc_votingSendNotifics").val(),
			conditions: $("#scc_votingSendNotifics").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingSendNotifics"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "roles_Search",
			value: $("#sc_roles_Search").val(),
			conditions: $("#scc_roles_Search").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "roles_Search"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingSubjectCandidates",
			value: $("#sc_votingSubjectCandidates").val(),
			conditions: $("#scc_votingSubjectCandidates").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingSubjectCandidates"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "roles_UnAssign",
			value: $("#sc_roles_UnAssign").val(),
			conditions: $("#scc_roles_UnAssign").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "roles_UnAssign"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingSubjectFormal",
			value: $("#sc_votingSubjectFormal").val(),
			conditions: $("#scc_votingSubjectFormal").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingSubjectFormal"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "tokens_Account_Add",
			value: $("#sc_tokens_Account_Add").val(),
			conditions: $("#scc_tokens_Account_Add").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "tokens_Account_Add"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "votingSubjectVacancies",
			value: $("#sc_votingSubjectVacancies").val(),
			conditions: $("#scc_votingSubjectVacancies").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "votingSubjectVacancies"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "tokens_Account_Close",
			value: $("#sc_tokens_Account_Close").val(),
			conditions: $("#scc_tokens_Account_Close").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "tokens_Account_Close"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "AddLand",
			value: $("#sc_AddLand").val(),
			conditions: $("#scc_AddLand").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "AddLand"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewContract",
			typeid: #type_new_contract_id#,
			global: 0,
			name: "tokens_CheckingClose",
			value: $("#sc_tokens_CheckingClose").val(),
			conditions: $("#scc_tokens_CheckingClose").val()
			}
	   },
{
		Forsign: 'global,id',
		Data: {
			type: "ActivateContract",
			typeid: #type_activate_contract_id#,
			global: 0,
			id: "tokens_CheckingClose"
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewSign",
			typeid: #type_new_sign_id#,
			global: 0,
			name: "tokens_Money_Transfer",
			value: $("#sign_tokens_Money_Transfer").val(),
			conditions: $("#signc_tokens_Money_Transfer").val()
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "buildings_use_class",
			value: $("#pa_buildings_use_class").val(),
			conditions: $("#pac_buildings_use_class").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "changing_language",
			value: $("#pa_changing_language").val(),
			conditions: $("#pac_changing_language").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "changing_menu",
			value: $("#pa_changing_menu").val(),
			conditions: $("#pac_changing_menu").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "changing_page",
			value: $("#pa_changing_page").val(),
			conditions: $("#pac_changing_page").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "changing_signature",
			value: $("#pa_changing_signature").val(),
			conditions: $("#pac_changing_signature").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "changing_smart_contracts",
			value: $("#pa_changing_smart_contracts").val(),
			conditions: $("#pac_changing_smart_contracts").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "changing_tables",
			value: $("#pa_changing_tables").val(),
			conditions: $("#pac_changing_tables").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "citizenship_price",
			value: $("#pa_citizenship_price").val(),
			conditions: $("#pac_citizenship_price").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "currency_name",
			value: $("#pa_currency_name").val(),
			conditions: $("#pac_currency_name").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "dlt_spending",
			value: $("#pa_dlt_spending").val(),
			conditions: $("#pac_dlt_spending").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "gender_list",
			value: $("#pa_gender_list").val(),
			conditions: $("#pac_gender_list").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "gov_account",
			value: $("#pa_gov_account").val(),
			conditions: $("#pac_gov_account").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "land_use",
			value: $("#pa_land_use").val(),
			conditions: $("#pac_land_use").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "members_request_status",
			value: $("#pa_members_request_status").val(),
			conditions: $("#pac_members_request_status").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "money_digit",
			value: $("#pa_money_digit").val(),
			conditions: $("#pac_money_digit").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "new_column",
			value: $("#pa_new_column").val(),
			conditions: $("#pac_new_column").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "new_table",
			value: $("#pa_new_table").val(),
			conditions: $("#pac_new_table").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "notification_ClosureType",
			value: $("#pa_notification_ClosureType").val(),
			conditions: $("#pac_notification_ClosureType").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "notification_icon",
			value: $("#pa_notification_icon").val(),
			conditions: $("#pac_notification_icon").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "property_types",
			value: $("#pa_property_types").val(),
			conditions: $("#pac_property_types").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "restore_access_condition",
			value: $("#pa_restore_access_condition").val(),
			conditions: $("#pac_restore_access_condition").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "roles_types",
			value: $("#pa_roles_types").val(),
			conditions: $("#pac_roles_types").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "state_coords",
			value: $("#pa_state_coords").val(),
			conditions: $("#pac_state_coords").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "state_flag",
			value: $("#pa_state_flag").val(),
			conditions: $("#pac_state_flag").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "state_name",
			value: $("#pa_state_name").val(),
			conditions: $("#pac_state_name").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "tokens_accounts_type",
			value: $("#pa_tokens_accounts_type").val(),
			conditions: $("#pac_tokens_accounts_type").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "tokens_rollback_tokens",
			value: $("#pa_tokens_rollback_tokens").val(),
			conditions: $("#pac_tokens_rollback_tokens").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "tokens_type_emission",
			value: $("#pa_tokens_type_emission").val(),
			conditions: $("#pac_tokens_type_emission").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "tx_fiat_limit",
			value: $("#pa_tx_fiat_limit").val(),
			conditions: $("#pac_tx_fiat_limit").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "type_voting",
			value: $("#pa_type_voting").val(),
			conditions: $("#pac_type_voting").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "type_voting_decisions",
			value: $("#pa_type_voting_decisions").val(),
			conditions: $("#pac_type_voting_decisions").val(),
			}
	   },
{
		Forsign: 'name,value,conditions',
		Data: {
			type: "NewStateParameters",
			typeid: #type_new_state_params_id#,
			name : "type_voting_participants",
			value: $("#pa_type_voting_participants").val(),
			conditions: $("#pac_type_voting_participants").val(),
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewMenu",
			typeid: #type_new_menu_id#,
			name : "government",
			value: $("#m_government").val(),
			global: 0,
			conditions: $("#mc_government").val()
			}
	   },
{
		Forsign: 'global,name,value,conditions',
		Data: {
			type: "NewMenu",
			typeid: #type_new_menu_id#,
			name : "menu_default",
			value: $("#m_menu_default").val(),
			global: 0,
			conditions: $("#mc_menu_default").val()
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "AddLand",
			menu: "menu_default",
			value: $("#p_AddLand").val(),
			global: 0,
			conditions: $("#pc_AddLand").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "AddProperty",
			menu: "menu_default",
			value: $("#p_AddProperty").val(),
			global: 0,
			conditions: $("#pc_AddProperty").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "Chat_history",
			menu: "menu_default",
			value: $("#p_Chat_history").val(),
			global: 0,
			conditions: $("#pc_Chat_history").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "chat_IncomingRoleMessages",
			menu: "menu_default",
			value: $("#p_chat_IncomingRoleMessages").val(),
			global: 0,
			conditions: $("#pc_chat_IncomingRoleMessages").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "CitizenInfo",
			menu: "menu_default",
			value: $("#p_CitizenInfo").val(),
			global: 0,
			conditions: $("#pc_CitizenInfo").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "citizen_profile",
			menu: "menu_default",
			value: $("#p_citizen_profile").val(),
			global: 0,
			conditions: $("#pc_citizen_profile").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "dashboard_default",
			menu: "menu_default",
			value: $("#p_dashboard_default").val(),
			global: 0,
			conditions: $("#pc_dashboard_default").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "EditLand",
			menu: "menu_default",
			value: $("#p_EditLand").val(),
			global: 0,
			conditions: $("#pc_EditLand").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "EditProperty",
			menu: "menu_default",
			value: $("#p_EditProperty").val(),
			global: 0,
			conditions: $("#pc_EditProperty").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "government",
			menu: "government",
			value: $("#p_government").val(),
			global: 0,
			conditions: $("#pc_government").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "LandHistory",
			menu: "menu_default",
			value: $("#p_LandHistory").val(),
			global: 0,
			conditions: $("#pc_LandHistory").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "LandObject",
			menu: "menu_default",
			value: $("#p_LandObject").val(),
			global: 0,
			conditions: $("#pc_LandObject").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "LandObjectContract",
			menu: "menu_default",
			value: $("#p_LandObjectContract").val(),
			global: 0,
			conditions: $("#pc_LandObjectContract").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "LandRegistry",
			menu: "menu_default",
			value: $("#p_LandRegistry").val(),
			global: 0,
			conditions: $("#pc_LandRegistry").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "MemberEdit",
			menu: "menu_default",
			value: $("#p_MemberEdit").val(),
			global: 0,
			conditions: $("#pc_MemberEdit").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "MemberManage",
			menu: "menu_default",
			value: $("#p_MemberManage").val(),
			global: 0,
			conditions: $("#pc_MemberManage").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "members_list",
			menu: "menu_default",
			value: $("#p_members_list").val(),
			global: 0,
			conditions: $("#pc_members_list").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "members_request_edit",
			menu: "menu_default",
			value: $("#p_members_request_edit").val(),
			global: 0,
			conditions: $("#pc_members_request_edit").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "MyChats",
			menu: "menu_default",
			value: $("#p_MyChats").val(),
			global: 0,
			conditions: $("#pc_MyChats").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "notification",
			menu: "menu_default",
			value: $("#p_notification").val(),
			global: 0,
			conditions: $("#pc_notification").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "notification_send_roles",
			menu: "menu_default",
			value: $("#p_notification_send_roles").val(),
			global: 0,
			conditions: $("#pc_notification_send_roles").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "notification_send_single",
			menu: "menu_default",
			value: $("#p_notification_send_single").val(),
			global: 0,
			conditions: $("#pc_notification_send_single").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "notification_testpage",
			menu: "menu_default",
			value: $("#p_notification_testpage").val(),
			global: 0,
			conditions: $("#pc_notification_testpage").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "notification_view_roles",
			menu: "menu_default",
			value: $("#p_notification_view_roles").val(),
			global: 0,
			conditions: $("#pc_notification_view_roles").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "notification_view_single",
			menu: "menu_default",
			value: $("#p_notification_view_single").val(),
			global: 0,
			conditions: $("#pc_notification_view_single").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "Property",
			menu: "menu_default",
			value: $("#p_Property").val(),
			global: 0,
			conditions: $("#pc_Property").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "PropertyDetails",
			menu: "menu_default",
			value: $("#p_PropertyDetails").val(),
			global: 0,
			conditions: $("#pc_PropertyDetails").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "property_list",
			menu: "0",
			value: $("#p_property_list").val(),
			global: 0,
			conditions: $("#pc_property_list").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "roles_assign",
			menu: "menu_default",
			value: $("#p_roles_assign").val(),
			global: 0,
			conditions: $("#pc_roles_assign").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "roles_create",
			menu: "menu_default",
			value: $("#p_roles_create").val(),
			global: 0,
			conditions: $("#pc_roles_create").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "roles_list",
			menu: "menu_default",
			value: $("#p_roles_list").val(),
			global: 0,
			conditions: $("#pc_roles_list").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "roles_view",
			menu: "menu_default",
			value: $("#p_roles_view").val(),
			global: 0,
			conditions: $("#pc_roles_view").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "tokens_accounts_add",
			menu: "menu_default",
			value: $("#p_tokens_accounts_add").val(),
			global: 0,
			conditions: $("#pc_tokens_accounts_add").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "tokens_accounts_list",
			menu: "menu_default",
			value: $("#p_tokens_accounts_list").val(),
			global: 0,
			conditions: $("#pc_tokens_accounts_list").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "tokens_create",
			menu: "menu_default",
			value: $("#p_tokens_create").val(),
			global: 0,
			conditions: $("#pc_tokens_create").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "tokens_emission",
			menu: "menu_default",
			value: $("#p_tokens_emission").val(),
			global: 0,
			conditions: $("#pc_tokens_emission").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "tokens_list",
			menu: "menu_default",
			value: $("#p_tokens_list").val(),
			global: 0,
			conditions: $("#pc_tokens_list").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "tokens_money_rollback",
			menu: "menu_default",
			value: $("#p_tokens_money_rollback").val(),
			global: 0,
			conditions: $("#pc_tokens_money_rollback").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "tokens_money_transfer",
			menu: "menu_default",
			value: $("#p_tokens_money_transfer").val(),
			global: 0,
			conditions: $("#pc_tokens_money_transfer").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "tokens_money_transfer_agency",
			menu: "menu_default",
			value: $("#p_tokens_money_transfer_agency").val(),
			global: 0,
			conditions: $("#pc_tokens_money_transfer_agency").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "tokens_money_transfer_company",
			menu: "menu_default",
			value: $("#p_tokens_money_transfer_company").val(),
			global: 0,
			conditions: $("#pc_tokens_money_transfer_company").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "tokens_money_transfer_person",
			menu: "menu_default",
			value: $("#p_tokens_money_transfer_person").val(),
			global: 0,
			conditions: $("#pc_tokens_money_transfer_person").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "voting_create",
			menu: "menu_default",
			value: $("#p_voting_create").val(),
			global: 0,
			conditions: $("#pc_voting_create").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "voting_decision_candidates",
			menu: "menu_default",
			value: $("#p_voting_decision_candidates").val(),
			global: 0,
			conditions: $("#pc_voting_decision_candidates").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "voting_decision_document",
			menu: "menu_default",
			value: $("#p_voting_decision_document").val(),
			global: 0,
			conditions: $("#pc_voting_decision_document").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "voting_decision_election",
			menu: "menu_default",
			value: $("#p_voting_decision_election").val(),
			global: 0,
			conditions: $("#pc_voting_decision_election").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "voting_decision_formal",
			menu: "menu_default",
			value: $("#p_voting_decision_formal").val(),
			global: 0,
			conditions: $("#pc_voting_decision_formal").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "voting_invite",
			menu: "menu_default",
			value: $("#p_voting_invite").val(),
			global: 0,
			conditions: $("#pc_voting_invite").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "voting_list",
			menu: "menu_default",
			value: $("#p_voting_list").val(),
			global: 0,
			conditions: $("#pc_voting_list").val(),
			}
	   },
{
		Forsign: 'global,name,value,menu,conditions',
		Data: {
			type: "NewPage",
			typeid: #type_new_page_id#,
			name : "voting_view",
			menu: "menu_default",
			value: $("#p_voting_view").val(),
			global: 0,
			conditions: $("#pc_voting_view").val(),
			}
	   },
{
				Forsign: 'name,trans',
				Data: {
					type: "NewLang",
					typeid: #type_new_lang_id#,
					name : "",
					trans: $("#l_lang").val(),
					}
				}]`
)
