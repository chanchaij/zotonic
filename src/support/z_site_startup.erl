%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2010 Marc Worrell
%% @date 2010-05-18
%% @doc This module is started after the complete site_sup has been booted. 
%% This is the moment for system wide initializations.

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

-module(z_site_startup).
-author("Marc Worrell <marc@worrell.nl>").

-export([start_link/1]).

%% @spec start_link() -> ignore
%% @doc Perform all site startup routines.
start_link(SiteProps) ->
    {host, Host} = proplists:lookup(host, SiteProps),
    Context = z_context:new(Host),

    % Make sure all modules are started
    z_module_manager:upgrade(Context),

    % Load all translations
    spawn(fun() -> z_trans_server:load_translations(Context) end),
    
    % Let the module handle their startup code, the whole site is now up and running.
    z_notifier:notify(site_startup, Context),
    ignore.
