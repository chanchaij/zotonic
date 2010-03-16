%%%-------------------------------------------------------------------
%% @copyright Geoff Cant
%% @author Geoff Cant <geoff@catalyst.net.nz>
%% @version {@vsn}, {@date} {@time}
%% @doc Email MIME encoding library.
%% @end
%%%-------------------------------------------------------------------
-module(esmtp_mime).

-include_lib("../include/esmtp_mime.hrl").

%% API
-export([encode/1, send/5,
         msg/0, msg/3, msg/4,
         from/1, to/1,
         add_text_part/2,
         add_html_part/2,
         add_header/2
]).

-export([test_msg/0,
         send_test/4,
         test/0,
         double_dot/1
]).

%%====================================================================
%% API
%%====================================================================

msg(To, From, Subject) ->
    #mime_msg{boundary=invent_mime_boundary(),
              headers=[{"To", To},
                       {"Subject", Subject},
                       {"From", From},
                       {"Date", httpd_util:rfc1123_date()}
                      ]}.

msg(To, From, Subject, Body) ->
    Msg = msg(To, From, Subject),
    add_text_part(Msg, Body).

msg() ->
    #mime_msg{boundary=invent_mime_boundary(),
              headers=[{"Date", httpd_util:rfc1123_date()}]}.

encode(Msg) ->
    encode_headers(headers(Msg)) ++ "\r\n\r\n" ++
        encode_parts(Msg) ++
        "--" ++ Msg#mime_msg.boundary ++ "--\r\n".

