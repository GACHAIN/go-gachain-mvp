SetVar(
	global = 0,
	typeid = TxId(EditContract),
	typecolid = TxId(NewColumn),
	type_new_page_id = TxId(NewPage),
	type_append_page_id = TxId(AppendPage),
	type_new_menu_id = TxId(NewMenu),
	type_edit_menu_id = TxId(EditMenu),
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
            DBInsert(Table("citizens"), "id,person_status,block_id,name,timestamp date_start,date_expiration", $wallet_id, $PersonStatus, $block, $RequestName,$block_time,$DateExpiration)  
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
}

`,
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
TextHidden( sc_AddLand, scc_AddLand, sc_AddProperty, scc_AddProperty, sc_chat_notification_close, scc_chat_notification_close, sc_chat_reply_to_message, scc_chat_reply_to_message, sc_chat_send_private_message, scc_chat_send_private_message, sc_CitizenCondition, scc_CitizenCondition, sc_EditLand, scc_EditLand, sc_EditProperty, scc_EditProperty, sc_LandBuyContract, scc_LandBuyContract, sc_LandSaleContract, scc_LandSaleContract, sc_members_Change_Status, scc_members_Change_Status, sc_members_Delete, scc_members_Delete, sc_members_Request_Accept, scc_members_Request_Accept, sc_members_Request_Reject, scc_members_Request_Reject, sc_members_Return, scc_members_Return, sc_notification_role_close, scc_notification_role_close, sc_notification_role_processing, scc_notification_role_processing, sc_notification_roles_send, scc_notification_roles_send, sc_notification_send, scc_notification_send, sc_notification_single_close, scc_notification_single_close, sc_notification_single_send, scc_notification_single_send, sc_PropertyAcceptOffers, scc_PropertyAcceptOffers, sc_PropertyRegistryChange, scc_PropertyRegistryChange, sc_PropertySendOffer, scc_PropertySendOffer, sc_roles_Add, scc_roles_Add, sc_roles_Assign, scc_roles_Assign, sc_roles_Del, scc_roles_Del, sc_roles_Search, scc_roles_Search, sc_roles_UnAssign, scc_roles_UnAssign, sc_tokens_Account_Add, scc_tokens_Account_Add, sc_tokens_Account_Close, scc_tokens_Account_Close, sc_tokens_CheckingClose, scc_tokens_CheckingClose, sc_tokens_Close, scc_tokens_Close, sc_tokens_Emission, scc_tokens_Emission, sc_tokens_EmissionAdd, scc_tokens_EmissionAdd, sc_tokens_Money_Rollback, scc_tokens_Money_Rollback, sc_tokens_Money_Transfer, scc_tokens_Money_Transfer, sc_tokens_Money_Transfer_extra, scc_tokens_Money_Transfer_extra, sc_tokens_SearchCitizen, scc_tokens_SearchCitizen, sc_TXCitizenRequest, scc_TXCitizenRequest, sc_TXEditProfile, scc_TXEditProfile, sc_votingAcceptCandidates, scc_votingAcceptCandidates, sc_votingAcceptDecision, scc_votingAcceptDecision, sc_votingAcceptDocument, scc_votingAcceptDocument, sc_votingCheckDecision, scc_votingCheckDecision, sc_votingCreateNew, scc_votingCreateNew, sc_votingDecideCandidates, scc_votingDecideCandidates, sc_votingDecideDecision, scc_votingDecideDecision, sc_votingDecideDocument, scc_votingDecideDocument, sc_votingDelete, scc_votingDelete, sc_votingIncAcceptCandidate, scc_votingIncAcceptCandidate, sc_votingIncAcceptOther, scc_votingIncAcceptOther, sc_votingInvite, scc_votingInvite, sc_votingRejectDecision, scc_votingRejectDecision, sc_votingRejectDocument, scc_votingRejectDocument, sc_votingSearch, scc_votingSearch, sc_votingSendNotifics, scc_votingSendNotifics, sc_votingSubjectApply, scc_votingSubjectApply, sc_votingSubjectCandidates, scc_votingSubjectCandidates, sc_votingSubjectDocument, scc_votingSubjectDocument, sc_votingSubjectFormal, scc_votingSubjectFormal, sc_votingSubjectRole, scc_votingSubjectRole, sc_votingSubjectVacancies, scc_votingSubjectVacancies, sc_votingUpdateDataForGraphs, scc_votingUpdateDataForGraphs)
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
Navigation(LiTemplate(LandRegistry, Land Registry), Add land)
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
                Label("Owner")
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
`p_chat_IncomingRoleMessages #= Title: Role messages

