%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @date 2009-06-08
%% @doc The base module, implementing basic Zotonic scomps, actions, models and validators.

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

-module(mod_base).
-author("Marc Worrell <marc@worrell.nl>").

-mod_title("Zotonic Base").
-mod_description("Base supplies all basic scomps, actions and validators.").
-mod_prio(9999).

-include_lib("zotonic.hrl").

%% interface functions
-export([
    observe_media_stillimage/2,
    observe_scomp_script_render/2,
    event/2
]).

%% @doc Return the filename of a still image to be used for image tags.
%% @spec media_stillimage(Notification, _Context) -> undefined | {ok, Filename}
observe_media_stillimage({media_stillimage, _Id, Props}, Context) ->
    case proplists:get_value(mime, Props) of
        undefined -> undefined;
        [] -> undefined;
        Mime ->
            case z_media_preview:can_generate_preview(Mime) of
                true ->
                    %% Let media preview handle this.
                    undefined;
                false ->
                    %% Serve an existing icon.
                    [A,B] = string:tokens(z_convert:to_list(Mime), "/"),
                    case z_module_indexer:find(lib, "images/mimeicons/"++A++[$-,B]++".png", Context) of
                        {ok, File} -> {ok, File};
                        {error, enoent} ->
                            case z_module_indexer:find(lib, "images/mimeicons/"++A++".png", Context) of
                                {ok, File} -> {ok, File};
                                {error, enoent} -> {ok, "lib/images/mimeicons/application-octet-stream.png"}
                            end
                    end
            end
    end.


%% @doc Part of the {% script %} rendering in templates
observe_scomp_script_render({scomp_script_render, false, _Args}, Context) ->
    NotifyPostback = z_render:make_postback_info(postback_notify, "", undefined, undefined, ?MODULE, Context),
    DefaultFormPostback = z_render:make_postback_info("", "submit", undefined, undefined, undefined, Context),
    [<<"z_init_postback_forms();\nz_default_form_postback = \"">>, DefaultFormPostback, 
     <<"\";\nz_default_notify_postback = \"">>, NotifyPostback, $", $;];
observe_scomp_script_render({scomp_script_render, true, _Args}, _Context) ->
    [].


%% @doc Handle the javascript event postback
event({postback, postback_notify, _TriggerId, _TargetId}, Context) ->
    Message = z_context:get_q("z_msg", Context), 
    case z_notifier:first({postback_notify, Message, Context}, Context) of
        undefined -> Context;
        #context{} = Context1 -> Context1
    end.


%%====================================================================
%% support functions
%%====================================================================

