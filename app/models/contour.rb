class Contour < ActiveRecord::Base
self.table_name = "contour"
def contains_peaks
  Peak.find_by_sql [ "select * from peaks p where ST_Within(p.summit_loc, (select geom from contour where fid=#{self.fid})) order by summit_ele desc; " ]
end

def get_centroid
  locations = Contour.find_by_sql ['select id, CASE
                  WHEN (ST_ContainsProperly("geom", ST_Centroid("geom")))
                  THEN ST_Centroid("geom")
                  ELSE ST_PointOnSurface("geom")
                END AS  "geom" from contour where fid=' + fid.to_s]
  if locations then locations.first.geom else nil end
end

def exceeds_extent
  overlap = Contour.find_by_sql [ " select c.id from contour c inner join extent e on ST_Intersects(c.geom, e.wkb_geometry) where c.fid=#{self.fid}; " ]
  if overlap and overlap.count>0 then true else false end
end

end
