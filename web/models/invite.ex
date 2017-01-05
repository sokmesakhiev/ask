defmodule Ask.Invite do
  use Ask.Web, :model

  schema "invites" do
    field :code, :string
    field :level, :string
    field :email, :string
    belongs_to :project, Ask.Survey

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:code, :level, :email, :project_id])
    |> validate_required([:code, :level])
  end

end
