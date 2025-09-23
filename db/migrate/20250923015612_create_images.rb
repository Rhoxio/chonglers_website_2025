class CreateImages < ActiveRecord::Migration[8.0]
  def change
    create_table :images do |t|
      t.string :title
      t.text :description
      t.string :cloudinary_public_id
      t.string :cloudinary_url

      t.timestamps
    end
  end
end
