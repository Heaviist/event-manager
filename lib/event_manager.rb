require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number.gsub!(/[^0-9]/, '')
  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number.delete_prefix('1')
  else
    'Bad number'
  end
end

def peaks(time_data)
  count = time_data.each_with_object(Hash.new(0)) do |data, result|
    result[data] += 1
  end
  count.max_by { |_data, times| times }[0]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('api.env').chomp # file contains API key
  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, personal_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts personal_letter
  end
end

puts 'EventManager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
hours = []
days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])

  date_and_time = Time.strptime(row[:regdate], '%m/%d/%y %H:%M')
  hours << date_and_time.hour
  days << date_and_time.wday

  legislators = legislators_by_zipcode(zipcode)

  personal_letter = erb_template.result(binding)
  save_thank_you_letter(id, personal_letter)
end

puts "First peak hour of the day: #{peaks(hours)}:00 to #{peaks(hours) + 1}:00"
puts "Peak weekday: #{Date::DAYNAMES[peaks(days)]}"
