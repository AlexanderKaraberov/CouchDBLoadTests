% Created by Oleksandr Karaberov on 31.07.18.
% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License. You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
% License for the specific language governing permissions and limitations under
% the License.


- module(load_test).
- export([start/2]).
- vsn(2).


for(N,N,F) ->
    [F(N)];
for(I,N,F) ->
    [F(I) | for(I+1, N, F)].

dispose(Url) ->
  io:format("Load test for CouchDB finished~n", []),
  _ = httpc:request(delete, {Url, []}, [], [{sync,true}]),
  {ok, test_db_deleted}.

readlines(FileName) ->
    {ok, Device} = file:open(FileName, [read]),
    try get_all_lines(Device)
      after file:close(Device)
    end.

get_all_lines(Device) ->
    L = case io:get_line(Device, "") of
          eof  -> [];
          Line -> Line ++ get_all_lines(Device)
        end,
    re:replace(L, "\n", "", [{return,list}]).

start(N, dbs) ->
  _ = inets:start(),
  io:format("Load test for CouchDB started with ~p processes...~n", [N]),
  Self = self(),
  Pids = for(1, N, fun(_) -> spawn_link(fun() ->
    DbSuffix = integer_to_list(rand:uniform(1000000000000000000)),

    Credentials = readlines("../config.ini"),
    URL = case Credentials of
              [] -> "http://127.0.0.1:5983/perftest-dbs-" ++ DbSuffix;
              _ ->  "http://" ++ Credentials ++ "@127.0.0.1:5983/perftest-docs-" ++ DbSuffix
          end,

     % create random db
    {ok, {{_Version0, _, _ReasonPhrase0}, _Headers0, _Body0}} =
       httpc:request(put, {URL, [], [], []}, [], [{sync,true}]),

    % put a doc
    ContentType = "application/json",
    Body = "{\"_id\":\"testdoc\"}",
    UnicodeBin = unicode:characters_to_binary(Body),
    _ = httpc:request(post, {URL, [], ContentType, UnicodeBin },[],
                      [{body_format,binary}, {sync,true}]),

     % read a doc
    {ok, {{_Version, _, _ReasonPhrase}, _Headers, _Body}} =
         httpc:request(get, {URL ++ "/testdoc", []}, [], [{sync,true}]),

     % delete a db
     _ = httpc:request(delete, {URL, []}, [], [{sync,true}]),

     Self ! {self(), finished}
   end) end),
   [receive {Pid, finished} -> Pid end || Pid <- Pids],
   io:format("Load test for CouchDB finished~n", []),
   ok;
start(N, docs) ->
  _ = inets:start(),

  DbSuffix = integer_to_list(rand:uniform(1000000000000000000)),
  Credentials = readlines("../config.ini"),
  Url = case Credentials of
            [] -> "http://127.0.0.1:5983/perftest-docs-" ++ DbSuffix;
            _ ->  "http://" ++ Credentials ++ "@127.0.0.1:5983/perftest-docs-" ++ DbSuffix
        end,

  io:format("Load test for CouchDB started with ~p processes...~n", [N]),
  {ok, {{_Version0, _Code, _ReasonPhrase0}, _Headers0, _Body0}} =
     httpc:request(put, {Url, [], [], []}, [], []),
  Self = self(),
  Pids = for(1, N, fun(_) -> spawn_link(fun() ->
    DocSuffix = integer_to_list(rand:uniform(10000000000000000000)),
    DocPrefix = "docs-perf-testdoc-",
    % put a test doc
    ContentType = "application/json",
    Body = "{\"_id\":\"" ++ DocPrefix ++ DocSuffix ++ "\"}",
    UnicodeBin = unicode:characters_to_binary(Body),
    {ok, {{_Version1, _Code1, _ReasonPhrase1}, _Headers1, _Body1}} =
         httpc:request(post, {Url, [], ContentType, UnicodeBin },[],
                      [{body_format,binary}]),

     % read a doc
    {ok, {{_Version2, _Code2, _ReasonPhrase2}, _Headers2, Body2}}  =
         httpc:request(get, {Url ++ "/" ++ DocPrefix ++ DocSuffix, []}, [], []),
    {struct, Doc} = mochijson:decode(Body2),
    Rev = case lists:keyfind("_rev", 1, Doc) of
        {"_rev", RevId} -> RevId;
        _ -> 0 end,

     % delete a doc
    {ok, {{_Version3, _Code3, _ReasonPhrase3}, _Headers3, _Body3}} =
         httpc:request(delete,
             {Url ++ "/" ++ DocPrefix ++ DocSuffix ++ "?rev=" ++ Rev, []}, [],
             []),

    Self ! {self(), finished}
 end) end),
  [receive {Pid, finished} -> Pid end || Pid <- Pids],
  dispose(Url);
