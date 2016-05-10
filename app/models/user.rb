class User < ActiveRecord::Base
  
  #Geocoder
  geocoded_by :address
  
  def address
    [address_1, address_2, city, state, country].compact.join(', ')
  end
  
  after_validation :geocode
  
end
