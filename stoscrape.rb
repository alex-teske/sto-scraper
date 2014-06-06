# encoding: utf-8
require_relative 'stoscrape-all'
require_relative 'stoscrape-partial'

require 'rspec'
require 'capybara'
require 'capybara/dsl'
require "active_support/core_ext"
require "builder"
require 'active_support/inflector'

include RSpec::Matchers
include Capybara::DSL

REQUEST_URL = "http://www.sto.ca/index.php?id=32&L=en"

Capybara.default_driver = :selenium
Capybara.app_host = REQUEST_URL

def get_routes(month, day)
  visit '/'
  click_link "Click here to view a bus route or bus stop timetable."

  sleep(1)

  select month, :from => "DatePicker$MonthsDropDownList"
  select day, :from => "DatePicker$DaysDropDownList"

  sleep(1)

  first('img.ComboBoxImage_Default' ).click
  first('img.ComboBoxImage_Default' ).click

  sleep(1)

  selection_page = Nokogiri::HTML(page.html.body)
  routes = Array.new
  selection_page.search('div.ComboBoxItem_Default').each do |tr|
    routes.push(tr.content.strip)
  end

  routes
end

def write_results_to_xml today, bus_schedule, out_file_name

  builder = Builder::XmlMarkup.new({:indent => 2})

  builder.bus_schedule("date_retrieved" => today.inspect) do
    bus_schedule.each do |route, route_info|
      builder.route("name" => route) do |node|
        route_info.each do |direction, days|
          node.direction("name" => direction) do |node|
            days.each do |day, stops|
              unless stops.empty?
                node.day("name" => day) do |node|
                  stops.each do |stop, time|
                    node.stop(time, {"name" =>stop})
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  File.open(out_file_name, 'w') {|f| f.write(builder.target!) }

end

sleep(1)
print 'Finding dates to use...'
today = Date.today
weekday = today.dup

until weekday.strftime('%A') == "Friday"
  weekday += 1
end

saturday = weekday + 1
sunday = weekday + 2
puts "done!"

print "Getting route list..."
routes = get_routes(weekday.strftime("%b"), weekday.strftime("%-d"))
print "got #{routes.size} routes..."
if routes.size == 0
  throw "Unable to build list of schedules"
end
puts "done!"

#puts "****GETTING COMPLETE SCHEDULE****"
done = false
until done
  begin
    get_complete_schedule routes.dup, "sto-complete.xml", today,  weekday, saturday, sunday
    done = true

  rescue => msg

  end
end

#get_complete_schedule routes, "sto-complete.xml", today,  weekday, saturday, sunday
puts "****GETTING PARTIAL SCHEDULE****"
get_partial_schedule routes, "sto-partial.xml", today,  weekday, saturday, sunday



