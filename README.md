# Pi-Hole-Parental-Controls

Network-wide parental controls via Raspberry Pi and Pi-Hole

Everything below is pre-populated, but completely configurable.

Language-based URL filtering
  - Blocked words and phrases (blocked_words.txt) 
  - Credit https://github.com/RobertJGabriel/Google-profanity-words/ for this eye-opening text file

Blacklisting wildcarded domains
  - Custom block wildcarded domain names (blocked_domains.txt)

Forced redirection to YouTube Restricted mode

Forced redirection to Google SafeSearch

Blacklisting of 400+ other search engines
 - Courtesy of https://github.com/NaveenDA/
 
 Thank you https://github.com/jaykepeters for original script!
 
 .
 .
 .
 
 Slightly Vague Install Instructions:
 1. Make sure you have Pi-Hole up and running as local DNS server
 2. Clone this repo and cd into it
 3. chmod +x ./safesearch.sh
 4. ./safesearch.sh enable
 
 To update after any modifications of the block files:
 1. ./safesearch.sh reload
 
 To remove all the configurations:
 1. ./safesearch.sh disable
 
 
