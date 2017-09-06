# frozen_string_literal: true

# Rails app must already have PostGIS installed
# Designed to be used when you have multiple PostGIS models, such as neighborhood shape files and points of interest within them
# To use, replace the Object model with your PostGIS DB model to be searched (e.g. points of interest)
# and add "include Postgis" into the model declaration of the object to search within (e.g. neighborhood)
# Explicitly works only with Geography data types
module Postgis

  # Returns all objects within the specified radius of the geog_point or (lat,lng)
  def objects_in_radius(radius = 10000)
    return objects_in_radius_by_geog(self.geog_point, radius) if self.has_attribute?(:geog_point)
    return objects_in_radius_by_coords(self.lat, self.lng, radius) if self.has_attribute?(:lat) && self.has_attribute?(:lng)
  end

  def objects_in_radius_by_coords(lat, lng, radius)
    return Object.where("ST_DWithin(geog_point, ST_GeographyFromText('SRID=4326;POINT(#{lng} #{lat})'), #{radius})")
  end

  def objects_in_radius_by_geog(geog_point, radius)
    return Object.where("ST_DWithin(geog_point, '#{geog_point}', #{radius})")
  end

  # Returns the 1 closest object within the specified radius of the geog_point or (lat,lng)
  def nearest_object(radius = 10000)
    return nearest_object_by_geog(self.geog_point, radius) if self.has_attribute?(:geog_point)
    return nearest_object_by_coords(self.lat, self.lng, radius) if self.has_attribute?(:lat) && self.has_attribute?(:lng)
  end

  def nearest_object_by_coords(lat, lng, radius)
    return Object.where("ST_DWithin(geog_point, ST_GeographyFromText('SRID=4326;POINT(#{lng} #{lat})'), #{radius})").order("ST_Distance(geog_point, ST_GeographyFromText('SRID=4326;POINT(#{lng} #{lat})'))").limit(1)
  end

  def nearest_object_by_geog(geog_point, radius)
    return Object.where("ST_DWithin(geog_point, '#{geog_point}', #{radius})").order("ST_Distance(geog_point, '#{geog_point}')").limit(1)
  end

  # Returns all objects within the geog_shape
  def objects_in_shape
    return Object.where("ST_Covers('#{self.geog_shape}', geog_point)") if self.has_attribute?(:geog_shape)
  end

  # Returns all objeects within the lat, lng bounding box
  def objects_in_bounding_box(min_lng, min_lat, max_lng, max_lat)
    return Object.where("ST_Covers(ST_MakeEnvelope(#{min_lng}, #{min_lat}, #{max_lng}, #{max_lat}, 4326), geog_point)")
  end

  # Checks if the geog is within the bounding box
  # Returns 1 if yes, 0 if no
  def within_bounding_box(geog, min_lng, min_lat, max_lng, max_lat)
    within = ActiveRecord::Base.connection.execute("SELECT ST_Intersects(ST_MakeEnvelope(#{(max_lng.to_f - min_lng.to_f) * 0.1 + min_lng.to_f}, #{(max_lat.to_f - min_lat.to_f) * 0.1 + min_lat.to_f}, #{max_lng.to_f - (max_lng.to_f - min_lng.to_f) * 0.1}, #{max_lat.to_f - (max_lat.to_f - min_lat.to_f) * 0.1}, 4326)::geography, '#{geog}')")
    return within.values[0][0]
  end

  # Checks if the point is within the radius of the bounding box
  # Returns 1 if yes, 0 if no
  def bounding_box_in_point_radius(point, radius, min_lng, min_lat, max_lng, max_lat)
    within = ActiveRecord::Base.connection.execute("SELECT ST_DWithin(ST_MakeEnvelope(#{(max_lng.to_f - min_lng.to_f) * 0.1 + min_lng.to_f}, #{(max_lat.to_f - min_lat.to_f) * 0.1 + min_lat.to_f}, #{max_lng.to_f - (max_lng.to_f - min_lng.to_f) * 0.1}, #{max_lat.to_f - (max_lat.to_f - min_lat.to_f) * 0.1}, 4326)::geography, '#{point}', #{radius})")
    return within.values[0][0]
  end

  # Combines multiple shape files into one simplified polygon
  # Input the IDs of the rows of the shape files
  def combine_shapes(ids)
    table_name = 'objects' # Replace me!
    geog = ActiveRecord::Base.connection.execute("SELECT ST_SimplifyPreserveTopology(ST_Union(geog_shape::geometry), 0.0001)::geography FROM #{table_name} WHERE id IN (#{ids})")
    return geog.values[0][0]
  end

  # Calculates the miles between the calling object and the called object
  def miles_between(distant_object)
    distance = ActiveRecord::Base.connection.execute("SELECT ST_Distance(geog_point, '#{distant_object.geog_point}') / 1609.34 from #{self.class.table_name} where id = #{self.id}") if self.has_attribute?(:geog_point)
    return distance.values[0][0].to_f if distance
  end

  # Calculates the area in square miles of the shape file
  def area_in_sq_mi
    area = ActiveRecord::Base.connection.execute("SELECT ST_Area(geog_shape) / 1609.34^2 from #{self.class.table_name} where id = #{self.id}")
    return area.values[0][0].to_f
  end

  # Takes in an array of points & calculates the *AVERAGE* center. Points are an array of [lat,lng]
  # Note that it calcs the average center, not the geographic center.
  def calculate_center_of_points(point_array)
    x = []
    y = []
    z = []
    point_array.each_with_index do |point, i|
      # Convert from Deg to Rad
      lat = point[0].to_f * Math::PI / 180
      lng = point[1].to_f * Math::PI / 180

      # Convert to Cartesian coordinates
      x[i] = Math.cos(lat) * Math.cos(lng)
      y[i] = Math.cos(lat) * Math.sin(lng)
      z[i] = Math.sin(lat)
    end

    # Compute average Cartesian coordinates
    num_points = point_array.length
    x = x.inject(0, :+) / num_points
    y = y.inject(0, :+) / num_points
    z = z.inject(0, :+) / num_points

    # Convert average Cartesian coordinates to latitude and longitude
    # WARNING: MATH
    lng = Math.atan2(y, x)
    hyp = Math.sqrt(x * x + y * y)
    lat = Math.atan2(z, hyp)

    # Convert latitude & longitude to Deg from Rad
    lat = lat * 180 / Math::PI
    lng = lng * 180 / Math::PI

    return [lat, lng]
  end
end
