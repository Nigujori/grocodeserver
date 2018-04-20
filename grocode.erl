-module(grocode).
-export([start/0,init/0, sup/0]).
-import(json,[decode/1,encode/1]).
-import(database,[connect/0,loginQuery/2,registerQuery/2,emailQuery/2,getItemsFromList/2,addItem/2,delItem/2,getLists/2,delList/2]).
%A supervisor 
sup() ->
	%Flag the process
    process_flag(trap_exit,true),
    %Death signal received 
    receive {'EXIT',_,_} ->
		%restart the server
        start() 
    end.

start() ->
	%%check if the process is already spawned
	case whereis(sts) of
	  %%in case not
	  undefined -> 
	  %%spawn it and return the PID
	  Pid=spawn_link(grocode, init, []),
	  %start a supervisor for this process 
      spawn_link(grocode, sup, []),
      %register the process
	  register(sts, Pid),
	  {ok, Pid};
	  %%in case it is already spawned just return the PID
	  _ -> 
	  %return {ok,PID}
	  {ok, whereis(sts)}
	end.

init()->
  %Connect to PRATA broker.hivemq.com 54.154.153.243 broker.hivemq.com 127.0.0.1
  {ok, C} = emqttc:start_link([{host, "54.154.153.243"}, 
  %client ID for this MQTT client
  {client_id, <<"GroMasterJohanRingstrom">>},
  %keepAlive 
  {keepalive, 1000},
  {connack_timeout, 60}]),
  %subscribe to all the sub topics with QOS 1
  emqttc:subscribe(C, <<"Gro/#">>, qos1),
  %monitor the connection to MQTT process 'C'
  RefMqtt = erlang:monitor(process, C),
  %if it dies then kill this process as well so we can restart it from the supervisor
  spawn_link(fun() -> receive {'DOWN', RefMqtt, process, _, _} -> exit(error) end end),
  %connect to DB
  Db = database:connect(),
  %monitor the connection to db 'Db'
  RefDb = erlang:monitor(process, Db),
  %if it dies then kill this process as well so we can restart it from the supervisor
  spawn_link(fun() -> receive {'DOWN', RefDb, process, _, _} -> exit(error) end end),
  loop(C,Db,0).
