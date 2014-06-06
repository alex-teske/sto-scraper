# encoding: utf-8

def get_route_info(route, month, day)
  visit '/'
  click_link "Click here to view a bus route or bus stop timetable."

  select month, :from => "DatePicker$MonthsDropDownList"
  select day, :from => "DatePicker$DaysDropDownList"

  sleep(1)

  fill_in("RouteDirectionDynamicComboBox$ComboBox_Input", :with => route)

  sleep(1)

  #find_field("RouteDirectionDynamicComboBox$ComboBox_Input").native.send_key(:enter)

  click_link "Click here to view the bus route timetable."

  doc = Nokogiri::HTML(html)


  stops = Array.new
  doc.search('th.TimetableHorizontalHeader').each do |tr|
    stops.push(tr["title"])
  end

  times = Array.new
  doc.search('span.TimetableTime').each do |time|
    times.push time.content
  end

  sorted_times = Array.new(stops.count){Array.new}

  times.each_with_index do |elem, index|
    bucket = index.modulo(stops.count)
    sorted_times[bucket].push elem
  end

  route_info = Hash.new

  for i in 0..sorted_times.count-1
    route_info[stops[i].strip] = sorted_times[i].join(",")
  end

  route_info

end


def get_partial_schedule routes, out_file_name, today, weekday, saturday, sunday
  puts routes.size

  bus_schedule = Hash.new
  routes.each do |route|
    route_num = route.split(" ").first
    route_direction = route.split(" ")[1..-1].join(" ").strip
    print "Getting route info for route: #{route_num} (direction: #{route_direction})..."
    bus_schedule[route_num] ||= Hash.new
    bus_schedule[route_num][route_direction] = Hash.new

    {weekday=>"Weekday", saturday=>"Saturday", sunday=>"Sunday"}.each do |day, string|
      print string+"..."
      if route == "21 CASINO DU LAC-LEAMY" and day == sunday
        route = "21 FREEMAN via CASINO DU LAC-LEAMY"
      end
      if route == "21 OTTAWA via MUSÉE DES CIVILISATIONS" and day == sunday
        route = "21 OTTAWA via CASINO DU LAC LEAMY via MUSÉE DES CIVILISATIONS"
      end
      bus_schedule[route_num][route_direction][string] = get_route_info(route, day.strftime("%b"), day.strftime("%-d"))
      write_results_to_xml(today, bus_schedule, out_file_name)
    end
    puts "done!"

  end

end
