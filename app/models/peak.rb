class Peak < ApplicationRecord

MIN_PROMINENCE=30

def self.add_all_peaks
  last_ele=9999999
  cs=Contour.find_by_sql [ " select fid, ele from contour where ele>0 order by ele desc; " ]

  cs.each do |c|
    #display some stats
    if c.ele != last_ele then
      last_ele=c.ele
      contours=Contour.find_by_sql [ " select count(fid) as fid from contour where ele=#{c.ele}; " ]
      unknown=Peak.find_by_sql [ " select count(id) as id from peaks where prom_status='unknown'; " ]
      incomplete=Peak.find_by_sql [ " select count(id) as id from peaks where prom_status='incomplete'; " ]
      valid=Peak.find_by_sql [ " select count(id) as id from peaks where prom_status='valid'; " ]

      puts "Checking #{c.ele}m contours"
      puts "Found #{contours.first.fid} polygons"
      puts "Database contains: #{valid.first.id} valid, #{incomplete.first.id} incomplete and #{unknown.first.id} unknown peaks"
    end

    exceeds_extent = c.exceeds_extent

    peaks=c.contains_peaks
    #contour contains no peaks, new peak needed
    if peaks.count==0 and c.ele>=MIN_PROMINENCE then
      p=Peak.create(
        summit_ele: c.ele, 
        summit_loc: c.get_centroid, 
        ele_status: if exceeds_extent then "incomplete" else "valid" end,
        prom_status: "unknown",
        saddle_status: "unknown"
      )
    end

    #contour contains multiple peaks, must be a saddle
    if peaks.count>1 then
      #mark all but highest as valid
      peaks[1..-1].each do |p|
        if p.prom_status=="unknown" then
          p.saddle_ele=c.ele+1
          p.saddle_status="elevation_known"
          p.prominence=p.summit_ele-p.saddle_ele
          if exceeds_extent then 
            p.prom_status="incomplete" 
          else 
            p.prom_status="valid" 
          end 

          #discard if prom too low
          if p.prominence<MIN_PROMINENCE then
            p.destroy
          else
            puts "Creating #{p.summit_ele} summit with prom=#{p.prominence} (#{p.prom_status})"
            p.save
          end
        end
      end
    end
  end

  #we are now at sea level - so all remaining summits need comparing to ele=0
  peaks=Peak.where(prom_status: 'unknown')
  peaks.each do |p|
    if p.summit_ele>=MIN_PROMINENCE then
      puts "Adding primary #{p.summit_ele}m summit"
      p.saddle_ele=0
      p.saddle_status="primary"
      p.prominence=p.summit_ele
      p.prom_status="valid"
      p.save
    else
      p.destroy
    end
  end
end

def self.add_all_saddles
  peaks=Peak.where(saddle_status: "elevation_known")
  count=0
  total=peaks.count
  peaks.each do |peak|
    count+=1
    puts "Checking peak #{count} of #{total}"
    peak.add_saddle
  end 
end

def add_saddle
  puts self.to_json
  loc=self.get_saddle
  if loc then
    self.saddle_loc=loc
    self.saddle_status="valid"
    self.save
    puts "Saddle found for #{self.summit_ele}m summit"
  else
    self.saddle_status="not_found"
    puts "Saddle not found for #{self.summit_ele}m summit"
    self.save
  end
end

####################################################

def containing_contour(ele)
  cs=Contour.find_by_sql [ " select * from contour c where ele=#{ele} and ST_Contains(c.geom, (select summit_loc from peaks where id=#{id})); " ]
  cs.first
end

def get_saddle
  saddle_contour=self.containing_contour(self.saddle_ele)
  ref_peak=saddle_contour.contains_peaks.first
  our_last_contour=self.containing_contour(self.saddle_ele+1)  
  ref_last_contour=ref_peak.containing_contour(self.saddle_ele+1)  

  mid_points=Peak.find_by_sql [ "select st_centroid(st_shortestline(a.geom, (select geom from contour b where b.fid=#{ref_last_contour.fid}))) as saddle_loc from contour a where a.fid=#{our_last_contour.fid}; " ]
  mid_point=mid_points.first.saddle_loc
  valid_location=Peak.find_by_sql [ "select ST_Contains( (select geom from contour where fid=#{saddle_contour.fid}), ST_GeomFromText('#{mid_point}', 4326)) as valid from peaks where id=#{self.id} " ]
  if valid_location and valid_location.count>0 then 
    valid=valid_location.first["valid"] 
  else 
    valid=false; 
    puts "bugger" 
  end
  if valid then mid_point else nil end
end


end
