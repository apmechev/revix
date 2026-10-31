defmodule Revix.Repo.Migrations.AddVisibilityToEntries do
  use Ecto.Migration

  def change do
    # Existing rows default to "public", so historical posts keep their
    # current visibility. Only local posts carry a meaningful value.
    alter table(:entries) do
      add :visibility, :string, null: false, default: "public"
    end

    create index(:entries, [:visibility])
  end
end
