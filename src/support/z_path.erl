%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @date 2009-08-05
%% @doc Defines all paths for files and directories of a site.

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

-module(z_path).
-author("Marc Worrell <marc@worrell.nl").

-export([
    media_preview/1,
    media_archive/1,
    files_subdir/2,
    files_subdir_ensure/2
]).

-include("zotonic.hrl").

%% @doc Return the path to the media preview directory
%% @spec media_preview(#context) -> filename()
media_preview(Context) ->
    files_subdir("preview", Context).

%% @doc Return the path to the media archive directory
%% @spec media_archive(#context) -> filename()
media_archive(Context) ->
    files_subdir("archive", Context).

%% @doc Return the path to a files subdirectory
%% @spec media_archive(#context) -> filename()
files_subdir(SubDir, #context{host=Host}) ->
        filename:join([z_utils:lib_dir(priv), "sites", Host, "files", z_convert:to_list(SubDir)]).

%% @doc Return the path to a files subdirectory and ensure that the directory is present
%% @spec files(SubDir, #context) -> filename()
files_subdir_ensure(SubDir, Context) ->
    Dir = files_subdir(SubDir, Context),
    ok = filelib:ensure_dir(filename:join([Dir, ".empty"])),
    Dir.
