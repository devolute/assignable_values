class CreateSongs < ActiveRecord::Migration

  def self.up
    create_table :songs do |t|
      t.integer :artist_id
      t.string :title
      t.string :genre
      t.integer :year
      t.boolean :active
      t.text :tags
    end
  end

  def self.down
    drop_table :songs
  end

end
