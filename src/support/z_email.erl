%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @date 2009-11-02
%%
%% @doc Send e-mail to a recipient. Optionally queue low priority messages.

%% Copyright 2009 Marc Worrell
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

-module(z_email).
-author("Marc Worrell <marc@worrell.nl>").

%% interface functions
-export([
	get_admin_email/1,
	send_admin/3,
	
	send/2,
	
    send/4,
    send_render/4,
    send_render/5,

    sendq/4,
    sendq_render/4,
    sendq_render/5,
    
    split_name_email/1,
    combine_name_email/2
]).

-include_lib("zotonic.hrl").


%% @doc Fetch the e-mail address of the site administrator
get_admin_email(Context) ->
	case m_config:get_value(zotonic, admin_email, Context) of
		undefined -> 
			case m_site:get(admin_email, Context) of
				undefined -> 
					case m_rsc:p_no_acl(1, email, Context) of
						Empty when Empty == undefined orelse Empty == <<>> ->
							hd(string:tokens("wwwadmin@" ++ z_convert:to_list(m_site:get(hostname, Context)), ":"));
						Email -> Email
					end;
				Email -> Email
			end;
		Email -> Email
	end.

%% @doc Send a simple text message to the administrator
send_admin(Subject, Message, Context) ->
	case get_admin_email(Context) of
		undefined -> 
			error;
		Email ->
			Subject1 = [
				$[,
				z_context:hostname(Context),
				"] ",
				Subject
			],
			Message1 = [
				Message, 
				"\n\n-- \nYou receive this e-mail because you are registered as the admin of the site ",
				z_context:abs_url("/", Context)
			],
			z_notifier:notify1(#email{queue=false, to=Email, subject=Subject1, text=Message1}, Context)
	end.

%% @doc Send an email message defined by the email record.
send(#email{} = Email, Context) ->
	z_notifier:notify1(Email, Context).

%% @doc Send a simple text message to an email address
send(To, Subject, Message, Context) ->
	z_notifier:notify1(#email{queue=false, to=To, subject=Subject, text=Message}, Context).

%% @doc Queue a simple text message to an email address
sendq(To, Subject, Message, Context) ->
	z_notifier:notify1(#email{queue=true, to=To, subject=Subject, text=Message}, Context).

%% @doc Send a html message to an email address, render the message using a template.
send_render(To, HtmlTemplate, Vars, Context) ->
    send_render(To, HtmlTemplate, undefined, Vars, Context).

%% @doc Send a html and text message to an email address, render the message using two templates.
send_render(To, HtmlTemplate, TextTemplate, Vars, Context) ->
	z_notifier:notify1(#email{queue=false, to=To, from=proplists:get_value(email_from, Vars), 
	                        html_tpl=HtmlTemplate, text_tpl=TextTemplate, vars=Vars}, Context).

%% @doc Queue a html message to an email address, render the message using a template.
sendq_render(To, HtmlTemplate, Vars, Context) ->
    sendq_render(To, HtmlTemplate, undefined, Vars, Context).

%% @doc Queue a html and text message to an email address, render the message using two templates.
sendq_render(To, HtmlTemplate, TextTemplate, Vars, Context) ->
	z_notifier:notify1(#email{queue=true, to=To, from=proplists:get_value(email_from, Vars),
	                        html_tpl=HtmlTemplate, text_tpl=TextTemplate, vars=Vars}, Context).



%% @doc Combine a name and an email address to the format "jan janssen <jan@example.com>"
combine_name_email(Name, Email) ->
    Name1 = z_convert:to_list(Name),
    Email1 = z_convert:to_list(Email),
    case Name1 of
        [] -> Email1;
        _ -> [$"|rfc2047:encode(filter_name(Name1))] ++ "\" <" ++ Email1 ++ ">"
    end.
    
    filter_name(Name) ->
        filter_name(Name, []).
    filter_name([], Acc) ->
        lists:reverse(Acc);
    filter_name([$"|T], Acc) ->
        filter_name(T, [32|Acc]);
    filter_name([$<|T], Acc) ->
        filter_name(T, [32|Acc]);
    filter_name([H|T], Acc) when H < 32 ->
        filter_name(T, [32|Acc]);
    filter_name([H|T], Acc) ->
        filter_name(T, [H|Acc]).

%% @doc Split the name and email from the format "jan janssen <jan@example.com>"
%% @todo Allow multiple email addresses to be found
split_name_email(Email) ->
    Email1 = string:strip(rfc2047:decode(Email)),
    case split_ne(Email1, in_name, [], []) of
        {N, []} ->
            {[], N};
        {E, N} ->
            {E, N}
    end.

split_ne([], _, [], Acc) ->
    {[], lists:reverse(Acc)};
split_ne([], _, Name, Acc) ->
    {Name, lists:reverse(Acc)};
split_ne([$<|T], to_email, Name, []) ->
    split_ne(T, in_email, Name, []);
split_ne([$<|T], in_name, Name, []) ->
    split_ne(T, in_email, Name, []);
split_ne([$>|_], in_email, Name, Acc) ->
    {Name, lists:reverse(Acc)};
split_ne([$"|T], in_name, [], Acc) ->
    split_ne(T, in_qname, [], Acc);
split_ne([$"|T], in_qname, [], Acc) ->
    split_ne(T, to_email, lists:reverse(Acc), []);
split_ne([H|T], to_email, Name, Acc) ->
    split_ne(T, to_email, Name, [H|Acc]);
split_ne([H|T], State, Name, Acc) ->
    split_ne(T, State, Name, [H|Acc]).