to(#mime_msg{headers=H}) ->
    proplists:get_value("To", H, undefined).

from(#mime_msg{headers=H}) ->
    proplists:get_value("From", H, undefined).

add_text_part(Msg = #mime_msg{parts=Parts}, Text) ->
    TextEncoded = z_quoted_printable:encode(Text),
    Msg#mime_msg{parts=Parts ++ [#mime_part{data=TextEncoded, encoding={"quoted-printable", "text/plain", "utf-8"}}]}.

add_html_part(Msg = #mime_msg{parts=Parts}, Html) ->
    HtmlEncoded = z_quoted_printable:encode(Html),
    Msg#mime_msg{parts=Parts ++ [#mime_part{data=HtmlEncoded, encoding={"quoted-printable", "text/html", "utf-8"}}]}.

add_header(Msg = #mime_msg{headers=H}, Header) ->
    Msg#mime_msg{headers=H++[Header]}.

%%====================================================================
%% Internal functions
%%====================================================================

test_msg() ->
    #mime_msg{boundary=invent_mime_boundary(),
              headers=[{"To", "Geoff Cant <geoff@example.com>"},
                       {"Subject", "Daily Report"},
                       {"From", "Geoff Cant <geoff@example.com>"},
                       {"Date", httpd_util:rfc1123_date()}
                      ],
              parts=[#mime_part{data="This is a test..."},
                     #mime_part{data="This,is,a,test\r\nof,something,ok,maybe",
                                type=attachment,
                                encoding={"8bit","text/plain","utf-8"},
                                name="foo.csv"}]}.
test() ->
    io:format("~s~n", [encode(test_msg())]).

send(Ip, Host, From, To, Msg=#mime_msg{}) ->
    ok = smtpc:sendmail(Ip, Host, From, To, encode(Msg)).

send_test(Ip, Host, From, To) ->
    send(Ip, Host, From, To, test_msg()).


encode_header({Header, [V|Vs]}) when is_list(V) ->
    Hdr = lists:map(fun ({K, Value}) when is_list(K), is_list(Value) ->
                            K ++ "=" ++ Value;
                        ({K, Value}) when is_atom(K), is_list(Value) ->
                            atom_to_list(K) ++ "=" ++ Value;
                        (Value) when is_list(Value) -> Value
                    end,
                    [V|Vs]),
    Header ++ ": " ++ join(Hdr, ";\r\n  ");
encode_header({Header, Value}) when Header =:= "To"; Header =:= "From"; Header =:= "Reply-To"; Header =:= "Cc"; Header =:= "Bcc" ->
    % Assume e-mail headers are already encoded
    Header ++ ": " ++ Value;
encode_header({Header, Value}) when is_list(Header), is_list(Value) ->
    % Encode all other headers according to rfc2047
    Header ++ ": " ++ rfc2047:encode(Value);
encode_header({Header, Value}) when is_atom(Header), is_list(Value) ->
    atom_to_list(Header) ++ ": " ++ rfc2047:encode(Value).

encode_headers(PropList) ->
    join(lists:map(fun encode_header/1,
                   PropList),
         "\r\n").

encode_parts(#mime_msg{parts=Parts, boundary=Boundary}) ->
    lists:map(fun (P) -> encode_part(P,Boundary) end, Parts).

encode_part(#mime_part{data=Data} = P, Boundary) ->
    "--" ++ Boundary ++ "\r\n" ++
    encode_headers(part_headers(P)) ++ "\r\n\r\n" ++
    double_dot(z_convert:to_list(Data)) ++ "\r\n".

part_headers(#mime_part{type=undefined, encoding={Enc, MimeType, Charset},
                        name=undefined}) ->
    [{"Content-Transfer-Encoding", Enc},
     {"Content-Type", [MimeType, {charset, Charset}]}];
part_headers(#mime_part{type=Type, encoding={Enc, MimeType, Charset},
                        name=Name}) when Type==inline; Type == attachment ->
    [{"Content-Transfer-Encoding", Enc},
     {"Content-Type", [MimeType, "charset=" ++ Charset ++ ",name=" ++ Name]},
     {"Content-Disposition", [atom_to_list(Type), 
                              {"filename", 
                              Name}]}].

headers(#mime_msg{headers=H, boundary=Boundary} = Msg) ->
    H ++ [{"MIME-Version", "1.0"},
          {"Content-Type", [multipart_mime(Msg), 
                            "boundary=\"" ++ Boundary ++ "\""]}].

    multipart_mime(Msg) ->
		case is_mixed(Msg#mime_msg.parts) of
			true -> "multipart/mixed";
    		false -> "multipart/alternative"
		end.

    is_mixed([]) -> false;
	is_mixed([#mime_part{type=attachment}|_]) -> true;
	is_mixed([#mime_part{encoding={_, "text/plain", _}}|T]) -> is_mixed(T);
	is_mixed([#mime_part{encoding={_, "text/html", _}}|T]) -> is_mixed(T);
	is_mixed(_) -> true.
	
invent_mime_boundary() ->
    string:copies("=", 10) ++ list_rand(boundary_chars(), 30).
        
list_rand(List, N) ->
    lists:map(fun (_) -> list_rand(List) end,
              lists:seq(1,N)).

list_rand(List) when is_list(List) ->
    lists:nth(random:uniform(length(List)), List).

boundary_chars() ->
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "0123456789"
%    "'()+_,-./=?"
    .

%% Double dots at the start of a line, conform to Section 4.5.2 of RFC 2821
double_dot([$.|T]) ->
    double_dot(T, [$., $.]);
double_dot(L) ->
    double_dot(L, []).

    double_dot([], Acc) ->
        lists:reverse(Acc);
    double_dot([13, 10, $. | T], Acc) ->
        double_dot(T, [$., $., 10, 13|Acc]);
    double_dot([H|T], Acc) ->
        double_dot(T, [H|Acc]).


join([H1, H2| T], S) when is_list(H1), is_list(H2), is_list(S) ->
    H1 ++ S ++ join([H2| T], S);
%join([C1, C2 | Chars], S) when is_integer(C1), is_integer(C2), is_list(S) ->
%    [C1|S] ++ S ++ join([C2 | Chars], S);
join([H], _) ->
    H;
join([], _) ->
    [].
