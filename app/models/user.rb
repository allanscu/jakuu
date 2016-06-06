class User < ActiveRecord::Base  
  include AlgoliaSearch

  algoliasearch do
    attribute :first_name, :last_name, :email
  end
  
  #Geocoder
  geocoded_by :address
  
  def address
    [address_1, address_2, city, state, country].compact.join(', ')
  end
  
  after_validation :geocode
  
end
