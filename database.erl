-module(database).
-export([connect/0,loginQuery/2,registerQuery/2,emailQuery/2,getItemsFromList/4,addItem/2,delItem/2,getLists/2,addList/2,delList/2, setToBought/2, getSubLists/2, getNotifications/2, getSubItems/4, addSubItem/2, confirmShare/3, deleteSubItem/4,invite/4, rejectInvite/3, setSubItemsToBought/2]).
connect() -> 
	{ok,PID} = mysql:start_link([{host,"mysql18.citynetwork.se"},
								{user,"116955-dw57706"},
								{password,"GrocodeMaster123"},
								{database,"116955-grocode"}]), PID.
								
loginQuery(DB,L) -> 
	{ok,_,Res} = mysql:query(DB,<<"SELECT Users_ID FROM 1GroCodeUsers WHERE Email=? and Password=?">>,
				[binary:bin_to_list(X) || X <- L]),
	Res.
registerQuery(DB,L) ->
	_Res = mysql:query(DB,<<"INSERT INTO 1GroCodeUsers (Email,Password,Users_ID,Name) VALUES (?,?,?,?)">>,[binary:bin_to_list(X) || X <- L]).
emailQuery(DB,L) ->
	{ok,_,Res} = mysql:query(DB,<<"SELECT Email FROM 1GroCodeUsers WHERE Email=?">>,[binary:bin_to_list(X) || X <- L]),
	Res.