start(N, {reads, Distribution}) ->
  _ = inets:start(),

  if N < 2 ->
     NErrorMsg = "There have to be at least 2 processes: one read and one write",
     erlang:error({'wrong N param', NErrorMsg}, {});
   true -> ok
  end,
  if Distribution < 50 orelse Distribution >= 100
                       orelse is_integer(Distribution) =:= false ->
     DistErrorMsg = "Distribution has to be an integer percentage in the interval from 50% to 99%",
     erlang:error({'wrong distribution param', DistErrorMsg}, {});
   true -> ok
  end,
  WritePercentage = 100 - Distribution,
  WriteProcLimit0 = round(N * (WritePercentage/100.0)),
  WriteProcLimit = if WriteProcLimit0 =:= 0 -> 1; true -> WriteProcLimit0 end,
  ReadProcLimit = N - WriteProcLimit,
  RBatchLimit = round(ReadProcLimit/WriteProcLimit),
  io:format("Load test for CouchDB started with ~p write processes and ~p read processes...~n",
             [WriteProcLimit, WriteProcLimit * RBatchLimit]),

  %create one test db
  DbSuffix = integer_to_list(rand:uniform(1000000000000000000)),
  DocPrefix = "reads-testdoc-",
  Credentials = readlines("../config.ini"),
  Url = case Credentials of
            [] -> "http://127.0.0.1:5983/perftest-reads-" ++ DbSuffix;
            _ ->  "http://" ++ Credentials ++ "@127.0.0.1:5983/perftest-docs-" ++ DbSuffix
        end,

  {ok, {{_Version0, _Code, _ReasonPhrase0}, _Headers0, _Body0}} =
     httpc:request(put, {Url, [], [], []}, [], [{sync,true}]),

  Self = self(),
  WritePids = for(1, WriteProcLimit, fun(_) -> spawn_link(fun() ->
    DocSuffix = integer_to_list(rand:uniform(10000000000000000000)),
    ContentType = "application/json",
    Body = "{\"_id\":\"" ++ DocPrefix ++ DocSuffix ++ "\"}",
    UnicodeBin = unicode:characters_to_binary(Body),
    {ok, {{_Version1, _Code1, _ReasonPhrase1}, _Headers1, _Body1}} =
        httpc:request(post, {Url, [], ContentType, UnicodeBin },[],
                     [{body_format,binary}, {sync,true}]),
    Self ! {self(), finished_write, DocSuffix}
  end) end),

  ReadPids = [receive {WPid, finished_write, Suffix} ->
    DocUrl = Url ++ "/" ++ DocPrefix ++ Suffix,
    RPids = for(1, RBatchLimit, fun(_) -> spawn_link(fun() ->
    {ok, {{_Version2, _Code2, _ReasonPhrase2}, _Headers2, _Body2}}  =
         httpc:request(get, {DocUrl, []}, [], [{sync,true}]),
    Self ! {self(), finished_read}
    end) end),
    RPids
  end || WPid <- WritePids],
  [receive {RPid, finished_read} -> RPid end || RPid <- lists:append(ReadPids)],
  dispose(Url).
