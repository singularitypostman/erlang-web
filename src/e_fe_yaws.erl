%% the contents of this file are subject to the erlang web public license,
%% version 1.0, (the "license"); you may not use this file except in
%% compliance with the license. you should have received a copy of the
%% erlang web public license along with this software. if not, it can be
%% retrieved via the world wide web at http://www.erlang-consulting.com/.
%%
%% software distributed under the license is distributed on an "as is"
%% basis, without warranty of any kind, either express or implied. see
%% the license for the specific language governing rights and limitations
%% under the license.
%%
%% the initial developer of the original code is erlang training & consulting
%% ltd. portions created by erlang training & consulting ltd are copyright 2008,
%% erlang training & consulting ltd. all rights reserved.

%%%-------------------------------------------------------------------
%%% file    : e_fe_yaws.erl
%%% @author Michal Ptaszek <michal.ptaszek@erlang-consulting.com>
%%%-------------------------------------------------------------------
-module(e_fe_yaws).

-export([out/1, arg_rewrite/1]).
-export([start/0]).

-include("yaws_api.hrl").
-include("yaws.hrl").

out(#arg{clisock = Socket, appmoddata = URL, headers = Headers} = A) ->
    Cookie = yaws_api:find_cookie_val("eptic_cookie", Headers#headers.cookie),
    e_fe_session:load_session(Cookie),

    if
	is_tuple(Socket) andalso element(1, Socket) == sslsocket ->
	    e_fe_proxy:request(A, e_mod_yaws);
	true ->
	    case is_cacheable() of
		false ->
		    e_fe_cache:request(A, URL, e_mod_yaws);
		true ->
		    e_fe_proxy:request(A, e_mod_yaws)
	    end
    end.

arg_rewrite(#arg{req = R} = Arg) ->
    {abs_path, URL} = R#http_request.path,
    check_docroot(Arg, URL).
    
start() ->
    application:start(yaws),
    application:start(ssl),
    application:start(sasl),
    application:start(crypto),
    
    GC0 = yaws_config:make_default_gconf(false, "e_fe_server"),
    GC = GC0#gconf{logdir = "log"},
    SC1 = #sconf{port = 8080,
		 docroot = "docroot",
		 listen = {0, 0, 0, 0},
		 arg_rewrite_mod = e_fe_yaws,
		 appmods = [{"docroot", e_fe_yaws}]},
    SC2 = #sconf{port = 8081,
		 docroot = "docroot",
		 listen = {0,0,0,0},
		 arg_rewrite_mod = e_fe_yaws,
		 appmods = [{"docroot", e_fe_yaws}],
		 ssl = #ssl{keyfile = "priv/keys/host.key",
			    certfile = "priv/keys/host.cert",
			    password = ""}},
    yaws_api:setconf(GC, [[SC1], [SC2]]),
    
    application:start(eptic_fe).

check_docroot(Arg, Url) ->
%% Add here your docroot elements resolver.
%% If the URL matches some element from docroot, the Arg itself 
%% should be returned. 
%% Otherwise, the request will be handled by the e_fe_yaws.
    rewrite_req(Arg, Url).

rewrite_req(#arg{req = R} = Arg, Url) ->
    Arg#arg{req = R#http_request{path = {abs_path, "/docroot" ++ Url}}}.

is_cacheable() ->
%% Here is the place where we can check, if the should skip cache
%% and redirect the request straight to the backend server.
%% 
%% We can decide wheter hit the cache or not after we inspect the
%% content of the session (e_fe_session:fget/1).
%%
%% As an example, all requests replies are cached.
    false.
