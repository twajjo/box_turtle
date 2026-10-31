defmodule BoxTurtle.Schema.Query.Options.API do
  @moduledoc """
  Accessors for the settings given to `use BoxTurtle.Schema.Query`.

  Every accessor takes an optional keyword list; a value for the same key in it overrides the `use`-time setting.
  This is how call-time options such as `repo:` or `default_sort:` take effect.
  """

  @callback default_distinct() :: [atom()]
  @callback default_distinct(keyword()) :: [atom()]
  @callback default_preloads() :: list()
  @callback default_preloads(keyword()) :: list()
  @callback default_sort() :: BoxTurtle.Schema.Sort.API.sort_spec()
  @callback default_sort(keyword()) :: BoxTurtle.Schema.Sort.API.sort_spec()
  @callback filter_module() :: module()
  @callback filter_module(keyword()) :: module()
  @callback page_size() :: pos_integer()
  @callback page_size(keyword()) :: pos_integer()
  @callback primary_key() :: atom()
  @callback primary_key(keyword()) :: atom()
  @callback repo() :: module()
  @callback repo(keyword()) :: module()
  @callback schema() :: module()
  @callback schema(keyword()) :: module()
  @callback sorting_module() :: module()
  @callback sorting_module(keyword()) :: module()

  @doc """
  Adds every `use`-time setting to the given options, keeping any value already present in them.
  """
  @callback inject_query_options(keyword()) :: keyword()
end
