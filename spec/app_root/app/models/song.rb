class Song < ActiveRecord::Base

  belongs_to :artist

  serialize :tags, Array
  
end
