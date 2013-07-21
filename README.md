batch
=====

Simple batch processing for erlang.

Usage
-----

Before using `batch` make sure to start the `batch_sup`:

```erlang
batch_sup:start_link().
```

Here's an example using [presenterl](https://github.com/CamShaft/presenterl):

```erlang
Batch = batch:create(),

batch:push(fun(P) ->
  %% Make a db call here
  User = get_user(),

  P ! [
    {<<"username">>, proplists:get_value(<<"username">>, User)}
  ]
end, Batch),

batch:push(fun(P) ->
  %% Make a db call here
  UserLikes = get_likes(),

  P ! [
    {<<"likes">>, UserLikes}
  ]
end, Batch),

batch:push(fun(P) ->
  %% Make a db call here
  Followers = get_followers(),

  P ! [
    {<<"followers">>, Followers}
  ]
end, Batch),

batch:push(fun(P) ->
  %% Make a db call here
  Repos = get_repos(),

  P ! [
    {<<"repos">>, Repos}
  ]
end, Batch),

%% Set the concurrency for the processing
batch:concurrency(2, Batch),

Presenter = presenterl:create(jsx),

%% Execute the batch with the second parameter being the arguments
%% to pass to the workers
batch:exec(Batch, [Presenter]),

JSON = presenterl:encode(Presenter).
```

outputs:

```json
{
  "followers": [
    "joearms"
  ], 
  "likes": 123, 
  "repos": [
    "CamShaft/batch", 
    "CamShaft/presenterl"
  ], 
  "username": "CamShaft"
}
```

It get's really interesting when you start nesting batches:

```erlang
Batch = batch:create(),

batch:push(fun(P) ->
  %% Get a list of all of the user repos
  Repos = get_repo_list(),
  
  %% Create a nested batch job
  Nested = batch:create(),

  % For each repo in the list make a call
  [batch:push(fun(RepoList) ->
    %% Make a db call here
    RepoInfo = get_repo_info(Repo),

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

Json = presenterl:encode(Presenter).
```

outputs:

```json
{
  "repos": [
    {
      "url": "CamShaft/presenterl",
      "commits": 3
    },
    {
      "url": "CamShaft/batch",
      "commits": 3
    }
  ]
}
```