Navigation(LiTemplate(MyChats, LangJS(my_chats)), Role messages)

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
            Tag(h3, If(GetVar(user_name)!=="", #user_name#, Anonym), m0)
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
`p_citizen_profile #= Title:Profile
Navigation(LiTemplate(dashboard_default, Dashboard),Editing profile)

GetRow("user", #state_id#_citizens, "id", #citizen#)

Divs(md-12, panel panel-default elastic data-sweet-alert)
    Divs(panel-body)
        Form()
            Divs(form-group)
                Label($name_first$)
                Input(name_first, "form-control input-lg m-b",text,"", #user_name#)
                Label($name_last$)
                Input(name_last, "form-control input-lg m-b",text,"", #user_name_last#)
                
            DivsEnd:
            Divs(form-group)
                Label("gender")
                Select(gender,gender_list,form-control input-lg,#user_gender#)
            DivsEnd:
            Divs(form-group)
                Label("photo", d-block)
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
                TxButton{ClassBtn:btn btn-primary, Contract:TXEditProfile,Name:Save, OnSuccess: MenuReload()}
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_citizen_profile #= ContractConditions("MainCondition")`,
`p_dashboard_default #= FullScreen(1)

Navigation(LiTemplate(dashboard_default, Citizen))

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
                Tag(h3, Date(GetOne(date_founded,global_states_list,gstate_id=#state_id#),DD.MM.YYYY), m0)
                P(m0 text-muted, Founded)
            DivsEnd:
            Divs: col-xs-4
                Tag(h3,  GetOne(name_tokens, #state_id#_accounts_tokens#, "delete=0"), m0)
                P(m0 text-muted, Tokens)
            DivsEnd:
            Divs: col-xs-4
                Tag(h3, GetOne(count(*),#state_id#_citizens), m0)
                P(m0 text-muted, Members)
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
                            Div(h4 m0 text-bold text-uppercase, Voting)
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
                            Div(h4 m0 text-bold text-uppercase, Members)
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
                            Div(h4 m0 text-bold text-uppercase, Roles)
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
    Div(panel-heading, Div(panel-title, Div(text-bold, Voting) ))
    Divs: panel-body text-center
        Divs(table-responsive)
            Table {
            	Table: #state_id#_voting_instances
            	Class: table-striped table-hover
            	Order: id
            	Columns: [
            	    [ID, Div(text-center, #id#), text-center h4 align="center" width="50" ],
            		[Name, Div(text-bold, LinkPage(voting_view, #name#, "vID:#id#",pointer) ), text-center h4 align="center"],
            		[End date, Div(text-center, DateTime(#enddate#, DD.MM.YYYY HH:MI)), text-center h4 align="center"]
            	]
            }
        DivsEnd:
    DivsEnd:
DivsEnd:

Divs(md-6, panel panel-default elastic data-sweet-alert)
    Div(panel-heading, Div(panel-title, Div(text-bold, Roles) ))
    Divs: panel-body text-center
        Divs(table-responsive)
        Table{
            Table: #state_id#_roles_assign
            Class: table-striped table-hover
            Order: "delete ASC, id ASC"
            Columns:  
            [
                [ ID,  SetVar(style=If(#delete#==0,"text-normal","text-muted")) Div(text-center #style#, #id#), text-center h4 align="center" width="50" ],
                [ Role name, Div(text-bold #style#, #role_name# ), text-center h4 align="center"],
                [ Member, SetVar(citizens_avatar=GetOne(avatar, #state_id#_citizens#, "id",  #member_id#))  Div(text-bold #style#, Image(If(GetVar(citizens_avatar)!=="", #citizens_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30), &nbsp #member_name#), text-center h4 align="center"]
            ]
        }
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_dashboard_default #= ContractConditions("MainCondition")`,
`p_EditLand #= Title:Edit Land
Navigation(LiTemplate(LandRegistry, Land Registry),Edit Land)

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
                TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract: EditLand,Name: Save, OnSuccess: "template,LandRegistry"}
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

Title :  Land Registry
Navigation(Land Registry)

Divs(md-12, panel panel-default data-sweet-alert)
    Divs(panel-body)
        Divs(table-responsive)
            Table {
                Class: table-striped table-bordered table-hover data-role="table"
                Table: #state_id#_land_registry
                Order: id
                Columns: [[ID, #id#], [Land Use, StateVal(land_use, #land_use#)], [Buildings use class, StateVal(buildings_use_class, #buildings_use_class#)], [Map, Map(#coords#,maptype=satellite hmap=100), width="200"], [Address, #address#],[Area Sq m, #area#], [Edit,BtnPage(EditLand, Edit,"LandId:#id#")],[View,BtnPage(LandObject, View,"LandId:#id#")]]
            }
        DivsEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs: clearfix
            Divs: pull-right
                BtnPage(LandHistory, History, '',btn btn-pill-left btn-default)
                BtnPage(AddLand, Add Land, '',btn btn-pill-right btn-primary)
            DivsEnd:
        DivsEnd:
    DivsEnd:
DivsEnd:

PageEnd:`,
`pc_LandRegistry #= ContractConditions("MainCondition")`,
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
    Div(panel-heading, Div(panel-title, "Membership request"))
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
                [Name, Div(text-bold,#name#), h4],
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
Navigation(LiTemplate(members_list,Members), If(#isChange#==1, LangJS(change), LangJS(accept)))

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
                                BtnContract(members_Request_Accept,$accept$, 确认接受 #vMemberName# 的申请?,"RequestId:Val(MemberID),PersonStatus:Val(MemberStatus),RequestName:Val(MemberName),DateExpiration:Val(DateExpiration),isDateExpiration:Val(isDateExpiration)",'btn btn-success btn-pill-right',template,members_list)
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
                BtnPage(notification_send_roles, LangJS(send), "",  btn btn-primary)
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
`p_roles_create #= Title:New role
Navigation(LiTemplate(roles_list, Roles), New role) 

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, New role))
                Divs(panel-body)
                    Form()
                        Divs(form-group)
                            Label("Name")
                            Input(position_name, "form-control  m-b ",Name,text)
                        DivsEnd:
                        Divs(form-group)
                            Label("Type")
                            Select(position_type,roles_types,form-control)
                        DivsEnd:
                    FormEnd:
                DivsEnd:
                Divs(panel-footer)
                    Divs: clearfix
                        Divs: pull-right
                            BtnPage(roles_list, "Back", "", btn btn-default btn-pill-left ml4)
                            TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:roles_Add,Name:"Create", OnSuccess: "template,roles_list"}
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
`p_roles_list #= Title:Roles
Navigation(Roles)
   
AutoUpdate(2)
Include(notification)
AutoUpdateEnd:

If(#isSearch#==1)
    SetVar(vWhere="role_name = '#RoleName#'")
Else:
    SetVar(vWhere="id <> 0")
IfEnd:
        
Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, "Roles"))
    Divs(panel-body)
        Divs: row df f-valign
			Divs: col-md-1 mt-sm text-right
			    Div(text-bold, "Name:")
            DivsEnd:
			Divs: col-md-10 mt-sm text-left
                Input(StrSearch, "form-control  m-b")
            DivsEnd:
            Divs: col-md-1 mt-sm
                TxButton { Contract:roles_Search, Name: Search, OnSuccess: "template,roles_list,RoleName:Val(StrSearch),isSearch:1" }
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
                [ Role name, If(#delete#==0, Div(#style# text-bold, LinkPage(roles_view, #role_name#, "RoleName:'#role_name#',isSearch:1",profile-flag text-blue) ), Div(#style#, #role_name# )), h4],
                [ Type, Div(text-center text-bold #style#, StateVal(roles_types,#role_type#)),  text-center h4 align="center" width="80" ],
                [ Creator, Div(text-center text-bold #style#, #creator_name#), text-center h4 align="center" ],
                [ Date create, Div(text-center #style#, DateTime(#date_create#, DD.MM.YYYY HH:MI) ), text-center h4 align="center" width="125" ],
                [ Date delete, Div(text-center #style#, DateTime(#date_delete#, DD.MM.YYYY HH:MI) ), text-center h4 align="center" width="125" ],
                [ Status, If(#delete#==0, Div(text-center text-bold #style#,"Active"), Div(text-center text-bold #style#, "Deleted")), text-center h4 align="center" width="65" ],
                [ , If(#delete#==0, BtnPage(roles_assign, Em(fa fa-plus), "vID:#id#", btn btn-success),""), text-center align="center" width="60" ],
                [ , If(#delete#==0, BtnContract(roles_Del, Em(fa fa-close), Do you want to delete this role?,"IDRole:#id#",'btn btn-danger btn-block',template,roles_list),""), text-center align="center" width="60" ]
            ]
        }
        DivsEnd:
        If(#isSearch#==1)
            Div(h4 m0 text-bold text-left, <br>)
            Divs(text-center)
                    BtnPage(roles_list, <b>View all</b>,"isSearch:0",btn btn-primary btn-oval)
            DivsEnd:
        IfEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs:clearfix 
            Divs: pull-left
            DivsEnd:
            Divs: pull-right
                BtnPage(roles_create, Add role, "",  btn btn-primary)
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

Navigation(LiTemplate(roles_list, Roles), Assigned) 
        
Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, "Assigned"))
    Divs(panel-body)
        Divs: row df f-valign
			Divs: col-md-1 mt-sm text-right
			    Div(text-bold, "Role:")
            DivsEnd:
			Divs: col-md-10 mt-sm text-left
			    If(#isSearch#==1)
                    Input(StrSearch, "form-control  m-b", text, text, #RoleName#)
                Else:
                    Input(StrSearch, "form-control  m-b")
                IfEnd:
            DivsEnd:
            Divs: col-md-1 mt-sm
                TxButton { Contract:roles_Search, Name: Search, OnSuccess: "template,roles_view,RoleName:Val(StrSearch),isSearch:1" }
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
                [ Role name, Div(text-bold #style#, #role_name# ), text-center h4 align="center"],
                [ Type, Div(text-center #style#, SetVar(role_type = GetOne(role_type, #state_id#_roles_list#, "id", #role_id#)) StateVal(roles_types, #role_type# ) ), text-center h4 align="center" width="65"],
                [ Member, SetVar(citizens_avatar=GetOne(avatar, #state_id#_citizens#, "id",  #member_id#))  Div(text-bold #style#, Image(If(GetVar(citizens_avatar)!=="", #citizens_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30),   #member_name#), text-center h4 align="center" ],
                [ Date start, Div(text-center #style#, DateTime(#date_start#, DD.MM.YYYY HH:MI) ), text-center h4 align="center" width="125" ],
                [ Date end, Div(text-center #style#, DateTime(#date_end#, DD.MM.YYYY HH:MI) ), text-center h4 align="center" width="125" ],
                [ Appointed, Div(text-center #style#, #appointed_by_name# ), text-center h4 align="center"],
                [ Status, Div(text-bold text-center #style#, If(#delete#==0, If(#role_type#==1, "Assigned", If(#appointed_by_id# ==0,"Waiting","Elective") ), "Deleted") ), text-center h4 align="center" width="65" ],
                [ , If(#delete#==0, BtnContract(roles_UnAssign, Em(fa fa-close), Are you sure you want to delete this member from the role?,"assignID:#id#",'btn btn-danger btn-block',template,roles_view),""), text-center align="center" width="60" ]    
            ]
        }
        DivsEnd:
        If(#isSearch#==1)
            Div(h4 m0 text-bold text-left, <br>)
            Divs(text-center)
                    BtnPage(roles_view, <b>View all</b>,"isSearch:0",btn btn-primary btn-oval)
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
                                TxButton{ClassBtn:btn btn-primary btn-pill-right, Contract:tokens_Emission,Name:"Execute", Inputs:"NameTokens=NameTokens,TypeEmission=TypeEmission,RollbackTokens=RollbackTokens,Amount=Amount,isDateExpiration=isDateExpiration,DateExpiration=isDateExpiration",OnSuccess: "template,tokens_list"}
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
                    [ Name,  Div(text-left text-bold #style#, #name_tokens#), h4 ],
                    [ Rollback tokens, Div(text-bold #style#, StateVal(tokens_rollback_tokens,#flag_rollback_tokens#) ), h4 ],
                    [ Date create,  Div(#style# text-center, DateTime(#date_create#, YYYY.MM.DD HH:MI) ), text-center h4 align="center" width="130" ],
                    [ Expiration, If(#date_expiration#, Div(#style# text-center, DateTime(#date_expiration#, YYYY.MM.DD HH:MI)), Div(#style# text-center, LangJS(not_limited))), text-center h4 align="center" width="130"],
                    [ Status, If(#delete#==0, Div(text-bold text-center #style#, "Active") ,  Div(text-bold text-center #style#, "Closed") ), text-center h4 align="center" width="80" ],
                    [ Emission, Div(text-bold text-center #style#, If(#delete#==0, If(#type_emission#==2, BtnPage(tokens_emission, Em(fa fa-plus), "",  btn btn-success),StateVal(tokens_type_emission,#type_emission#)), StateVal(tokens_type_emission,#type_emission#)) ), text-center h4 align="center" width="130" ],
                    [ Amount,  Div(text-right text-bold #style#, Money(#amount#) ), text-center h4 align="center" width="130" ],
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
                            TxButton{ClassBtn:btn btn-primary, Contract:tokens_Money_Rollback,Name:"Rollback", Inputs:"AccountID=SenderAccountID,Amount=Amount",OnSuccess: "template,tokens_accounts_list"}
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
                            TxButton{ClassBtn:btn btn-primary, Contract:tokens_Money_Transfer_extra,Name:"Send", Inputs:"SenderAccountType#=person_acc,RecipientAccountID=RecipientAccountID,Amount=Amount",OnSuccess: "template,tokens_accounts_list"}
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
`p_voting_create #= Title: New voting
Navigation(LiTemplate(voting_list, Voting), New voting)

Divs:content-wrapper 
    Divs: row df f-valign
		Divs: col-md-3 mt-sm text-left 
        DivsEnd:
		Divs: col-md-6 mt-sm text-left
            Divs(md-6, panel panel-primary data-sweet-alert)
                Div(panel-heading, Div(panel-title, New voting))
                Form()
                    Divs(list-group-item)
                        Divs(form-group)
                            Label("Name")
                            Input(voting_name, "form-control  m-b ",Name,text, New voting)
                        DivsEnd: 
                    DivsEnd:
                    Divs(list-group-item)
                        Divs(form-group)
                            Label($voting_description$)
                            Textarea(description, form-control, "no")
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
                    				    [ Member, GetRow("member", #state_id#_citizens, "id", #member_id#) Div(text-bold,Image(If(GetVar(member_avatar)!=="", #member_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30), &nbsp #member_name#), h5],
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
                    				    [ Member, GetRow("member", #state_id#_citizens, "id", #member_id#) Div(text-bold,Image(If(GetVar(member_avatar)!=="", #member_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full h-30 w-30), &nbsp #member_name#), h5],
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
                                		[Member, Div("text-left",GetRow("citizens", #state_id#_citizens, "id", GetVar(member_id)) Div("",Image(If(GetVar(citizens_avatar)!=="",#citizens_avatar#,"/static/img/avatar.svg"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30), &nbsp  #citizens_name#)), h4],
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
                                        Div(h5 text-normal, Image(If(GetVar(citizen_avatar)!=="", #citizen_avatar#, "/static/img/apps/ava.png"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30), &nbsp #citizen_name#)
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
`p_voting_list #= Title: Voting
Navigation(Voting)

AutoUpdate(2)
Include(notification)
AutoUpdateEnd:

If(#isSearch#==1)
    SetVar(vWhere="name = '#StrSearch#' and delete = 0")
Else:
    SetVar(vWhere="delete = 0")
IfEnd:

Divs(md-12, panel panel-primary data-sweet-alert)
    Div(panel-heading, Div(panel-title, "Voting"))
    Divs(panel-body)
        Divs: row df f-valign
			Divs: col-md-1 mt-sm text-right
			    Div(text-bold, "Name:")
            DivsEnd:
			Divs: col-md-10 mt-sm text-left
                Input(StrSearch, "form-control  m-b")
            DivsEnd:
            Divs: col-md-1 mt-sm
                TxButton { Contract:votingSearch, Name: Search, OnSuccess: "template,voting_list,StrSearch:Val(StrSearch),isSearch:1" }
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
            		[Name, Div(text-bold, LinkPage(voting_view, #name#, "vID:#id#",pointer) ), h5],
            		[Subject of voting,  If(#vCmpStartDate#<0, StateVal("type_voting_decisions",#typedecision#), If(#typedecision#==1,LinkPage(voting_decision_candidates,StateVal("type_voting_decisions",#typedecision#),"vID:#id#",pointer)) If(#typedecision#==2,LinkPage(voting_decision_election,StateVal("type_voting_decisions",#typedecision#),"vID:#id#",pointer)) If(#typedecision#==3,LinkPage(voting_decision_document,StateVal("type_voting_decisions",#typedecision#),"vID:#id#",pointer)) If(#typedecision#==4,LinkPage(voting_decision_formal,StateVal("type_voting_decisions",#typedecision#),"vID:#id#",pointer)) ), text-center align="center" h5 width="220"],
                    [Participants, Div(text-center, If(#vCmpStartDate#<0, StateVal("type_voting_participants", #typeparticipants#), LinkPage(voting_invite, StateVal("type_voting_participants", #typeparticipants#), "vID:#id#",pointer) ) ), text-center h5 align="center" width="70"],
            		[Notifics,  Div(text-center, If(#flag_notifics#==1, Div(text-center, "yes"), If(And(#flag_success#!=1,#vCmpEndDate#>0,#vCmpStartDate#<0,#creator_id#==#citizen#), BtnContract(votingSendNotifics,LangJS(send), Do you want to send a notification to all the voters?,"votingID:'#id#'",'btn btn-primary',template,voting_list), Div(text-center, "no") ) ) ), text-center h5 align="center" width="70"],
            		[Creator, Div("text-left",GetRow("citizens", #state_id#_citizens, "id", GetVar(creator_id)) Div("",Image(If(GetVar(citizens_avatar)!=="",#citizens_avatar#,"/static/img/avatar.svg"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30), &nbsp  #citizens_name#)), text-center h5 align="center"],
            		[Start \ end date, If(#vCmpStartDate#<0, Div(text-muted text-center, DateTime(#startdate#, DD.MM.YYYY HH:MI) ), Div(text-bold text-center, DateTime(#startdate#, DD.MM.YYYY HH:MI) ) ) If(#vCmpEndDate#<0, Div(text-muted text-center, DateTime(#enddate#, DD.MM.YYYY HH:MI)), Div(text-bold text-center, DateTime(#enddate#, DD.MM.YYYY HH:MI))), text-center h5 align="center" width="125"],
            		[Success, Div(text-center text-bold, #percent_success#  %), text-center h5 align="center" width="70"],
            		[Decision, Div(text-center text-bold, If(#flag_decision#==0, If(And(#vCmpEndDate#<0,#creator_id#==#citizen#), BtnContract(votingCheckDecision,Decision, Do you want to check decision?,"votingID:'#id#'",'btn btn-primary',template,voting_list), Div(text-muted,"no")) ) If(#flag_decision#==-2, Div(text-muted,"not enough votes") ) If(#flag_decision#==1, Div(text-success,"accepted") ), If(#flag_decision#==-1, Div(text-danger,"rejected") ) ), text-center h5 align="center" width="90"],
            		[Status,  Div(text-center text-bold, If(#flag_success#==1, Div(text-success,"success"),  If(#vCmpEndDate#<0, Div(text-muted, "finished"), If(#vCmpStartDate#<0, BtnPage(voting_view, LangJS(go), "vID:#id#",  btn btn-primary), Div(text-warning,"waiting") ) ) ) ), text-center h5 align="center" width="70"],
            		[ , BtnContract(votingDelete, Em(fa fa-close),Do you want to delete this voting?,"votingID:#id#",'btn btn-danger',template,voting_list), text-center align="center" width="60" ]
            	]
            }
        DivsEnd:
        If(#isSearch#==1)
            Div(h4 m0 text-bold text-left, <br>)
            Divs(text-center)
                    BtnPage(voting_list, <b>View all</b>,"isSearch:0",btn btn-primary btn-oval)
            DivsEnd:
        IfEnd:
    DivsEnd:
    Divs(panel-footer)
        Divs:clearfix 
            Divs: pull-left
            DivsEnd:
            Divs: pull-right
                BtnPage(voting_create, Add voting, "",  btn btn-primary)
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
                            		[, Div("text-left",GetRow("citizens", #state_id#_citizens, "id", GetVar(member_id)) Div("",Image(If(GetVar(citizens_avatar)!=="",#citizens_avatar#,"/static/img/avatar.svg"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30), &nbsp #citizens_name#)), h4],
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
                                        		[, Div("text-left",GetRow("citizens", #state_id#_citizens, "id", GetVar(member_id)) Div("",Image(If(GetVar(citizens_avatar)!=="",#citizens_avatar#,"/static/img/avatar.svg"), Avatar, img-thumbnail img-circle thumb-full w-30 h-30), &nbsp #citizens_name#)), h4],
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
TextHidden( p_AddLand, pc_AddLand, p_AddProperty, pc_AddProperty, p_Chat_history, pc_Chat_history, p_chat_IncomingRoleMessages, pc_chat_IncomingRoleMessages, p_CitizenInfo, pc_CitizenInfo, p_citizen_profile, pc_citizen_profile, p_dashboard_default, pc_dashboard_default, p_EditLand, pc_EditLand, p_EditProperty, pc_EditProperty, p_LandHistory, pc_LandHistory, p_LandObject, pc_LandObject, p_LandObjectContract, pc_LandObjectContract, p_LandRegistry, pc_LandRegistry, p_members_list, pc_members_list, p_members_request_edit, pc_members_request_edit, p_MyChats, pc_MyChats, p_notification, pc_notification, p_notification_send_roles, pc_notification_send_roles, p_notification_send_single, pc_notification_send_single, p_notification_testpage, pc_notification_testpage, p_notification_view_roles, pc_notification_view_roles, p_notification_view_single, pc_notification_view_single, p_Property, pc_Property, p_PropertyDetails, pc_PropertyDetails, p_property_list, pc_property_list, p_roles_assign, pc_roles_assign, p_roles_create, pc_roles_create, p_roles_list, pc_roles_list, p_roles_view, pc_roles_view, p_tokens_accounts_add, pc_tokens_accounts_add, p_tokens_accounts_list, pc_tokens_accounts_list, p_tokens_create, pc_tokens_create, p_tokens_emission, pc_tokens_emission, p_tokens_list, pc_tokens_list, p_tokens_money_rollback, pc_tokens_money_rollback, p_tokens_money_transfer, pc_tokens_money_transfer, p_tokens_money_transfer_agency, pc_tokens_money_transfer_agency, p_tokens_money_transfer_company, pc_tokens_money_transfer_company, p_tokens_money_transfer_person, pc_tokens_money_transfer_person, p_voting_create, pc_voting_create, p_voting_decision_candidates, pc_voting_decision_candidates, p_voting_decision_document, pc_voting_decision_document, p_voting_decision_election, pc_voting_decision_election, p_voting_decision_formal, pc_voting_decision_formal, p_voting_invite, pc_voting_invite, p_voting_list, pc_voting_list, p_voting_view, pc_voting_view)
SetVar(`m_menu_default #= MenuItem(Dashboard, dashboard_default,, "fa pull-left icon-home") 
MenuItem(Profile, CitizenInfo, "", "fa pull-left icon-user")
MenuGroup(Members and Roles,members_list,icon-user)
    MenuItem(Members, members_list,, "fa pull-left icon-user")
    MenuItem(Roles, roles_list,, "fa pull-left icon-list")
    MenuItem(Single notifications, notification_view_single,, "fa pull-left icon-bell")
    MenuItem(Role notifications, notification_view_roles,, "fa pull-left icon-bell")
    MenuItem(Test page, notification_testpage,, "fa pull-left icon-settings")
MenuEnd:
MenuGroup(System tokens,tokens_accounts_list,icon-energy)
    MenuItem(Accounts,  tokens_accounts_list,, "fa pull-left icon-wallet")
    MenuItem(Tokens,  tokens_list,, "fa pull-left icon-energy")
    MenuItem(Money transfer,  tokens_money_transfer_person,, "fa pull-left icon-action-redo")
    MenuItem(Money rollback,  tokens_money_rollback,, "fa pull-left icon-trash")
MenuEnd:
MenuItem(Voting, voting_list,, "fa pull-left icon-pin")
MenuItem(My Chats, MyChats,, "fa pull-left icon-bubble")
MenuItem(Land Registry, LandRegistry,, "fa pull-left icon-globe")
MenuItem(Property Registry, Property,, "fa pull-left fa-home")
MenuGroup(Admin tools,admin, icon-settings)
    MenuItem(Tables,sys-listOfTables)
    MenuItem(Smart contracts, sys-contracts)
    MenuItem(Interface, sys-interface)
    MenuItem(App List, sys-app_catalog)
    MenuItem(Export, sys-export_tpl)
    MenuItem(Wallet,  sys-edit_wallet)
    MenuItem(Languages, sys-languages)
    MenuItem(Signatures, sys-signatures)
    MenuItem(Gen Keys, sys-gen_keys)
MenuEnd:


`,
`mc_menu_default #= ContractConditions("MainCondition")`)
TextHidden( m_menu_default, mc_menu_default)
SetVar(`pa_buildings_use_class #= Shops, Financial and professional services, Restaurants and cafes, Business, Hotels, Dwellinghouses, Non-residential institutions, No`,
`pac_buildings_use_class #= ContractConditions("MainCondition")`,
`pa_land_use #= Agriculture, Forestry, Fishing, Mining and quarrying, Hunting, Energy production, Industry and manufacturing, Transport - communication networks - storage and protective works, Water and waste treatment, Construction, Commerce finance and business, Community services, Recreational - leisure - sport, Residential, Unused`,
`pac_land_use #= ContractConditions("MainCondition")`,
`pa_members_request_status #= $member$,$visitor$,$visitor_sr$`,
`pac_members_request_status #= ContractConditions("MainCondition")`,
`pa_notification_ClosureType #= Single,Multiple`,
`pac_notification_ClosureType #= ContractConditions("MainCondition")`,
`pa_notification_icon #= fa-bell,fa-comment,fa-envelope,fa-bookmark,fa-check,fa-exclamation-triangle,fa-info-circle`,
`pac_notification_icon #= ContractConditions("MainCondition")`,
`pa_property_types #= $residential$,$commercial$,$land$`,
`pac_property_types #= ContractConditions("MainCondition")`,
`pa_roles_types #= Assigned,Elective`,
`pac_roles_types #= ContractConditions("MainCondition")`,
`pa_tokens_accounts_type #= $sys_emission$,$sys_trash$,$person$,$agency$,$company$`,
`pac_tokens_accounts_type #= ContractConditions("MainCondition")`,
`pa_tokens_rollback_tokens #= $impossible$,$possible$`,
`pac_tokens_rollback_tokens #= ContractConditions("MainCondition")`,
`pa_tokens_type_emission #= $limited$,$unlimited$`,
`pac_tokens_type_emission #= ContractConditions("MainCondition")`,
`pa_type_voting #= voting_type_candidate_manual,voting_type_candidate_requests,voting_type_document,voting_type_table`,
`pac_type_voting #= ContractConditions("MainCondition")`,
`pa_type_voting_decisions #= voting_decisions_candidate_requests,voting_decisions_candidate_manual,voting_decisions_document,voting_decisions_db`,
`pac_type_voting_decisions #= ContractConditions("MainCondition")`,
`pa_type_voting_participants #= voting_participants_everybody,voting_participants_manual,voting_participants_role`,
`pac_type_voting_participants #= ContractConditions("MainCondition")`)
TextHidden( pa_buildings_use_class, pac_buildings_use_class, pa_land_use, pac_land_use, pa_members_request_status, pac_members_request_status, pa_notification_ClosureType, pac_notification_ClosureType, pa_notification_icon, pac_notification_icon, pa_property_types, pac_property_types, pa_roles_types, pac_roles_types, pa_tokens_accounts_type, pac_tokens_accounts_type, pa_tokens_rollback_tokens, pac_tokens_rollback_tokens, pa_tokens_type_emission, pac_tokens_type_emission, pa_type_voting, pac_type_voting, pa_type_voting_decisions, pac_type_voting_decisions, pa_type_voting_participants, pac_type_voting_participants)
SetVar()
TextHidden( )
SetVar(`l_lang #= {" ResultSoon":"{\"en\": \" Result will be soon\", \"hk\": \"結果即將揭曉\", \"nl\": \" Result will be soon\", \"ru\": \"Результат будет скоро\", \"zh\": \"结果即将揭晓\"}","$voting_entry_number":"{\"en\": \"Poll #\", \"hk\": \"投票序號\", \"ru\": \"Poll #\", \"zh\": \"投票序号\"}","Actn":"{\"en\": \"Actions\", \"hk\": \"動作\", \"nl\": \"Acties\", \"ru\": \"Действия\", \"zh\": \"动作\"}","Actual":"{\"en\": \"Actual\", \"nl\": \"Actueel\", \"ru\": \"Текущие\"}","Anonym":"{\"en\": \"Anonymous\", \"hk\": \"匿名\", \"zh\": \"匿名\"}","Ans":"{\"en\": \"Answer\", \"hk\": \"答案\", \"nl\": \"Antwoord\", \"ru\": \"Ответить\", \"zh\": \"答案\"}","Apps":"{\"en\": \"Applications\", \"hk\": \"應用程式\", \"ru\": \"Приложения\", \"zh\": \"应用程序\"}","Cancel":"{\"en\": \"Cancel\", \"hk\": \"取消\", \"nl\": \"Annuleer\", \"ru\": \"Отменить\", \"zh\": \"取消\"}","Chng":"{\"en\": \"Change\", \"hk\": \"更改\", \"nl\": \"Wijzigen\", \"ru\": \"Изменить\", \"zh\": \"更改\"}","Confirm":"{\"en\": \"Confirm\", \"hk\": \"確認\", \"nl\": \"Bevestig\", \"ru\": \"Подтвердить\", \"zh\": \"确认\"}","Contin":"{\"en\": \"Continues\", \"nl\": \"Doorgaan\", \"ru\": \"Продолжаются\", \"zh\": \"继续\"}","Continues":"{\"en\": \"Continues\", \"hk\": \"繼續\", \"nl\": \"Doorgaan\", \"ru\": \"Продолжаются\", \"zh\": \"继续\"}","CreateNew":"{\"en\": \"Create new\", \"hk\": \"新建\", \"ru\": \"Создать новое\", \"zh\": \"新建\"}","DateFinishVoting":"{\"en\": \"Date Finish Voting\", \"hk\": \"投票結束日期\", \"nl\": \"Eind datum stem vraag\", \"ru\": \"Дата завершения голосования\", \"zh\": \"投票结束日期\"}","DateStartVoting":"{\"en\": \"Date Start Voting\", \"hk\": \"投票開始日期\", \"nl\": \"Begin datum stem vraag\", \"ru\": \"Дата начала голосования\", \"zh\": \"投票开始日期\"}","Del":"{\"en\": \"Delete\", \"hk\": \"刪除\", \"nl\": \"Verwijdering\", \"ru\": \"Удалить\", \"zh\": \"删除\"}","EnterIssue":"{\"en\": \"Enter Issue\", \"hk\": \"輸入問題\", \"nl\": \"Onderwerp\", \"ru\": \"Введите вопрос\", \"zh\": \"输入问题\"}","Finish":"{\"en\": \"Finish\", \"hk\": \"結束\", \"nl\": \"Einde\", \"ru\": \"Окончание\", \"zh\": \"结束\"}","Finished":"{\"en\": \"Finished\", \"hk\": \"已結束\", \"nl\": \"Einde\", \"ru\": \"Завершено\", \"zh\": \"已结束\"}","FinishedVotings":"{\"en\": \"Finished Votings\", \"hk\": \"已結束的投票\", \"nl\": \"Einde Stemmen\", \"ru\": \"Завершенные\", \"zh\": \"已结束的投票\"}","Fnsh":"{\"en\": \"Finish\", \"hk\": \"結束\", \"nl\": \"Einde\", \"ru\": \"Окончание\", \"zh\": \"结束\"}","Fnshd":"{\"en\": \"Finished\", \"hk\": \"已結束\", \"nl\": \"Einde\", \"ru\": \"Завершено\", \"zh\": \"已结束\"}","Gender":"{\"en\": \"Gender\", \"hk\": \"性別\", \"ru\": \"Пол\", \"zh\": \"性别\"}","GetResult":"{\"en\": \"Get Result\", \"hk\": \"獲取結果\", \"nl\": \"Haa resultaat op\", \"ru\": \"Получить результат\", \"zh\": \"获取结果\"}","GovernmentDashboard":"{\"en\": \"Government dashboard\", \"hk\": \"政務控制檯\", \"nl\": \"Land overzicht\", \"ru\": \"Панель государства\", \"zh\": \"政务控制台\"}","ID":"{\"en\": \"ID\", \"hk\": \"編號\", \"ru\": \"Номер\", \"zh\": \"编号\"}","Inf":"{\"en\": \"Info\", \"hk\": \"信息\", \"nl\": \"Info\", \"ru\": \"Информация\", \"zh\": \"信息\"}","Info":"{\"en\": \"Info\", \"hk\": \"信息\", \"nl\": \"Info\", \"ru\": \"Информация\", \"zh\": \"信息\"}","Iss":"{\"en\": \"Issue\", \"hk\": \"問題\", \"nl\": \"Onderwerp\", \"ru\": \"Вопрос\", \"zh\": \"问题\"}","Issue":"{\"en\": \"Issue\", \"hk\": \"問題\", \"nl\": \"Onderwerp\", \"ru\": \"Вопрос\", \"zh\": \"问题\"}","ListVotings":"{\"en\": \"List of Polling\", \"hk\": \"投票項目列表\", \"nl\": \"Stemlijst\", \"ru\": \"Опросы\", \"zh\": \"投票项目列表\"}","ListofApps":"{\"en\": \"List of applications:\", \"hk\": \"應用程式列表\", \"ru\": \"Список приложений:\", \"zh\": \"应用程序列表\"}","N":"{\"en\": \"No\", \"hk\": \"否\", \"nl\": \"Nee\", \"ru\": \"Нет\", \"zh\": \"否\"}","Name":"{\"en\": \"Name\", \"hk\": \"名稱\", \"ru\": \"Название\", \"zh\": \"名称\"}","NewVoting":"{\"en\": \"New Polling\", \"hk\": \"新投票\", \"nl\": \"Nieuwe vraag\", \"ru\": \"Новый опрос\", \"zh\": \"新投票\"}","Next":"{\"en\": \"Next\", \"hk\": \"下一個\", \"nl\": \"Naast\", \"ru\": \"Дальше\", \"zh\": \"下一个\"}","No":"{\"en\": \"No\", \"hk\": \"否\", \"nl\": \"Nee\", \"ru\": \"Нет\", \"zh\": \"否\"}","NoAvailablePolls":"{\"en\": \"No Available Polls\", \"hk\": \"暫無有效的投票項目\", \"nl\": \"Geen beschikbare vragen\", \"ru\": \"Нет доступных голосований\", \"zh\": \"暂无有效的投票项目\"}","QuestionList":"{\"en\": \"Questions List\", \"hk\": \"問題列表\", \"nl\": \"Lijst van vragen\", \"ru\": \"Список вопросов\", \"zh\": \"问题列表\"}","Referendapartij":"{\"en\": \"Referendapartij\", \"hk\": \"全員投票選舉\", \"nl\": \"stemNLwijzer.nl - directe democratie\", \"ru\": \"Referendapartij\", \"zh\": \"全员投票\"}","Res":"{\"en\": \"Result\", \"hk\": \"結果\", \"nl\": \"Resultaat\", \"ru\": \"Результат\", \"zh\": \"结果\"}","Result":"{\"en\": \"Result\", \"hk\": \"結果\", \"nl\": \"Resultaat\", \"ru\": \"Результат\", \"zh\": \"结果\"}","ResultSoon":"{\"en\": \" Result will be soon\", \"hk\": \"結果即將揭曉\", \"nl\": \" Result will be soon\", \"ru\": \"Результат будет скоро\", \"zh\": \"结果即将揭晓\"}","Save":"{\"en\": \"Save\", \"hk\": \"保存\", \"nl\": \"Bewaren\", \"ru\": \"Сохранить\", \"zh\": \"保存\"}","Search":"{\"en\": \"Search\", \"hk\": \"搜索\", \"ru\": \"Поиск\", \"zh\": \"搜索\"}","SearchAppbyName":"{\"en\": \"Search applications by name:\", \"hk\": \"通過名稱搜索應用程式\", \"ru\": \"Поиск приложения по названию:\", \"zh\": \"通过名称搜索应用程序\"}","ShowAll":"{\"en\": \"Show all\", \"hk\": \"顯示所有\", \"ru\": \"Показать все\", \"zh\": \"显示所有\"}","Start":"{\"en\": \"Start\", \"hk\": \"開始\", \"nl\": \"Sart\", \"ru\": \"Начало\", \"tw\": \"开始\"}","StartVote":"{\"en\": \"Start Vote\", \"hk\": \"開始投票\", \"nl\": \"Begin stemmen\", \"ru\": \"Начать голосование\", \"zh\": \"开始投票\"}","Stp":"{\"en\": \"Stop\", \"hk\": \"停止\", \"nl\": \"Stop\", \"ru\": \"Стоп\", \"zh\": \"停止\"}","Strt":"{\"en\": \"Start\", \"hk\": \"開始\", \"nl\": \"Sart\", \"ru\": \"Начало\", \"zh\": \"开始\"}","Synonym":"{\"en\": \"Synonym\", \"hk\": \"同義\", \"ru\": \"Синоним\", \"zh\": \"同义\"}","TEST_WARNING":"{\"en\": \"LOCALIZED_TEST\", \"hk\": \"測試報警\", \"zh\": \"测试报警\"}","TotalVoted":"{\"en\": \"Total voted\", \"hk\": \"總票數\", \"nl\": \"Aantal stemmen\", \"ru\": \"Всего проголосовало\", \"zh\": \"总票数\"}","TypeIssue":"{\"en\": \"Type\", \"hk\": \"類型\", \"nl\": \"Type\", \"ru\": \"Тип опроса\", \"zh\": \"类型\"}","View":"{\"en\": \"View\", \"hk\": \"顯示\", \"nl\": \"Uitzicht\", \"ru\": \"Смотреть\", \"zh\": \"显示\"}","Vote":"{\"en\": \"Vote\", \"hk\": \"投票\", \"nl\": \"Stemmen\", \"ru\": \"Голосовать\", \"zh\": \"投票\"}","Voting":"{\"en\": \"Voting\", \"hk\": \"投票/民調\", \"nl\": \"Stemmen\", \"ru\": \"Голосование\", \"zh\": \"投票/民调\"}","VotingFinished":"{\"en\": \" Voting finished\", \"hk\": \"該投票項目已結束\", \"nl\": \"Ende stemmen\", \"ru\": \"Голосование закончено\", \"zh\": \"该投票项目已结束\"}","Vw":"{\"en\": \"View\", \"hk\": \"顯示\", \"nl\": \"Uitzicht\", \"ru\": \"Смотреть\", \"zh\": \"显示\"}","Welcome":"{\"en\": \"Welcome\", \"hk\": \"歡迎您\", \"nl\": \"Welkom\", \"ru\": \"Добро пожаловать\", \"zh\": \"欢迎您\"}","Y":"{\"en\": \"Yes\", \"hk\": \"是\", \"nl\": \"Ja\", \"ru\": \"Да\", \"zh\": \"是\"}","Yes":"{\"en\": \"Yes\", \"hk\": \"是\", \"nl\": \"Ja\", \"ru\": \"Да\", \"zh\": \"是\"}","YouVoted":"{\"en\": \"You voted for all available issues\", \"hk\": \"您已對全部有效議題進行了投票\", \"nl\": \"U stemt op alle beschikbare onderwerpen\", \"ru\": \"Вы проголосовали за все доступные вопросы\", \"zh\": \"您已对全部有效议题进行了投票\"}","YourAnswer":"{\"en\": \"Your Answer\", \"hk\": \"您的答複\", \"nl\": \"Uw antwoord\", \"ru\": \"Ваш ответ\", \"zh\": \"您的答复\"}","accounts":"{\"en\": \"Accounts\", \"hk\": \"賬戶信息\", \"zh\": \"账户信息\"}","add_role":"{\"en\": \"Add role\", \"hk\": \"增加職位身份\", \"zh\": \"增加职位身份\"}","address":"{\"en\": \"Address\", \"hk\": \"地址\", \"zh\": \"地址\"}","admin_tools":"{\"en\": \"Admin tools\", \"hk\": \"管理員工具\", \"zh\": \"管理员工具\"}","app_list":"{\"en\": \"App List\", \"hk\": \"應用程式列表\", \"zh\": \"应用程序列表\"}","area":"{\"en\": \"Area\", \"hk\": \"面積\", \"zh\": \"面积\"}","buildings_use_class":"{\"en\": \"Buildings use class\", \"hk\": \"建築物類型\", \"zh\": \"建筑物类型\"}","change":"{\"en\": \"Change\", \"hk\": \"變更\", \"zh\": \"变更\"}","coords":"{\"en\": \"Coords\", \"hk\": \"座標\", \"zh\": \"座标\"}","create":"{\"en\": \"Create\", \"hk\": \"創建\", \"zh\": \"创建\"}","creator":"{\"en\": \"Creator\", \"hk\": \"創建人\", \"zh\": \"创建人\"}","dashboard":"{\"en\": \"Dashboard\", \"hk\": \"儀錶板\", \"zh\": \"仪表板\"}","date_accept":"{\"en\": \"Date Accept\", \"hk\": \"審批日期\", \"zh\": \"审批日期\"}","date_create":"{\"en\": \"Date create\", \"hk\": \"創建日期\", \"zh\": \"创建日期\"}","date_delete":"{\"en\": \"Date Delete\", \"hk\": \"刪除日期\", \"zh\": \"删除日期\"}","dateformat":"{\"en\": \"YYYY-MM-DD\", \"hk\": \"YYYY年MM月DD日\", \"ru\": \"DD.MM.YYYY\", \"zh\": \"YYYY年MM月DD日\"}","editing_profile":"{\"en\": \"Editing profile\", \"hk\": \"編輯會員信息\", \"zh\": \"编辑会员信息\"}","expiration":"{\"en\": \"Expiration\", \"hk\": \"過期日期\", \"zh\": \"过期日期\"}","export":"{\"en\": \"Export\", \"hk\": \"導出\", \"zh\": \"导出\"}","female":"{\"en\": \"Female\", \"hk\": \"女\", \"ru\": \"Женский\", \"zh\": \"女\"}","gen_keys":"{\"en\": \"Gen Keys\", \"hk\": \"生成密鈅\", \"zh\": \"生成密钥\"}","interface":"{\"en\": \"Interface\", \"hk\": \"接口界面\", \"zh\": \"接口界面\"}","land_registry":"{\"en\": \"Land Registry\", \"hk\": \"土地登記註冊\", \"zh\": \"土地登记注册\"}","land_use":"{\"en\": \"Land use\", \"hk\": \"土地用途\", \"zh\": \"土地用途\"}","languages":"{\"en\": \"Languages\", \"hk\": \"多語言資源\", \"zh\": \"多语言资源\"}","male":"{\"en\": \"Male\", \"hk\": \"男\", \"ru\": \"Мужской\", \"zh\": \"男\"}","member":"{\"en\": \"Member\", \"hk\": \"成員\", \"zh\": \"成员\"}","member_id":"{\"en\": \"Member ID\", \"hk\": \"成員ID\", \"zh\": \"成员ID\"}","members":"{\"en\": \"Members\", \"hk\": \"成員\", \"zh\": \"成员\"}","membersandroles":"{\"en\": \"Members and Roles\", \"hk\": \"成員和職務身份\", \"zh\": \"成员和职务身份\"}","membership_request":"{\"en\": \"Membership Request\", \"hk\": \"待審批的會員列表\", \"zh\": \"待审批的会员列表\"}","moneyrollback":"{\"en\": \"Money rollback\", \"hk\": \"資產回收\", \"zh\": \"资产回收\"}","moneytransfer":"{\"en\": \"Money transfer\", \"hk\": \"資產轉賬\", \"zh\": \"资产转账\"}","my_chats":"{\"en\": \"My Chats\", \"hk\": \"我的交流窗口\", \"zh\": \"我的交流窗口\"}","name":"{\"en\": \"Name\", \"hk\": \"名稱\", \"zh\": \"名称\"}","name_first":"{\"en\": \"First name\", \"hk\": \"名字\", \"ru\": \"Имя\", \"zh\": \"名字\"}","name_last":"{\"en\": \"Last name\", \"hk\": \"姓氏\", \"ru\": \"Фамилия\", \"zh\": \"姓氏\"}","new_role":"{\"en\": \"New role\", \"hk\": \"新增職務身份\", \"zh\": \"新增职务身份\"}","not_limited":"{\"en\": \"Not Limited\", \"hk\": \"無限制\", \"zh\": \"无限制\"}","photo":"{\"en\": \"Photo\", \"hk\": \"照片\", \"zh\": \"照片\"}","profile":"{\"en\": \"Profile\", \"hk\": \"用戶信息\", \"zh\": \"用户信息\"}","property_registry":"{\"en\": \"Property Registry\", \"hk\": \"房產註冊\", \"zh\": \"房产注册\"}","qes1":"{\"en\": \"the first question \", \"hk\": \"首要問題\", \"nl\": \"De eerste vraag\", \"zh\": \"首要问题\"}","ques1":"{\"en\": \"the first question \", \"hk\": \"首要問題\", \"nl\": \"De eerste vraag\", \"zh\": \"首要问题\"}","role_name":"{\"en\": \"Role name\", \"hk\": \"職務身份名稱\", \"zh\": \"职务身份名称\"}","rolenotifications":"{\"en\": \"Role notifications\", \"hk\": \"工作通知\", \"zh\": \"工作通知\"}","roles":"{\"en\": \"Roles\", \"hk\": \"職務身份\", \"zh\": \"职务身份\"}","search":"{\"en\": \"Search\", \"hk\": \"搜索\", \"zh\": \"搜索\"}","signatures":"{\"en\": \"Signatures\", \"hk\": \"數字簽名\", \"zh\": \"数字签名\"}","singlenotifications":"{\"en\": \"Single notifications\", \"hk\": \"個人通知\", \"zh\": \"个人通知\"}","smart_contracts":"{\"en\": \"Smart contracts\", \"hk\": \"智能合約\", \"zh\": \"智能合约\"}","status":"{\"en\": \"Status\", \"hk\": \"狀態\", \"zh\": \"状态\"}","subject_of_voting":"{\"en\": \"Subject of voting\", \"hk\": \"投票/民調主題\", \"zh\": \"投票/民调主题\"}","systemtokens":"{\"en\": \"System tokens\", \"hk\": \"系統代幣\", \"zh\": \"系统代币\"}","tables":"{\"en\": \"Tables\", \"hk\": \"數據表\", \"zh\": \"数据表\"}","testpage":"{\"en\": \"Test page\", \"hk\": \"測試頁面\", \"zh\": \"测试页面\"}","timeformat":"{\"en\": \"YYYY-MM-DD HH:MI:SS\", \"hk\": \"YYYY年MM月DD日 HH:MI:SS\", \"ru\": \"DD.MM.YYYY HH:MI:SS\", \"zh\": \"YYYY年MM月DD日 HH:MI:SS\"}","tokens":"{\"en\": \"Tokens\", \"hk\": \"代幣\", \"zh\": \"代币\"}","type":"{\"en\": \"Type\", \"hk\": \"類型\", \"zh\": \"类型\"}","view_all":"{\"en\": \"View all\", \"hk\": \"顯示所有\", \"zh\": \"显示所有\"}","visitor":"{\"en\": \"Visitor\", \"hk\": \"訪客（僅瀏覽）\", \"zh\": \"访客（仅浏览）\"}","visitor_sr":"{\"en\": \"Visitor (SR)\", \"hk\": \"嘉賓（部分權限）\", \"zh\": \"嘉宾（部分权限）\"}","voting":"{\"en\": \"Voting\", \"hk\": \"投票/民調\", \"ru\": \"voting\", \"zh\": \"投票/民调\"}","voting_actions":"{\"en\": \"Actions\", \"hk\": \"動作\", \"ru\": \"Actions\", \"zh\": \"动作\"}","voting_create":"{\"en\": \"Create new\", \"hk\": \"新建投票項目\", \"ru\": \"Create new\", \"zh\": \"新建投票项目\"}","voting_creator":"{\"en\": \"Creator\", \"hk\": \"創建者\", \"ru\": \"Creator\", \"zh\": \"创建者\"}","voting_decision":"{\"en\": \"Subject of voting\", \"hk\": \"投票項目的主題\", \"ru\": \"Subject of voting\", \"zh\": \"投票项目的主题\"}","voting_decisions_candidate_manual":"{\"en\": \"Role candidates with manual registration of participants\", \"hk\": \"按要求人工登記的候選人\", \"ru\": \"Role candidates with manual registration of participants\", \"zh\": \"按要求人工登记的候选人\"}","voting_decisions_candidate_requests":"{\"en\": \"Role candidates with registration of participants by request\", \"hk\": \"按要求自動登記的候選人\", \"ru\": \"Role candidates with registration of participants by request\", \"zh\": \"按要求自动登记的候选人\"}","voting_decisions_db":"{\"en\": \"Formal decision\", \"hk\": \"正式決議\", \"ru\": \"Formal decision\", \"zh\": \"正式决议\"}","voting_decisions_document":"{\"en\": \"Document approval\", \"hk\": \"文件審批\", \"ru\": \"Document approval\", \"zh\": \"文件审批\"}","voting_decisions_set":"{\"en\": \"Set goal\", \"hk\": \"設定投票目標\", \"ru\": \"Set goal\", \"zh\": \"设定投票目标\"}","voting_description":"{\"en\": \"Description\", \"hk\": \"投票項目簡介\", \"ru\": \"Description\", \"zh\": \"投票项目简介\"}","voting_end":"{\"en\": \"End date\", \"hk\": \"結束日期\", \"ru\": \"End date\", \"zh\": \"结束日期\"}","voting_end_desc":"{\"en\": \"End date for voting\", \"hk\": \"投票結束日期\", \"ru\": \"End date for voting\", \"zh\": \"投票结束日期\"}","voting_error":"{\"en\": \"Error\", \"hk\": \"投票錯誤\", \"ru\": \"Error\", \"zh\": \"投票错误\"}","voting_error_not_exists":"{\"en\": \"Requested entry does not exist\", \"hk\": \"該投票項目不存在\", \"ru\": \"Requested entry does not exist\", \"zh\": \"该投票项目不存在\"}","voting_invite":"{\"en\": \"Invite\", \"hk\": \"投票邀請\", \"ru\": \"Invite\", \"zh\": \"投票邀请\"}","voting_list":"{\"en\": \"voting list\", \"hk\": \"投票項目列表\", \"ru\": \"voting list\", \"zh\": \"投票项目列表\"}","voting_participant_id":"{\"en\": \"Citizen ID\", \"hk\": \"投票參與者 ID\", \"ru\": \"Citizen ID\", \"zh\": \"投票参与者 ID\"}","voting_participants":"{\"en\": \"Invited participants\", \"hk\": \"受邀投票參與者\", \"ru\": \"Invited participants\", \"zh\": \"受邀投票参与者\"}","voting_participants_everybody":"{\"en\": \"Anybody\", \"hk\": \"所有人\", \"ru\": \"Anybody\", \"zh\": \"所有人\"}","voting_participants_manual":"{\"en\": \"Choose manually\", \"hk\": \"手動選擇\", \"ru\": \"Choose manually\", \"zh\": \"手动选择\"}","voting_participants_role":"{\"en\": \"By role\", \"hk\": \"按職務和身份\", \"ru\": \"By role\", \"zh\": \"按职务和身份\"}","voting_prestart":"{\"en\": \"Start date for applications\", \"hk\": \"應用程式的開始日期\", \"ru\": \"Start date for applications\", \"zh\": \"应用程序的开始日期\"}","voting_quorum":"{\"en\": \"Quorum\", \"hk\": \"法定人數\", \"ru\": \"Quorum\", \"zh\": \"法定人数\"}","voting_quorum_desc":"{\"en\": \"Percentage value of total participiants to fulfill requirements of this poll (from 5 to 100)\", \"hk\": \"滿足本次投票要求的參與人數百分比（5〜100）\", \"ru\": \"Percentage value of total participiants to fulfill requirements of this poll (from 5 to 100)\", \"zh\": \"满足本次投票要求的参与人数百分比（5〜100）\"}","voting_start":"{\"en\": \"Start date\", \"hk\": \"開始日期\", \"ru\": \"Start date\", \"zh\": \"开始日期\"}","voting_start_desc":"{\"en\": \"Start date for voting\", \"hk\": \"開始投票日期\", \"ru\": \"Start date for voting\", \"zh\": \"开始投票日期\"}","voting_view":"{\"en\": \"View\", \"hk\": \"顯示詳情\", \"ru\": \"View\", \"zh\": \"显示详情\"}","voting_volume":"{\"en\": \"Volume\", \"hk\": \"投票通過率\", \"ru\": \"Volume\", \"zh\": \"投票通过率\"}","voting_volume_desc":"{\"en\": \"Percentage value of votes to fulfill requirements of this poll (from 50 to 100)\", \"hk\": \"符合投票要求的票數百分比（50〜100）\", \"ru\": \"Percentage value of votes to fulfill requirements of this poll (from 50 to 100)\", \"zh\": \"符合投票要求的票数百分比（50〜100）\"}","voting_voting_participants":"{\"en\": \"Voting participants\", \"hk\": \"投票參與者\", \"ru\": \"Voting participants\", \"zh\": \"投票参与者\"}","wallet":"{\"en\": \"Wallet\", \"hk\": \"錢包信息\", \"zh\": \"钱包信息\"}"}`)
TextHidden(l_lang)
Json(`Head: "ListApplications",
Desc: "ListApplications",
		Img: "/static/img/apps/ava.png",
		OnSuccess: {
			script: 'template',
			page: 'government',
			parameters: {}
		},
		TX: [{
        		Forsign: 'table_name,column_name,permissions,index,column_type',
        		Data: {
        			type: "NewColumn",
        			typeid: #typecolid#,
        			table_name : "#state_id#_citizens",
        			column_name: "avatar",
        			index: "0",
        			column_type: "text",
        			permissions: "ContractConditions(\"CitizenCondition\")"
        		}
        },
		{
        		Forsign: 'table_name,column_name,permissions,index,column_type',
        		Data: {
        			type: "NewColumn",
        			typeid: #typecolid#,
        			table_name : "#state_id#_citizens",
        			column_name: "name",
        			index: "1",
        			column_type: "hash",
        			permissions: "ContractConditions(\"CitizenCondition\")"
        		}
        },
		{
        		Forsign: 'table_name,column_name,permissions,index,column_type',
        		Data: {
        			type: "NewColumn",
        			typeid: #typecolid#,
        			table_name : "#state_id#_citizens",
        			column_name: "name_last",
        			index: "1",
        			column_type: "hash",
        			permissions: "ContractConditions(\"CitizenCondition\")"
        		}
        },
		{
        		Forsign: 'table_name,column_name,permissions,index,column_type',
        		Data: {
        			type: "NewColumn",
        			typeid: #typecolid#,
        			table_name : "#state_id#_citizens",
        			column_name: "person_status",
        			index: "1",
        			column_type: "int64",
        			permissions: "ContractConditions(\"CitizenCondition\")"
        		}
        },
		{
        		Forsign: 'table_name,column_name,permissions,index,column_type',
        		Data: {
        			type: "NewColumn",
        			typeid: #typecolid#,
        			table_name : "#state_id#_citizens",
        			column_name: "gender",
        			index: "1",
        			column_type: "int64",
        			permissions: "ContractConditions(\"CitizenCondition\")"
        		}
        },
		{
        		Forsign: 'table_name,column_name,permissions,index,column_type',
        		Data: {
        			type: "NewColumn",
        			typeid: #typecolid#,
        			table_name : "#state_id#_citizens",
        			column_name: "date_end",
        			index: "1",
        			column_type: "time",
        			permissions: "ContractConditions(\"CitizenCondition\")"
        		}
        },
		{
        		Forsign: 'table_name,column_name,permissions,index,column_type',
        		Data: {
        			type: "NewColumn",
        			typeid: #typecolid#,
        			table_name : "#state_id#_citizens",
        			column_name: "date_start",
        			index: "1",
        			column_type: "time",
        			permissions: "ContractConditions(\"CitizenCondition\")"
        		}
        },
		{
        		Forsign: 'table_name,column_name,permissions,index,column_type',
        		Data: {
        			type: "NewColumn",
        			typeid: #typecolid#,
        			table_name : "#state_id#_citizens",
        			column_name: "date_expiration",
        			index: "1",
        			column_type: "time",
        			permissions: "ContractConditions(\"CitizenCondition\")"
        		}
        },		
{
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "accounts",
			columns: '[["amount", "money", "0"],["onhold", "int64", "1"],["citizen_id", "int64", "1"],["type", "int64", "1"]]'
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
			column_name: "citizen_id",
			permissions: "ContractAccess(\"tokens_Account_Add\")",
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
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "accounts_tokens",
			columns: '[["flag_rollback_tokens", "int64", "1"],["amount", "int64", "1"],["delete", "int64", "1"],["date_create", "time", "1"],["name_tokens", "hash", "1"],["type_emission", "int64", "1"],["date_expiration", "time", "1"]]'
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
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "chat_private_chats",
			columns: '[["receiver_name", "text", "0"],["sender_avatar", "text", "0"],["receiver_avatar", "text", "0"],["lower_id", "int64", "1"],["last_message", "text", "0"],["receiver_id", "int64", "1"],["sender_name", "text", "0"],["last_message_id", "int64", "0"],["higher_id", "int64", "1"],["sender_id", "int64", "1"]]'
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
			column_name: "receiver_avatar",
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
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "chat_private_messages",
			columns: '[["sender", "int64", "0"],["message", "text", "0"],["receiver", "int64", "0"],["sender_name", "text", "0"],["sender_avatar", "text", "0"],["receiver_avatar", "text", "0"],["receiver_role_id", "int64", "1"],["receiver_name", "text", "0"],["sender_role_id", "int64", "1"]]'
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
			column_name: "sender",
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
			column_name: "sender_avatar",
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
			columns: '[["sender_name", "text", "0"],["last_message", "text", "0"],["sender_avatar", "text", "0"],["last_message_frome_role", "int64", "0"],["role_id", "int64", "1"],["citizen_id", "int64", "1"]]'
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
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "citizenship_requests",
			columns: '[["public_key_0", "text", "0"],["dlt_wallet_id", "int64", "1"],["name", "hash", "1"],["approved", "int64", "1"],["block_id", "int64", "1"]]'
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
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "editing_land_registry",
			columns: '[["person_id", "int64", "1"],["person_name", "hash", "1"],["lend_object_id", "int64", "1"],["new_attr_value", "text", "0"],["old_attr_value", "text", "0"],["editing_attribute", "hash", "1"],["date", "time", "0"]]'
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
			column_name: "person_id",
			permissions: "ContractConditions(\"MainCondition\")",
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
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "land_ownership",
			columns: '[["owner_id", "int64", "1"],["date_creat", "time", "0"],["owner_type", "int64", "1"],["date_signing", "time", "1"],["owner_new_id", "int64", "1"],["lend_object_id", "int64", "1"],["price", "money", "1"]]'
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
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "land_registry",
			columns: '[["buildings_use_class", "int64", "1"],["land_registry_number", "int64", "1"],["land_use", "int64", "1"],["date_last_edit", "time", "1"],["coords", "text", "0"],["address", "text", "0"],["date_insert", "time", "1"],["area", "int64", "1"],["value", "money", "1"]]'
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
			column_name: "coords",
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
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "notification",
			columns: '[["text_body", "text", "0"],["page_value", "int64", "1"],["started_processing_id", "int64", "1"],["finished_processing_time", "time", "0"],["closed", "int64", "1"],["header", "hash", "0"],["page_value2", "hash", "1"],["type", "hash", "1"],["recipient_id", "int64", "1"],["icon", "int64", "0"],["role_id", "int64", "1"],["page_name", "hash", "1"],["finished_processing_id", "int64", "1"],["started_processing_time", "time", "0"]]'
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
			column_name: "page_value",
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
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "property",
			columns: '[["sell_price", "money", "1"],["business_suitability", "int64", "1"],["name", "text", "0"],["coords", "text", "0"],["rent_price", "money", "1"],["offers", "int64", "0"],["sewerage", "int64", "0"],["citizen_id", "int64", "1"],["waste_solutions", "int64", "0"],["police_inspection", "int64", "1"],["area", "int64", "0"],["type", "int64", "1"],["leaser", "int64", "1"]]'
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
			columns: '[["role_id", "int64", "1"],["role_name", "hash", "1"],["date_start", "time", "1"],["appointed_by_id", "int64", "1"],["appointed_by_name", "hash", "1"],["delete", "int64", "1"],["date_end", "time", "1"],["member_id", "int64", "1"],["role_title", "hash", "1"],["member_name", "hash", "1"]]'
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
			columns: '[["creator_id", "int64", "1"],["date_create", "time", "1"],["date_delete", "time", "1"],["creator_name", "hash", "1"],["delete", "int64", "1"],["role_name", "hash", "1"],["role_type", "int64", "1"]]'
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
			column_name: "delete",
			permissions: "ContractAccess(\"roles_Del\")",
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
		Forsign: 'global,table_name,columns',
		Data: {
			type: "NewTable",
			typeid: #type_new_table_id#,
			global: 0,
			table_name : "voting_instances",
			columns: '[["percent_success", "int64", "0"],["name", "hash", "1"],["delete", "int64", "0"],["description", "text", "0"],["typedecision", "int64", "0"],["flag_decision", "int64", "0"],["percent_voters", "int64", "0"],["optional_role_vacancies", "int64", "1"],["quorum", "int64", "0"],["volume", "int64", "0"],["enddate", "time", "1"],["flag_success", "int64", "1"],["optional_role_id", "int64", "1"],["number_participants", "int64", "1"],["flag_fulldata", "int64", "0"],["optional_number_cands", "int64", "1"],["startdate", "time", "1"],["creator_id", "int64", "1"],["flag_notifics", "int64", "0"],["number_voters", "int64", "1"],["typeparticipants", "int64", "0"]]'
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
			column_name: "startdate",
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
			column_name: "flag_success",
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
			columns: '[["decision", "int64", "1"],["member_id", "int64", "1"],["voting_id", "int64", "1"],["decision_date", "time", "1"]]'
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
			columns: '[["number_accept", "int64", "1"],["text_document", "text", "0"],["formal_decision_table", "hash", "1"],["formal_decision_colvalue", "hash", "1"],["formal_decision_tableid", "int64", "1"],["formal_decision_description", "text", "0"],["member_id", "int64", "1"],["voting_id", "int64", "1"],["text_doc_hash", "text", "0"],["formal_decision_column", "hash", "1"]]'
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
			column_name: "member_id",
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
			column_name: "formal_decision_table",
			permissions: "ContractConditions(\"CitizenCondition\")",
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
				type: "EditMenu",
				typeid: #type_edit_menu_id#,
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
		Forsign: 'global,name,value',
		Data: {
			type: "AppendPage",
			typeid: #type_append_page_id#,
			name : "dashboard_default",
			value: $("#p_dashboard_default").val(),
			global: 0
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