%@para C is MQTT service PID, DB is the PID of the connection to the DB, and the loop number N we just did it for debugging it's not essential at all
loop(C,DB,N) -> 
	receive 
		%receive an MQTT message 
		{publish ,Topic, Message} ->
			%decode the message notice in some request some of these varabiles will be equal to null
			{Client_id,List,Req,Item}=json:decode(Message),
			%just to debug
			io:format("~p~n",[Req]),
			%in case of a login request {item is password, CLient_id is Email}
			%in case of a register request {List is Name, item is password, CLient_id is Email} 
			case Req of
				<<"login">> ->
					%search the database for this credential  
					Res = database:loginQuery(DB,[Client_id,Item]),
						case Res of 
							%not found
							[] ->
								emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"error">>}]));
							%found	
							_ ->
								emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]))
						end,	
					loop(C,DB,N);
				<<"register">> ->
					%search the database for this credential  
					Res = database:loginQuery(DB,[Client_id,Item]),
						case Res of 
							%user not found
							[] ->
								%check if the email already exists
								E = database:emailQuery(DB,[Client_id]),
								case E of
									% Email doesn't exists
									[] -> 
										database:registerQuery(DB,[Client_id,Item,binary:list_to_bin([N]),List]),
										emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
									% Email exists	
									_ -> 
										emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"email_already_exists">>}])) 
								end,
								loop(C,DB,N);
							_ ->
								emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"email_already_exists">>}])), loop(C,DB,N)
						end,	
					loop(C,DB,N);
				%% add the values, update the dict and reply to client (on the same topic)
				<<"add">> ->
					%insert values into databse
					Res = database:addItem(DB,[List,Client_id,Item]),
					case Res of 
						ok -> emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
						%database error
						_ ->  emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"error">>}]))
					end,
					loop(C,DB,N);
                <<"add-subItem">> ->
					io:format("main loop at add and the Client is~p~n",[Client_id]), io:format("List is ~p~n",[List]),io:format("Item is~p~n",[Item]),
					Res = database:addSubItem(DB,[List,Client_id,Item]),
					case Res of 
						ok -> emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
						_ ->  emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"error">>}]))
					end,
					loop(C,DB,N);
				%% delete the values, update the dict and reply to client (on the same topic)
				<<"delete">> ->
					Res = database:delItem	(DB,[List,Client_id,Item]),
					case Res of 
						ok -> emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
						_ ->  emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"error">>}]))
					end,
					loop(C,DB,N);
				%% get the values, reply to client (on the same topic)
				<<"fetch">> -> 
                    BoughtOrNot=0,
					Res = database:getItemsFromList(DB,Client_id,List,BoughtOrNot),
                    ReqTopic = "Gro/"++binary_to_list(Client_id)++"/"++binary_to_list(Req),
					case Res of
					[] -> emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,
                    <<"done">>},{<<"data">>,[]}]));
					_ -> emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,<<"done">>},{<<"data">>,json:encode(Res)}]))
					end,
					loop(C,DB,N);
                <<"fetch-SubItems">> -> 
                    BoughtOrNot=0,
					Res = database:getSubItems(DB, Client_id, List, BoughtOrNot ),
                    ReqTopic = "Gro/"++binary_to_list(Client_id)++"/"++binary_to_list(Req),
					case Res of
					[] -> emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,
                    <<"done">>},{<<"data">>,[]}]));
					_ -> emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,<<"done">>},{<<"data">>,json:encode(Res)}]))
					end,
					loop(C,DB,N);
                 <<"fetch-BoughtSubItem">> -> 
                    BoughtOrNot=1,
					Res = database:getSubItems(DB, Client_id, List, BoughtOrNot ),
                    ReqTopic = "Gro/"++binary_to_list(Client_id)++"/"++binary_to_list(Req),
					case Res of
					[] -> emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,
                    <<"done">>},{<<"data">>,[]}]));
					_ -> emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,<<"done">>},{<<"data">>,json:encode(Res)}]))
					end,
					loop(C,DB,N);
                <<"fetch-bought">> -> 
                    BoughtOrNot=1,
					Res = database:getItemsFromList(DB,Client_id,List,BoughtOrNot),
                    ReqTopic = "Gro/"++binary_to_list(Client_id)++"/"++binary_to_list(Req),
					case Res of
					[] -> emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,
                    <<"done">>},{<<"data">>,[]}]));
					_ -> emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,<<"done">>},{<<"data">>,json:encode(Res)}]))
					end,
					loop(C,DB,N);
                <<"setToBought">> -> 
					Res = database:setToBought	(DB,[List,Client_id,Item]),
					case Res of 
						ok -> emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
						_ ->  emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"error">>}]))
					end,
					loop(C,DB,N);
                <<"setSubItemsToBought">> -> 
					Res = database:setSubItemsToBought(DB,[List,Client_id,Item]),
					case Res of 
						ok -> emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
						_ ->  emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"error">>}]))
					end,
					loop(C,DB,N);
				<<"fetch-lists">> ->
					Res=database:getLists(DB,[Client_id]),
                     ReqTopic = "Gro/"++binary_to_list(Client_id)++"/"++binary_to_list(Req),
					case Res of
						[] ->
							emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,<<"error">>}]));
						_ -> 
							emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,<<"done">>},{<<"data">>,json:encode(Res)}]))
							
					end,
					loop(C,DB,N);	
                <<"fetch-SubscriptionList">> ->
					Res=database:getSubLists(DB,[Client_id]),
                    io:format(">>????Res ~p", [Res]),
                    ReqTopic = "Gro/"++binary_to_list(Client_id)++"/"++binary_to_list(Req),
					case Res of
						[] ->
							emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,<<"error">>}]));
						_ -> 
							emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,<<"done">>},{<<"data">>,json:encode(Res)}]))
							
					end,
					loop(C,DB,N);
                  <<"confirmShare">> -> 
					Res = database:confirmShare(DB,Client_id,List),
					case Res of 
						ok -> emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
						_ ->  emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"error">>}]))
					end,
					loop(C,DB,N);
                <<"fetch-Notifications">> ->
					Res=database:getNotifications(DB,[Client_id]),
                    io:format(">>????Res ~p", [Res]),
                    ReqTopic =
                    "Gro/"++binary_to_list(Client_id)++"/"++binary_to_list(Req),
					case Res of
						[] ->
							emqttc:publish(C,list_to_binary(ReqTopic) , jsx:encode([{<<"reply">>,<<"error">>}]));
						_ -> 
							emqttc:publish(C, list_to_binary(ReqTopic), jsx:encode([{<<"reply">>,<<"done">>},{<<"data">>,json:encode(Res)}]))
							
					end,
					loop(C,DB,N);
				<<"add-list">> -> 
					Res = database:addList(DB,[Client_id,List]),
					case Res of 
						ok -> emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
						_ -> emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"list_already_exists">>}]))
					end,
					loop(C,DB,N);
				<<"delete-list">> -> 
					Res = database:delList(DB,[Client_id,List]),
					case Res of
						ok -> 
							emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
						_ ->
						    emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"list_doesn't_exists">>}]))
					end,	
					loop(C,DB,N);
                <<"delete-SubItem">> -> 
					io:format("main loop at add and the Client is~p~n",[Client_id]), io:format("List is ~p~n",[List]),io:format("Item is~p~n",[Item]),
					Res = database:deleteSubItem(DB,List,Client_id,Item),
					case Res of 
						ok -> emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
						_ ->  emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"error">>}]))
					end,
					loop(C,DB,N);
                <<"invite">> ->
					io:format("main loop at add and the Client is~p~n",[Client_id]),io:format("List is ~p~n",[List]),io:format("Item is~p~n",[Item]),
					Res = database:invite(DB,List,Client_id,Item),
					case Res of 
						ok -> emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
						_ ->  emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"error">>}]))
					end,
					loop(C,DB,N);
                <<"reject-invite">> ->
                    io:format("main loop at add and the Client is~p~n",[Client_id]), io:format("List is ~p~n",[List]),io:format("Item is~p~n",[Item]),
					Res = database:rejectInvite(DB,List,Client_id),
					case Res of 
						ok -> emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"done">>}]));
						_ ->  emqttc:publish(C, Topic, jsx:encode([{<<"reply">>,<<"error">>}]))
					end,
					loop(C,DB,N);
				<<"fetch-sh-list">> -> loop(C,DB,N);
				%% in case of a decode crash just loop again
				_ -> loop(C,DB,N)
			end
	end.	
