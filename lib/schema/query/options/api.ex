defmodule BoxTurtle.Schema.Query.Options.API do
  @moduledoc """
  This module extends BoxTurtle.Schema.Query.API, implementations of this
  API must also implement all callbacks given therein.

  Allows retrieval of the options set when using BoxTurtle.Schema.Query, with optional overrides in the function opts:
    default_distinct
    default_order
    default_preloads
    default_sort
    filter_module
    primary_key
    repo
    schema
    sorting_module
  """
  @doc """
  Overridden by default_order: settings in optional opts at execution time if present.
  """
  @callback default_order() :: atom()
  @callback default_order(keyword()) :: atom()
  @doc """
  Overridden by default_preloads: settings in optional opts at execution time if present.
  """
  @callback default_preloads() :: [field_join :: atom()]
  @callback default_preloads(keyword()) :: [field_join :: atom()]
  @doc """
  Overridden by default_distinct: settings in optional opts at execution time if present.
  """
  @callback default_distinct() :: [field :: atom()]
  @callback default_distinct(keyword()) :: [field :: atom()]
  @doc """
  Overridden by default_sort: settings in optional opts at execution time if present.
  """
  @callback default_sort() :: [field :: atom()]
  @callback default_sort(keyword()) :: [field :: atom()]
  @doc """
  Overridden by filter_module: settings in optional opts at execution time if present.
  """
  @callback filter_module() :: module()
  @callback filter_module(keyword()) :: module()
  @doc """
  Overridden by primary_key: settings in optional opts at execution time if present.
  """
  @callback primary_key() :: atom()
  @callback primary_key(keyword()) :: atom()
  @doc """
  Overridden by sorting_module: settings in optional opts at execution time if present.
  """
  @callback sorting_module() :: module()
  @callback sorting_module(keyword()) :: module()
  @doc """
  Overridden by repo: settings in optional opts at execution time if present.
  """
  @callback repo() :: module()
  @callback repo(keyword()) :: module()
  @doc """
  Overridden by schema: settings in optional opts at execution time if present.
  """
  @callback schema() :: module()
  @callback schema(keyword()) :: module()

  @doc """
  Inject all use-time settings into the given collection of keyword options (allowing run-time overrides).
  """
  @callback inject_query_options(keyword()) :: keyword()

  @optional_callbacks [
    default_order: 0,
    default_preloads: 0,
    default_distinct: 0,
    default_sort: 0,
    filter_module: 0,
    primary_key: 0,
    sorting_module: 0,
    repo: 0,
    schema: 0,
    default_order: 1,
    default_preloads: 1,
    default_distinct: 1,
    default_sort: 1,
    filter_module: 1,
    primary_key: 1,
    sorting_module: 1,
    repo: 1,
    schema: 1
  ]
end
