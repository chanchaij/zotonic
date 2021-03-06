%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2010 Marc Worrell
%% @date 2010-01-15
%%
%% @doc Model for managing the comments on a page.

%% Copyright 2010 Marc Worrell
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% 
%%     http://www.apache.org/licenses/LICENSE-2.0
%% 
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(m_comment).
-author("Marc Worrell <marc@worrell.nl").

-behaviour(gen_model).

%% interface functions
-export([
    m_find_value/3,
    m_to_list/2,
    m_value/2,
    
    list_rsc/2,
    get/2,
    insert/5,
    delete/2,
    gravatar_code/1,
    
    search/3
]).

-include_lib("zotonic.hrl").


%% @doc Fetch the value for the key from a model source
%% @spec m_find_value(Key, Source, Context) -> term()
m_find_value(rsc, #m{value=undefined} = M, _Context) ->
    M#m{value=rsc};
m_find_value(Id, #m{value=rsc}, Context) ->
    % All comments of the resource.
    list_rsc(Id, Context);
m_find_value(_Key, #m{value=undefined}, _Context) ->
   undefined.

%% @doc Transform a m_config value to a list, used for template loops
%% @spec m_to_list(Source, Context)
m_to_list(_, _Context) ->
    [].

%% @doc Transform a model value so that it can be formatted or piped through filters
%% @spec m_value(Source, Context) -> term()
m_value(#m{value=undefined}, _Context) ->
    undefined.



%% @doc List all comments of the resource.
%% @spec list_rsc(int(), Context) -> [ PropList ]
list_rsc(RscId, Context) when is_integer(RscId) ->
    F = fun() ->
        z_db:assoc_props("select * from comment where rsc_id = $1 order by created asc", [RscId], Context)
    end,
    z_depcache:memo(F, {comment_rsc, RscId}, 0, Context).


%% @spec Fetch a specific comment from the database.
%% @spec get(int(), Context) -> PropList
get(CommentId, Context) ->
    z_db:assoc_props_row("select * from comment where id = $1", [CommentId], Context).


%% @doc Insert a new comment. Fetches the submitter information from the Context.
%% @spec insert(Id:int(), Name::string(), Email::string(), Message::string(), Context) -> {ok, CommentId} | {error, Reason}
%% @todo Insert external ip address and user agent string
insert(RscId, Name, Email, Message, Context) ->
	case z_acl:rsc_visible(RscId, Context) 
		and (z_auth:is_auth(Context) 
			orelse z_convert:to_bool(m_config:get_value(mod_comment, anonymous, true, Context))) of
		true ->
		    Email = z_string:trim(Email),
		    Name1 = z_html:escape(z_string:trim(Name)),
		    Message1 = z_html:escape_link(z_string:trim(Message)),
		    KeepInformed = z_convert:to_bool(z_context:get_q("keep_informed", Context, false)),
		    Props = [
		        {rsc_id, z_convert:to_integer(RscId)},
		        {is_visible, true},
		        {user_id, z_acl:user(Context)},
		        {persistent_id, z_context:persistent_id(Context)},
		        {name, Name1},
		        {message, Message1},
		        {email, Email},
		        {gravatar_code, gravatar_code(Email)},
		        {keep_informed, KeepInformed},
		        {ip_address, ""},
		        {user_agent, ""}
		    ],
		    case z_db:insert(comment, Props, Context) of
		        {ok, _CommentId} = Result ->
		            z_depcache:flush({comment_rsc, RscId}, Context),
		            Result;
		        {error, _} = Error ->
		            Error
		    end;
		false ->
			{error, eacces}
	end.


%% @doc Delete a comment.  Only possible if the user has edit permission on the page.
delete(CommentId, Context) ->
    case z_db:q1("select rsc_id from comment where id = $1", [CommentId], Context) of
        undefined -> {error, enoent};
        RscId ->
            case z_acl:rsc_editable(RscId, Context) of
                true ->
                    z_db:q("delete from comment where id = $1", [CommentId], Context),
                    z_depcache:flush({comment_rsc, RscId}, Context),
                    ok;
                false ->
                    {error, eacces}
            end
    end.


%% @doc Return the gravatar code of an email address. See also http://gravatar.com/
%% @spec gravatar_code(Email) -> list()
gravatar_code(Email) ->
    z_string:to_lower(z_utils:hex_encode(erlang:md5(z_string:to_lower(Email)))).



%% @doc Return the search as used by z_search and the search model.
search({recent_comments, []}, _OfffsetLimit, _Context) ->
    #search_sql{
        select="c.*",
        from="comment c",
        order="c.created desc",
        assoc=true
    }.
