# encoding: utf-8

def get_stop_list(month, day, route)
  visit '/'
  click_link "Click here to view a bus route or bus stop timetable."


  select month, :from => "DatePicker$MonthsDropDownList"
  select day, :from => "DatePicker$DaysDropDownList"

  sleep(0.5)

  fill_in("RouteDirectionDynamicComboBox$ComboBox_Input", :with => route)

  sleep(0.5)

  all_stops = Array.new
  while all_stops.size == 0

    all('img.ComboBoxImage_Default' )[1].click
    sleep(1)
    all('img.ComboBoxImage_Default' )[1].click
    selection_page = Nokogiri::HTML(page.html.body)

    selection_page.search('div#StopDynamicComboBox_ComboBox_DropDownPlaceholder div.ComboBoxItem_Default').each do |tr|
      all_stops.push(tr.content.strip)
    end

    return {} unless find_field("RouteDirectionDynamicComboBox$ComboBox_Input").value == route

  end

  print "found #{all_stops.size} stops..."

  route_info = Hash.new

  all_stops.each do |stop|

    next if stop.starts_with? "Courtesy stop"

    this_stop_info = []

    for i in 0..10
      next unless this_stop_info.empty?
      this_stop_info = get_times_at_stop(month,day,route,stop,false)
      this_stop_info = get_times_at_stop(month,day,route,stop,true) if this_stop_info.empty?
    end

    unless this_stop_info.empty?
      stop_name = stop.split(" - ").last.strip
      route_info[stop_name] = this_stop_info.join(",")
    end

  end
  route_info
end

def get_times_at_stop month, day, route, stop, arrival
  visit '/'
  click_link "Click here to view a bus route or bus stop timetable."

  select month, :from => "DatePicker$MonthsDropDownList"
  select day, :from => "DatePicker$DaysDropDownList"

  until find_field("RouteDirectionDynamicComboBox$ComboBox_Input").value == route
    fill_in("RouteDirectionDynamicComboBox$ComboBox_Input", :with => route)
  end


  while Nokogiri::HTML(page.html.body).search('div#StopDynamicComboBox_ComboBox_DropDownPlaceholder div.ComboBoxItem_Default').size == 0
    all('img.ComboBoxImage_Default' )[1].click
  end

  stop = stop.slice(0..(stop.index('&'))-1) if stop.include? "&"
  fill_in("StopDynamicComboBox$ComboBox_Input", :with => stop)


  choose("ArrivalRadioButton") if arrival

  sleep(0.5)

  click_link "Click here to view the bus stop timetable."

  get_stop_info

end

def get_stop_info

  doc = Nokogiri::HTML(html)

  times = Array.new
  doc.search('span.TimetableTime').each do |time|
    times.push time.content unless time.content == ""
  end

  times

end

def resume

  doc = Nokogiri::XML(File.open("sto-complete.xml")) do |config|
    config.strict.nonet
    config.strict.noblanks
  end

  bus_schedule = Hash.new { |h, k| h[k] = {  } }
  doc.root.children.each do |route_num|
    current_route_num = route_num["name"]
    bus_schedule[current_route_num] ||= {}
    route_num.children.each do |direction|
      current_direction = direction["name"]
      bus_schedule[current_route_num][current_direction] ||= {}
      direction.children.each do |day|
        current_day = day["name"]
        bus_schedule[current_route_num][current_direction][current_day] ||= {}
        day.children.each do |stop|
          bus_schedule[current_route_num][current_direction][current_day][stop["name"]] = stop.content
        end
      end
    end
  end

  bus_schedule
end

def save_progress route
  File.open("complete-scraper.progress", 'w') { |file| file.write(route) }
end


def get_complete_schedule routes, out_file_name, today, weekday, saturday, sunday

  bus_schedule = Hash.new

  if File.file?("complete-scraper.progress")
    file = File.open("complete-scraper.progress")
    contents = file.read.force_encoding 'utf-8'

     until routes.first == contents
       routes.shift
     end
     routes.shift

    bus_schedule = resume
  end

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
      bus_schedule[route_num][route_direction][string] = get_stop_list(day.strftime("%b"), day.strftime("%-d"), route)
    end

    puts "done!"

    write_results_to_xml today, bus_schedule, out_file_name
    save_progress(route)

  end

end