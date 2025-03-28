class CreatePeaks < ActiveRecord::Migration[8.0]
  def change
    create_table :peaks do |t|
      t.st_point :summit_loc, :srid => 4326
      t.st_point :saddle_loc, :srid => 4326
      t.float :summit_ele
      t.float :saddle_ele
      t.float :prominence
      t.string :ele_status
      t.string :prom_status
      t.string :saddle_status
      t.timestamps
    end
  end
end
