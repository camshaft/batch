-module(batch).
 
-behaviour(gen_batch).
-export([init/1, process_item/3, worker_died/5, job_stopping/1, job_complete/2]).
 
-export([create/0]).
-export([push/2]).
-export([concurrency/2]).
-export([exec/1]).
-export([exec/2]).

-export([loop/2]).

create() ->
  spawn_link(?MODULE, loop, [{5, []}, self()]).
 
concurrency(C, Batch) ->
  Batch ! {concurrency, C},
  ok.
 
push(F, Batch) ->
  Batch ! {push, F},
  ok.
 
exec(Batch) ->
  exec(Batch, []).
 
exec(Batch, Args) ->
  Batch ! {stop, self()},

  receive
    {ok, Batch, State} ->
      gen_batch:sync_run_job(batch, {State, Args});
    {error, _} = Error ->
      Error
  end.

loop({C, Batch} = State, Owner) ->
  receive
    {concurrency, NewC} ->
      ?MODULE:loop({NewC, Batch}, Owner);
    {push, F} ->
      ?MODULE:loop({C, [F|Batch]}, Owner);
    {stop, Owner} ->
      Owner ! {ok, self(), State};
    {stop, Caller} ->
      Caller ! {error, not_owner};
    _ ->
      ?MODULE:loop(State, Owner)
  end.
 
init({{C, Batch}, Args}) ->
  {ok, C, Batch, Args}.
 
process_item(F, _StartTime, Args) ->
  apply(F, Args),
  ok.
 
worker_died(_, _WorkerPid, _StartTime, _Info, _) ->
  ok.
 
job_stopping(_) ->
  ok.
 
job_complete(_Status, _) ->
  ok.