getItemsFromList(DB,Email, List, BoughtOrNot) ->
	{ok,_,Res} = mysql:query(DB,<<"SELECT 4ItemInList.Item, 4ItemInList.Bought  FROM 4ItemInList INNER JOIN (1GroCodeUsers, 2Lists) 
	ON 2Lists.List_ID = 4ItemInList.List_ID AND 2Lists.User_ID = 1GroCodeUsers.Users_ID
	 WHERE  1GroCodeUsers.Email = (?) AND 2Lists.ListName = (?) AND 4ItemInList.Bought = (?)">>,[binary:bin_to_list(Email),binary:bin_to_list(List), BoughtOrNot] ),
	 case Res of 
		[] -> Res;
		_ -> [hd(X) || X <- Res] 
	 end.
deleteSubItem(DB,List,Email,Item ) ->  
    %get the list id
    {ok,_, Res} = mysql:query(DB,"SELECT 2Lists.List_ID FROM 2Lists INNER JOIN (1GroCodeUsers, 3ShareList) ON 1GroCodeUsers.Users_ID = 3ShareList.User_ID AND 3ShareList.List_ID = 2Lists.List_ID WHERE 1GroCodeUsers.Email = (?) AND 2Lists.ListName = (?)", 
     [binary:bin_to_list(Email),binary:bin_to_list(List)]),	
     io:format(">>>>>>>>List_ID ~p", [Res]),
    case Res of
    % if not
    [] -> error;
    %exists
    _ -> [[List_ID]]=Res,
        io:format(">>>>>>>>List_ID ~p", [List_ID]),
		%Delete item from subscribed ItemInList.
		mysql:query(DB, "DELETE FROM 4ItemInList WHERE List_ID=(?) AND Item=(?)", [List_ID, binary:bin_to_list(Item)])
    end.	
getSubItems(DB, Email , List, BoughtOrNot ) ->
    {ok,_,Res_UserID} = mysql:query(DB, "SELECT 1GroCodeUsers.Users_ID FROM 1GroCodeUsers WHERE 1GroCodeUsers.Email = (?)", [binary:bin_to_list(Email)] ),
        case Res_UserID of
        % if not
        [] -> error;
        %exists
        _ -> [[User_ID]]=Res_UserID,  
            {ok,_,Res} = mysql:query(DB, <<"SELECT 4ItemInList.Item FROM 4ItemInList INNER JOIN (1GroCodeUsers, 2Lists, 3ShareList) ON 2Lists.List_ID = 4ItemInList.List_ID AND 2Lists.User_ID = 1GroCodeUsers.Users_ID AND 3ShareList.List_ID = 2Lists.List_ID  WHERE 2Lists.ListName = (?) AND 3ShareList.User_ID = (?) AND 4ItemInList.Bought=(?)">>, 
             [binary:bin_to_list(List), User_ID, BoughtOrNot]),
             case Res of 
                [] -> Res;
                _ -> [hd(X) || X <- Res] 
                end
             end.

% SHARE: ADD
addSubItem(DB,[List,Email,Item]) -> 
	%get the list id
    {ok,_, Res} = mysql:query(DB,<<"SELECT 2Lists.List_ID FROM 2Lists INNER JOIN (1GroCodeUsers, 3ShareList) ON 1GroCodeUsers.Users_ID = 3ShareList.User_ID AND 3ShareList.List_ID = 2Lists.List_ID WHERE 1GroCodeUsers.Email = (?) AND 2Lists.ListName = (?)">>, 
     [binary:bin_to_list(Email),binary:bin_to_list(List)]),	
     io:format("STUFF HERE ~p~n",[Res]),
     io:format("STUFF HERE ~p~n",[Email]),
    case Res of
    % if not
    [] -> error;
    %exists
    _ -> [[List_ID]]=Res,
		%Puts item to ItemInList.
		mysql:query(DB, "INSERT INTO 4ItemInList (List_ID, Item) VALUES (?, ?)", [List_ID, binary:bin_to_list(Item)]), ok
    end.	     
     
     
%Set bought item
setToBought(DB,[List,Email,Item]) ->
	%get the list id
    {ok,_, Res} = mysql:query(DB,  "SELECT 2Lists.List_ID FROM 2Lists INNER JOIN 1GroCodeUsers ON 2Lists.User_ID = 1GroCodeUsers.Users_ID WHERE 2Lists.ListName = (?) AND 1GroCodeUsers.Email = (?)", [binary:bin_to_list(List),binary:bin_to_list(Email)]),
    %check if list exists							
    case Res of
    % if not
    [] -> error;
    %exists
    _ -> [[List_ID]]=Res,
		%Puts item to ItemInList.
		mysql:query(DB, "UPDATE 4ItemInList Set Bought='1' WHERE List_ID=(?) AND Item=(?)", [List_ID, binary:bin_to_list(Item)])
        end.
setSubItemsToBought(DB,[List,Email,Item])->
    %get the list id
    {ok,_, Res} = mysql:query(DB,"SELECT 2Lists.List_ID FROM 2Lists INNER JOIN (1GroCodeUsers, 3ShareList) ON 1GroCodeUsers.Users_ID = 3ShareList.User_ID AND 3ShareList.List_ID = 2Lists.List_ID WHERE 1GroCodeUsers.Email = (?) AND 2Lists.ListName = (?)", 
     [binary:bin_to_list(Email),binary:bin_to_list(List)]),	
     io:format(">>>>>>>>List_ID ~p", [Res]),
    case Res of
    % if not
    [] -> error;
    %exists
    _ -> [[List_ID]]=Res,
        io:format(">>>>>>>>List_ID ~p", [List_ID]),
		%Delete item from subscribed ItemInList.
		mysql:query(DB, "UPDATE 4ItemInList SET Bought='1' WHERE List_ID=(?) AND Item=(?)", [List_ID, binary:bin_to_list(Item)])
    end.	
    

%getBought(DB,L) ->
	%{ok,_,Res} = mysql:query(DB,<<"SELECT 4ItemInList.Item, 4ItemInList.Bought %FROM 4ItemInList INNER JOIN (1GroCodeUsers, 2Lists) 
	%ON 2Lists.List_ID = 4ItemInList.List_ID AND 2Lists.User_ID = %1GroCodeUsers.Users_ID
	 %WHERE 4ItemInList.Bought = '1' AND  1GroCodeUsers.Email = (?) AND %2Lists.ListName = (?)">>,[binary:bin_to_list(X) || X <- L]),
	 %case Res of 
		%[] -> Res;
		%_ -> [hd(X) || X <- Res] 
	% end.            
%add item to a list	 
addItem(DB,[List,Email,Item]) -> 
	%get the list id
    {ok,_, Res} = mysql:query(DB,"SELECT 2Lists.List_ID FROM 2Lists INNER JOIN 1GroCodeUsers ON 2Lists.User_ID = 1GroCodeUsers.Users_ID WHERE 2Lists.ListName = (?) AND 1GroCodeUsers.Email = (?)", [binary:bin_to_list(List),binary:bin_to_list(Email)]),
	%check if list exists
    io:format(">>>>>>>> ~p", [Res]),
    case Res of
    % if not
    [] -> error;
    %exists
    _ -> [[List_ID]]=Res,
        io:format(">>>>>>>>List_ID ~p", [List_ID]),
		%Puts item to ItemInList.
		mysql:query(DB, "INSERT INTO 4ItemInList (List_ID, Item) VALUES (?, ?)", [List_ID, binary:bin_to_list(Item)])
    end.	
delItem(DB,[List,Email,Item]) ->
	%get the list id
    {ok,_, Res} = mysql:query(DB,  "SELECT 2Lists.List_ID FROM 2Lists INNER JOIN 1GroCodeUsers ON 2Lists.User_ID = 1GroCodeUsers.Users_ID WHERE 2Lists.ListName = (?) AND 1GroCodeUsers.Email = (?)", [binary:bin_to_list(List),binary:bin_to_list(Email)]),
    %check if list exists							
    case Res of
    % if not
    [] -> error;
    %exists
    _ -> [[List_ID]]=Res,
		%Puts item to ItemInList.
		mysql:query(DB, "DELETE FROM 4ItemInList WHERE List_ID=(?) AND Item=(?)", [List_ID, binary:bin_to_list(Item)])
    end.	
getLists(DB,L) ->
	{ok,_,Res} = mysql:query(DB,<<"SELECT 2Lists.ListName FROM 2Lists INNER JOIN 1GroCodeUsers ON 1GroCodeUsers.Users_ID = 2Lists.User_ID WHERE 1GroCodeUsers.Email = (?)">>,
				[binary:bin_to_list(hd(L))]),
	[hd(X) || X <- Res].
getSubLists(DB,L) ->
     {ok,_,Res} = mysql:query(DB, <<"SELECT ListName FROM 2Lists INNER JOIN (1GroCodeUsers, 3ShareList) ON 1GroCodeUsers.Users_ID = 3ShareList.User_ID AND 3ShareList.List_ID = 2Lists.List_ID WHERE 1GroCodeUsers.Email = (?) AND 3ShareList.Subscribe = '1' ">>, 
            [binary:bin_to_list(hd(L))]), 
    [hd(X) || X <- Res] .
getNotifications(DB,L) ->
     {ok,_,Res} = mysql:query(DB, <<"SELECT ListName FROM 2Lists INNER JOIN (1GroCodeUsers, 3ShareList) ON 1GroCodeUsers.Users_ID = 3ShareList.User_ID AND 3ShareList.List_ID = 2Lists.List_ID WHERE 1GroCodeUsers.Email = (?) AND 3ShareList.Subscribe = '0' ">>, 
            [binary:bin_to_list(hd(L))]), 
    [hd(X) || X <- Res] .
addList(DB,[Email,List]) -> 
	%check if the list already exists
    {ok,_, Check} = mysql:query(DB,"SELECT 2Lists.List_ID FROM 2Lists 
								INNER JOIN 1GroCodeUsers ON 2Lists.User_ID = 1GroCodeUsers.Users_ID 
								WHERE 2Lists.ListName = (?) AND 1GroCodeUsers.Email = (?)",
								[binary:bin_to_list(List),binary:bin_to_list(Email)]),
	case Check of
		% list doesn't exists 
		[] ->
			%Search for Users_ID
			{ok, _, Res} = mysql:query(DB, "SELECT Users_ID FROM 1GroCodeUsers WHERE Email = (?)", [binary:bin_to_list(Email)]),
			%didn't check if email exists cuz it's stupid
			[[Users_ID]]=Res,
			%Insert User and list name to the table List
			mysql:query(DB, "INSERT INTO  2Lists (ListName, User_ID) VALUES (?, ?)", [binary:bin_to_list(List), Users_ID]);
		_ -> error
	end.	
delList(DB,[Email,List]) -> 
	%check if the list already exists
    {ok,_, Check} = mysql:query(DB,"SELECT 2Lists.List_ID FROM 2Lists 
								INNER JOIN 1GroCodeUsers ON 2Lists.User_ID = 1GroCodeUsers.Users_ID 
								WHERE 2Lists.ListName = (?) AND 1GroCodeUsers.Email = (?)",
								[binary:bin_to_list(List),binary:bin_to_list(Email)]),
	case Check of 
		%list doesn't exists
		[] -> 
			error;	
		_ ->
			%Search for Users_ID
			{ok, _, Res} = mysql:query(DB, "SELECT Users_ID FROM 1GroCodeUsers WHERE Email = (?)", [binary:bin_to_list(Email)]),
			%didn't check if email exists cuz it's stupid
			[[Users_ID]]=Res,
			mysql:query(DB, "DELETE FROM  2Lists WHERE ListName=(?) AND User_ID=(?)", [binary:bin_to_list(List), Users_ID])
	end.
confirmShare(DB, Client_ID, List) ->
	%get the list id
    {ok,_,Res} = mysql:query(DB, "SELECT 3ShareList.ShareList_ID FROM 3ShareList
    INNER JOIN (1GroCodeUsers , 2Lists) ON 2Lists.List_ID=3ShareList.List_ID AND 1GroCodeUsers.Users_ID = 3ShareList.User_ID Where 1GroCodeUsers.Email=(?) AND 2Lists.ListName = (?) AND 3ShareList.Subscribe ='0'",
    [binary:bin_to_list(Client_ID), binary:bin_to_list(List)]),
    %exists
    io:format(">>>>>>>>RES ~p", [Res]),
     case Res of
    % if not
    [] -> error;
    %exists
    _ -> [[List_ID]]=Res,
        io:format(">>>>>>>>List_ID ~p", [List_ID]),
		%Puts item to ItemInList.
		mysql:query(DB, "UPDATE 3ShareList Set Subscribe='1' WHERE 3ShareList.ShareList_ID=(?)", [List_ID])
        end.
invite(DB,List,Client_ID, Email)-> 
        {ok,_,Res_UserID} = mysql:query(DB, "SELECT 1GroCodeUsers.Users_ID FROM 1GroCodeUsers WHERE 1GroCodeUsers.Email = (?)", [binary:bin_to_list(Email)] ),
         case Res_UserID of
        % if not
        [] -> error;
        %exists
        _ -> [[User_ID]]=Res_UserID,
            {ok,_, Res_ListID} = mysql:query(DB,"SELECT 2Lists.List_ID FROM 2Lists INNER JOIN 1GroCodeUsers ON 2Lists.User_ID = 1GroCodeUsers.Users_ID WHERE 2Lists.ListName = (?) AND 1GroCodeUsers.Email = (?)", [binary:bin_to_list(List),binary:bin_to_list(Client_ID)]),
            case Res_ListID of
                % if not
                [] -> error;
                %exists
                _ -> [[List_ID]]=Res_ListID,
                    {ok,_, Check}=mysql:query(DB, "SELECT List_ID FROM              3ShareList WHERE List_ID= (?) AND User_ID=(?)",
                    [List_ID, User_ID]),
                        %Check if list is already sharead.
                        case Check of
                            [] ->    %Puts list to invited to subscribe.
                                    mysql:query(DB, "INSERT INTO  3ShareList (List_ID, User_ID, Subscribe) VALUES (?, ?, '0');", [List_ID, User_ID]);
                            _ ->    list_already_shared
                end                    
            end
        end.
    rejectInvite(DB, List, Email) ->
        {ok,_,Res} = mysql:query(DB, "SELECT 3ShareList.ShareList_ID FROM 3ShareList
        INNER JOIN (1GroCodeUsers , 2Lists) ON 2Lists.List_ID=3ShareList.List_ID AND 1GroCodeUsers.Users_ID = 3ShareList.User_ID Where 1GroCodeUsers.Email=(?) AND 2Lists.ListName = (?) ", %AND 3ShareList.Subscribe ='0'
        [binary:bin_to_list(Email), binary:bin_to_list(List)]),
        %exists
        io:format(">>>>>>>>RES ~p", [Res]),
         case Res of
        % if not
        [] -> error;
        %exists
        _ -> [[List_ID]]=Res,
            io:format(">>>>>>>>List_ID ~p", [List_ID]),
            %Delete invite in share lists.
            mysql:query(DB, "DELETE FROM  3ShareList WHERE 3ShareList.ShareList_ID = (?)", [List_ID])
            end.
        
        
            
       
 
     
