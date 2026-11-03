defmodule BoxTurtle.Test.Author do
  use Ecto.Schema
  import Ecto.Changeset

  schema "authors" do
    field(:name, :string)
    has_many(:posts, BoxTurtle.Test.Post)
    timestamps(type: :utc_datetime)
  end

  def changeset(author, attrs) do
    author
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end

defmodule BoxTurtle.Test.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field(:title, :string)
    field(:status, :string, default: "draft")
    field(:likes, :integer, default: 0)
    belongs_to(:author, BoxTurtle.Test.Author)
    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :status, :likes, :author_id])
    |> validate_required([:title])
  end

  # Only the status may change after creation.
  def update_changeset(post, attrs) do
    post
    |> cast(attrs, [:status])
    |> validate_inclusion(:status, ~w(draft published archived))
  end
end

defmodule BoxTurtle.Test.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, BoxTurtle.Schema.Ecto.Ksuid, autogenerate: true}
  schema "tags" do
    field(:name, :string)
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end

defmodule BoxTurtle.Test.Post.Filters do
  use BoxTurtle.Schema.Filters
  import Ecto.Query

  def filter_with(query, [{:min_likes, likes} | rest]) do
    query
    |> where([p], p.likes >= ^likes)
    |> filter_with(rest)
  end
end

defmodule BoxTurtle.Test.Post.Sort do
  use BoxTurtle.Schema.Sort
  import Ecto.Query

  def sort_by(query, [:popularity | rest]) do
    query
    |> order_by([p], desc: p.likes, asc: p.id)
    |> sort_by(rest)
  end
end

# A shared "scope" module: queries any schema with an :author_id by %Author{}, using the
# settings the delegating Query module injects into opts.
defmodule BoxTurtle.Test.ByAuthor do
  use BoxTurtle.Schema.Query, repo: BoxTurtle.Test.Repo, schema: BoxTurtle.Test.Author

  extend :list_by do
    def list_by(%BoxTurtle.Test.Author{id: id}, opts), do: list(add_filters(opts, author_id: id))
  end

  extend :count_by do
    def count_by(%BoxTurtle.Test.Author{id: id}, opts),
      do: count(add_filters(opts, author_id: id))
  end
end

defmodule BoxTurtle.Test.Post.Query do
  use BoxTurtle.Schema.Query,
    repo: BoxTurtle.Test.Repo,
    default_sort: [asc: :id],
    filter_module: BoxTurtle.Test.Post.Filters,
    sorting_module: BoxTurtle.Test.Post.Sort,
    page_size: 2,
    delegates: [{BoxTurtle.Test.ByAuthor, %BoxTurtle.Test.Author{}}]

  delegate([:list_by, :count_by])

  extend :get_by! do
    def get_by!(title, opts) when is_binary(title), do: get!(%{title: title}, opts)
  end
end

defmodule BoxTurtle.Test.Post.Change do
  use BoxTurtle.Schema.Change, repo: BoxTurtle.Test.Repo, update_changeset: :update_changeset
end

defmodule BoxTurtle.Test.Author.Query do
  use BoxTurtle.Schema.Query, repo: BoxTurtle.Test.Repo
end

defmodule BoxTurtle.Test.Author.Change do
  use BoxTurtle.Schema.Change, repo: BoxTurtle.Test.Repo
end

defmodule BoxTurtle.Test.Tag.Query do
  use BoxTurtle.Schema.Query, repo: BoxTurtle.Test.Repo, default_sort: [:name]
end

defmodule BoxTurtle.Test.Tag.Change do
  use BoxTurtle.Schema.Change, repo: BoxTurtle.Test.Repo
end

defmodule BoxTurtle.Test.Code do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:code, :string, autogenerate: false}
  schema "codes" do
    field(:label, :string)
  end

  def changeset(code, attrs), do: cast(code, attrs, [:code, :label])

  # Insert-only changeset that upcases the code.
  def create_changeset(code, attrs) do
    code
    |> changeset(attrs)
    |> update_change(:code, &String.upcase/1)
  end
end

defmodule BoxTurtle.Test.Code.Query do
  use BoxTurtle.Schema.Query, repo: BoxTurtle.Test.Repo, primary_key: :code
end

defmodule BoxTurtle.Test.Code.Change do
  use BoxTurtle.Schema.Change, repo: BoxTurtle.Test.Repo, create_changeset: :create_changeset
end
