-module (batch_test).

-include_lib ("eunit/include/eunit.hrl").

-define (EXPECTED_SIMPLE, <<"{\"likes\":123,\"followers\":[\"joearms\"],\"repos\":[\"CamShaft/batch\",\"CamShaft/presenterl\"],\"username\":\"CamShaft\"}">>).
-define (EXPECTED_NESTED, <<"{\"repos\":[{\"url\":\"CamShaft/presenterl\",\"commits\":3},{\"url\":\"CamShaft/batch\",\"commits\":3}]}">>).

simple_test() ->
  %% Setup
  error_logger:tty(false),
  gen_batch_sup:start_link(),

  Batch = batch:create(),

  batch:push(fun(P) ->
    %% Make a db call here
    User = user(),

    P ! [
      {<<"username">>, proplists:get_value(<<"username">>, User)}
    ]
  end, Batch),

  batch:push(fun(P) ->
    %% Make a db call here
    UserLikes = likes(),

    P ! [
      {<<"likes">>, UserLikes}
    ]
  end, Batch),

  batch:push(fun(P) ->
    %% Make a db call here
    Followers = followers(),

    P ! [
      {<<"followers">>, Followers}
    ]
  end, Batch),

  batch:push(fun(P) ->
    %% Make a db call here
    Repos = repos(),

    P ! [
      {<<"repos">>, Repos}
    ]
  end, Batch),

  batch:concurrency(4, Batch),

  Presenter = presenterl:create(jsx),

  batch:exec(Batch, [Presenter]),

  Json = presenterl:encode(Presenter),
  ?assertEqual(?EXPECTED_SIMPLE, Json).

nested_test() ->

  Batch = batch:create(),

  batch:push(fun(P) ->
    %% Get repo list
    Repos = repos(),
    
    %% Create a nested batch job
    Nested = batch:create(),

    % For each repo in the list make a call
    [batch:push(fun(RepoList) ->
      %% Make a db call here
      RepoInfo = repo(Repo),

      %% Add the formatted Repo to the RepoList
      presenterl:add([
        {<<"url">>, Repo},
        {<<"commits">>, proplists:get_value(<<"commits">>, RepoInfo)}
      ], RepoList)
    end, Nested) || Repo <- Repos],

    %% Create a presenter without an encoding
    NestedPresenter = presenterl:create(),

    batch:exec(Nested, [NestedPresenter]),

    FormattedRepos = presenterl:encode(NestedPresenter),

    P ! [
      {<<"repos">>, FormattedRepos}
    ]
  end, Batch),

  Presenter = presenterl:create(jsx),

  batch:exec(Batch, [Presenter]),

  Json = presenterl:encode(Presenter),
  ?assertEqual(?EXPECTED_NESTED, Json).

% simulated database calls

user() ->
  timer:sleep(40),
  [{<<"username">>, <<"CamShaft">>}].

likes() ->
  timer:sleep(10),
  123.

followers() ->
  timer:sleep(20),
  [<<"joearms">>].

repos() ->
  timer:sleep(30),
  [<<"CamShaft/batch">>, <<"CamShaft/presenterl">>].

repo(_) ->
  timer:sleep(30),
  [{<<"commits">>, 3}].
