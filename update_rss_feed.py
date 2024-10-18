import gspread
from google.oauth2.service_account import Credentials
import xml.etree.ElementTree as ET
import requests
from mutagen.mp3 import MP3

# Google Sheets setup

SERVICE_ACCOUNT_FILE = 'service_account.json'
# Define the scope
SCOPES = ['https://www.googleapis.com/auth/spreadsheets', 
          'https://www.googleapis.com/auth/drive']
creds = Credentials.from_service_account_file(SERVICE_ACCOUNT_FILE, scopes=SCOPES)
client = gspread.authorize(creds)

# Open the Google Sheet by name or by URL
spreadsheet = client.open_by_url('https://docs.google.com/spreadsheets/d/1sD7h-bVG0diyRliXbrD_22coXE5e65YG0oWuKIPzVkQ/edit')  # Or use the sheet URL
sheet = spreadsheet.sheet1  # Open the first sheet

# Fetch all rows from the spreadsheet
# data = sheet.get_all_records()

# # Load existing RSS feed
# tree = ET.parse('podcast_rss.xml')
# root = tree.getroot()
# channel = root.find('channel')

# # Function to get audio duration from the file URL
# def get_audio_duration(audio_url):
#     response = requests.get(audio_url)
#     file_name = 'temp_audio.mp3'
#     with open(file_name, 'wb') as f:
#         f.write(response.content)
    
#     audio = MP3(file_name)
#     duration = audio.info.length  # Duration in seconds
#     hours, remainder = divmod(int(duration), 3600)
#     minutes, seconds = divmod(remainder, 60)
#     return f"{hours:02}:{minutes:02}:{seconds:02}"

# # Iterate through the rows in Google Sheet
# for row in data:
#     if row['Uploaded as Podcast'] == 'No':  # Only process rows not yet uploaded
#         item = ET.Element('item')
        
#         title = ET.SubElement(item, 'title')
#         title.text = row['Title of the source clip']
        
#         description = ET.SubElement(item, 'description')
#         description.text = row['Description Text']
        
#         enclosure = ET.SubElement(item, 'enclosure')
#         enclosure.set('url', row['Link for Audio file'])
#         enclosure.set('type', 'audio/mpeg')
        
#         # Get audio duration from the URL
#         duration_text = get_audio_duration(row['Link for Audio file'])
#         duration = ET.SubElement(item, 'itunes:duration')
#         duration.text = duration_text
        
#         pubDate = ET.SubElement(item, 'pubDate')
#         pubDate.text = row['Upload Date']  # Ensure this is properly formatted in your sheet
        
#         # Mark the podcast as uploaded
#         sheet.update_cell(row['S.No'], 8, 'Yes')  # Assuming 'Uploaded as Podcast' is in the 8th column
        
#         # Add episode to RSS feed
#         channel.append(item)

# # Save the updated RSS feed
# tree.write('updated_podcast_rss.xml')
