%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @date 2009-12-04
%% @doc Calendar view

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

-module(scomp_calendar_calview).
-behaviour(gen_scomp).

-export([init/1, varies/2, terminate/2, render/4]).

-include_lib("zotonic.hrl").
-include_lib("../include/mod_calendar.hrl").

init(_Args) -> {ok, []}.
varies(_Params, _Context) -> undefined.
terminate(_State, _Context) -> ok.

render(Params, Vars, Context, _State) ->
	WeekStartConf = m_config:get_value(mod_calendar, weekstart, 1, Context),
	DayStartConf = m_config:get_value(mod_calendar, daystart, 0, Context),
	Date = z_convert:to_datetime(proplists:get_value(date, Params)),
	WeekStart = z_convert:to_integer(proplists:get_value(weekstart, Params, WeekStartConf)),
	DayStart = z_convert:to_integer(proplists:get_value(daystart, Params, DayStartConf)),
	DateFormat = z_convert:to_list(proplists:get_value(date_format, Params, "b j")),
    Period = proplists:get_value(period, Vars, week),
	
	Date1 = case Date of
		undefined -> erlang:localtime();
		_ -> Date
	end,
	
	case Period of
	    week ->
        	%% Calculate the datetime range for the weekview.
        	{StartDate, EndDate} = z_datetime:week_boundaries(Date1, WeekStart),
        	{StartDate1, EndDate1} = case DayStart of
        									0 -> 
        										{StartDate, EndDate};
        									H ->
        										{SD,_ST} = StartDate,
        										{ED,_ET} = z_datetime:next_day(EndDate),
        										{{SD,{H,0,0}}, {ED, {H-1,59,59}}}
        								 end,
        	PeriodVars = [];
        month ->
            {StartDate, EndDate} = z_datetime:month_boundaries(Date1),
        	{StartDateWeek, _} = z_datetime:week_boundaries(StartDate, WeekStart),
        	{_, EndDateWeek} = z_datetime:week_boundaries(EndDate, WeekStart),
            {StartDate1, EndDate1} = case DayStart of
        									0 -> 
        										{StartDateWeek, EndDateWeek};
        									H ->
        										{SD,_ST} = StartDateWeek,
        										{ED,_ET} = z_datetime:next_day(EndDateWeek),
        										{{SD,{H,0,0}}, {ED, {H-1,59,59}}}
        								 end,
        	PeriodVars = [
        	    {month_dates, month_dates(StartDate1, EndDate1)}
        	]
    end,
	
	%% Search all events within the range
    #search_result{result=Result} = z_search:search({events, [{start, StartDate1}, {'end', EndDate1}]}, {1,2000}, Context),

	%% Prepare for displaying, crop events to the week.
	{Calendar, WholeDay} = group_by_day(Result, DayStart),
    WeekCalendar = filter_period(Calendar, StartDate1, EndDate1),
    WeekWholeDay = filter_period(WholeDay, StartDate1, EndDate1),
	WeekDates = week_dates(StartDate1),
	DayHours = case DayStart of
		0 -> lists:seq(0,23);
		N -> lists:seq(N,23) ++ lists:seq(0,N-1)
	end,
	
	EventDivs = [ {D,event2div(Evs)} || {D,Evs} <- WeekCalendar ],
	WholeDayProps = [ {D,[calevent_to_proplist(E2) || E2 <- Evs]} || {D,Evs} <- WeekWholeDay ],

	TemplateVars = PeriodVars ++ [
		{day_hours, DayHours},
		{week_dates, WeekDates},
		{event_divs, EventDivs},
		{date_format, DateFormat},
        {whole_day, WholeDayProps},
        {period, Period}
	],
	
	Template = case Period of week -> "_calview_week.tpl"; month -> "_calview_month.tpl" end,
	Html = z_template:render(Template, TemplateVars, Context),
    {ok, Html}.
    

%% @doc Recalculate the events to divs with offsets and unique z-index
event2div(CalEvents) ->
	C1 = lists:sort(fun compare_date_start/2, CalEvents),
	event2div(C1, 0, []).
	
	compare_date_start(#calendar_event{date_start=A}, #calendar_event{date_start=B}) ->
		A > B.
	
event2div([], _N, Acc) ->
    lists:reverse(Acc);
event2div([Event=#calendar_event{date_start=DateStart, date_end=DateEnd, duration=Duration, 
                           sec_start=SecStart, level=Level}|Rest], N, Acc) ->
    case DateStart of
        {_, {0,0,0}} = DateEnd ->
            %% Wholeday event; skip.
            event2div(Rest, N+1, Acc);
        _ -> 
            Acc1 = [ calevent_to_proplist(Event) ++
                     [ {z_index, 1000*Level + N},
                       {height_em, max(Duration / 1800, 0.75)},
                       {top_em, SecStart / 1800}] | Acc],
            event2div(Rest, N+1, Acc1)
    end.

calevent_to_proplist(#calendar_event{id=Id, date_start=DateStart, date_end=DateEnd, duration=Duration, 
                           level=Level, max_level=MaxLevel}) ->
    [{id, Id},
     {date_start, DateStart},
     {date_end, DateEnd},
     {duration, Duration},
     {level,Level},
     {max_level, MaxLevel}].

max(A,B) when A > B -> A;
max(_,B) -> B.

group_by_day(Result, DayStart) ->
	CalEvents = [ #calendar_event{id=Id, date_start=nosecs(Start), date_end=nosecs(sensible_end_date(Start,End))} || {Id,Start,End} <- Result ],
	calendar_sort:sort(CalEvents, DayStart).
	
	nosecs({D,{H,I,_}}) -> {D, {H,I,0}}.

	sensible_end_date(Start, {{9999,_,_},_}) -> Start;
	sensible_end_date(Start, End) when Start > End -> Start;
	sensible_end_date(_Start, End) -> End.

filter_period(Days, StartDate, EndDate) ->
	{SD,_} = StartDate,
	{ED, _} = z_datetime:next_second(EndDate),
	lists:sort(lists:filter(fun({D,_Evs}) -> D >= SD andalso D < ED end, Days)).
	
%% Given the start day, return the dates of the week.
week_dates(Date) ->
	week_dates(7, Date, []).
	
	week_dates(1, Date, Acc) ->
		lists:reverse([Date|Acc]);
	week_dates(N, Date, Acc) ->
		week_dates(N-1, z_datetime:next_day(Date), [Date|Acc]).


month_dates(S, E) ->
    month_dates(S, E, []).
    
    month_dates(S, E, Acc) when S > E ->
        lists:reverse(Acc);	
    month_dates(S, E, Acc) ->
        month_dates(z_datetime:next_day(S), E, [S|Acc]).

    