-module(json).
%% module to decode JSON objects into erlang terms 
-export([encode/1,decode/1]).	
%encode a list of binary data to fulfill our RFC

encode(L) ->
	%encode {"data":[{"item":"item1"},{"item":"item2"}...etc]}
	[[{<<"item">>,X}] || X <- L].

decode(Message) ->
		try
			decodeSmart(Message)
		catch
			error:E->
				%return null values in case of any failure 
				{<<"null">>,<<"null">>,<<"null">>,<<"null">>}
		end.		
decodeSmart(Message) -> 
	Data = jsx:decode(Message),
	%get the request
	Req = proplists:get_value(<<"request">>, Data),
	case Req of
		%no request key (the reply from the server itself)
		undefined ->
			%return null values  for the main loop
			{<<"null">>,<<"null">>,<<"null">>,<<"null">>};
		<<"register">> ->
			%values inside the data key
			Data1 = proplists:get_value(<<"data">>,Data),
			%return {email,name,request,passowrd}
			{
			proplists:get_value(<<"email">>,Data1),
			proplists:get_value(<<"name">>,Data1),
			Req,
			proplists:get_value(<<"password">>,Data1)
			};
		<<"login">> ->
			%values inside the data key
			Data1 = proplists:get_value(<<"data">>,Data),
			%return {email,null,request,passowrd}
			{
			proplists:get_value(<<"email">>,Data1),
			<<"null">>,
			proplists:get_value(<<"request">>,Data),
			proplists:get_value(<<"password">>,Data1)
			};
		_ ->
			Data1 = proplists:get_value(<<"data">>,Data),
			case Data1 of
				%we don't have the key "data"
				%@return {client-id,list,request,null}
				undefined ->
					{
					proplists:get_value(<<"client_id">>,Data),
					proplists:get_value(<<"list">>,Data),
					Req,
					<<"null">>
					};
				%return the keys as shown below, notice some keys might be "undefined"	
				_ ->
					{
					proplists:get_value(<<"client_id">>,Data),
					proplists:get_value(<<"list">>,Data),
					Req,
					proplists:get_value(<<"item">>,Data1)
					}	
			end		
	end.
