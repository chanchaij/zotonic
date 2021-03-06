-module(survey_q_thurstone).

-export([
    new/0,
    question_props/1,
    render/1,
    answer/2
]).

-include("../survey.hrl").

new() ->
    Q = #survey_question{
        type = thurstone, 
        name = z_ids:identifier(5),
        question = "",
        text = "This editor is very intuitive.
This editor is fairly easy to use.
This editor gets the job done.
This editor is not that easy to use.
This editor is very confusing."
    },
    render(Q).

question_props(Q) ->
    [
        {explanation, ""},
        
        {has_question, true},
        {has_text, true},
        {has_name, true},
        
        {question_label, ""},
        {text_label, "Options"},
        {text_explanation, "<p>Enter the options below, one per line.</p>"},
        
        {type, Q#survey_question.type},
        {name, Q#survey_question.name},
        {question, Q#survey_question.question},
        {text, Q#survey_question.text}
    ].

render(Q) ->
    Name = z_html:escape(Q#survey_question.name),
    Options = split_options(Q#survey_question.text),
    Rs = radio(Options, 1, Name, []),
    Q#survey_question{
        question = iolist_to_binary(Q#survey_question.question),
        html = iolist_to_binary([
            "<p class=\"question\">", z_html:escape(Q#survey_question.question), "</p>",
            "<p class=\"thurstone\">",
            Rs,
            "</p"
            ])
    }.



split_options(Text) ->
    Options = string:tokens(z_string:trim(z_convert:to_list(Text)), "\n"),
    [ z_string:trim(Option) || Option <- Options ].

radio([], _N, _Name, Acc) ->
    lists:reverse(Acc);
radio([""|T], N, Name, Acc) ->
    radio(T, N, Name, Acc);
radio([H|T], N, Name, Acc) ->
    R = ["<input class=\"survey-q\" type=\"radio\" name=\"",Name,"\" value=\"", integer_to_list(N),"\"> ", z_html:escape(H), "<br />"],
    radio(T, N+1, Name, [R|Acc]).


answer(Q, Context) ->
    Name = Q#survey_question.name,
    Options = split_options(Q#survey_question.text),
    case z_context:get_q(Name, Context) of
        undefined -> {error, missing};
        N -> {ok, [{Name, lists:nth(list_to_integer(N), Options)}]}
    end.

    