defmodule Ask.Study do
  use Ask.Web, :model

  schema "studies" do
    field :name, :string
    belongs_to :user, Ask.User

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name])
    |> validate_required([:name])
  end
end