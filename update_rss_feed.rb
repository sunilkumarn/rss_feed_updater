require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'rexml/document'
require 'net/http'
require 'nokogiri'
require 'uri'
require 'fileutils'
require 'open-uri'
require 'tempfile'
require 'date'

include REXML

# Set up Google Sheets API
SERVICE_ACCOUNT_FILE = 'service_account.json'
SCOPE = ['https://www.googleapis.com/auth/spreadsheets', 
         'https://www.googleapis.com/auth/drive']
spreadsheet_id = '1sD7h-bVG0diyRliXbrD_22coXE5e65YG0oWuKIPzVkQ'

authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
  json_key_io: File.open(SERVICE_ACCOUNT_FILE),
  scope: SCOPE
)
sheets_service = Google::Apis::SheetsV4::SheetsService.new
sheets_service.authorization = authorizer

# Get data from Google Sheets
response = sheets_service.get_spreadsheet_values(spreadsheet_id, 'Podcast List')
rows = response.values.drop(1) # Skip the header row

rss_content = File.read('podcast_rss.xml')
rss_doc = Nokogiri::XML(rss_content)

# Set the <channel> node
channel = rss_doc.at_xpath('//channel')

# Helper function to get audio duration
def get_audio_duration(url)
  temp_file = Tempfile.new(['temp_audio', '.mp3'])
  temp_file.binmode
  temp_file.write(URI.open(url).read)
  temp_file.rewind

  # Calculate duration (requires ffmpeg)
  duration = `ffprobe -i #{temp_file.path} -show_entries format=duration -v quiet -of csv="p=0"`.strip.to_f
  temp_file.close
  temp_file.unlink

  hours, remainder = (duration.to_i / 3600), (duration.to_i % 3600)
  minutes, seconds = remainder / 60, remainder % 60
  format('%02d:%02d:%02d', hours, minutes, seconds)
end

rows.each_with_index do |row, index|
  spreadsheet_row_number = index + 2 # Add 2 to account for the header row and zero-based index
  next if row[7] == 'Yes' # Skip rows already marked as uploaded

  puts "Row data: #{row[0]}, Spreadsheet row number: #{spreadsheet_row_number}"

  # New item with CDATA tags
  item_node = Nokogiri::XML::Node.new 'item', rss_doc
  upload_date = Date.strptime(row[8], '%m-%d-%Y')

  title_node = Nokogiri::XML::Node.new 'title', rss_doc
  title_node.content = "<![CDATA[#{row[1]}]]>" # Title from 'Title of the source clip'
  item_node.add_child(title_node)

  description_node = Nokogiri::XML::Node.new 'description', rss_doc
  description_node.content = "<![CDATA[#{row[6]}]]>" # Description from 'Description Text'
  item_node.add_child(description_node)

  enclosure_node = Nokogiri::XML::Node.new 'enclosure', rss_doc
  enclosure_node['url'] = row[5] # Audio URL from 'Link for Audio file'
  enclosure_node['type'] = 'audio/mpeg'
  item_node.add_child(enclosure_node)

  unique_id = Digest::SHA256.hexdigest(row[1].gsub(/\s+/, "") + upload_date.to_s)
  guid_node = Nokogiri::XML::Node.new 'guid', rss_doc
  guid_node.content = unique_id
  item_node.add_child(guid_node)

  creator_node = Nokogiri::XML::Node.new 'dc:creator', rss_doc
  creator_node.content = "Narayanashrama Tapovanam, An abode of Brahmavidya" # Constant creator value
  item_node.add_child(creator_node)

  pubDate_node = Nokogiri::XML::Node.new 'pubDate', rss_doc

  formatted_pub_date = upload_date.strftime('%a, %d %b %Y %H:%M:%S GMT')
  pubDate_node.content = formatted_pub_date # Upload date from 'Upload Date'
  item_node.add_child(pubDate_node)

  itunes_summary_node = Nokogiri::XML::Node.new 'itunes:summary', rss_doc
  itunes_summary_node.content = "<![CDATA[#{row[6]}]]>" # Summary same as description
  item_node.add_child(itunes_summary_node)

  itunes_explicit_node = Nokogiri::XML::Node.new 'itunes:explicit', rss_doc
  itunes_explicit_node.content = "No"
  item_node.add_child(itunes_explicit_node)

  itunes_duration_node = Nokogiri::XML::Node.new 'itunes:duration', rss_doc
  itunes_duration_node.content = get_audio_duration(row[5]) # Duration from calculated function

  puts "Audion duration: #{itunes_duration_node.content}"

  item_node.add_child(itunes_duration_node)

  itunes_image_node = Nokogiri::XML::Node.new 'itunes:image', rss_doc
  itunes_image_node['href'] = ""
  item_node.add_child(itunes_image_node)

  itunes_episode_type_node = Nokogiri::XML::Node.new 'itunes:episodeType', rss_doc
  itunes_episode_type_node.content = "full"
  item_node.add_child(itunes_episode_type_node)

  # Insert the new item before the closing </channel> tag
  channel.add_child(item_node)

  puts "H#{row[0].to_i}"

  begin
    sheets_service.update_spreadsheet_value(
      spreadsheet_id,
      "H#{spreadsheet_row_number}",
      Google::Apis::SheetsV4::ValueRange.new(values: [['Yes']]),
      value_input_option: 'RAW'
    )
  rescue => e
    puts "Failed to update row #{row[0]}: #{e.message}"
  end
  break
end

File.write('podcast_rss.xml', rss_doc.to_xml)

