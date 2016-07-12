class AddDemoUrlToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :demo_url, :string
  end
end
