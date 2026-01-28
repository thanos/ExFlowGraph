defmodule ExFlow.Repo.Migrations.CreateGraphs do
  use Ecto.Migration

  def change do
    create table(:graphs) do
      add :name, :string, null: false
      add :data, :map, null: false
      add :version, :integer, default: 1, null: false
      add :user_id, :integer

      timestamps()
    end

    create index(:graphs, [:name])
    create index(:graphs, [:user_id])
    create unique_index(:graphs, [:name, :user_id], name: :graphs_name_user_id_index)
  end
end
