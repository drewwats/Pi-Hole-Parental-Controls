#!/bin/bash
# SafeSearch List Generator for Pi-hole 4.0 and above
# Modifications and improvements by drewwats (https://github.com/drewwats)
# Originally created by Jayke Peters (https://github.com/jaykepeters)




function refreshtime
{

    timestamp="`date +%H:%M:%S`"
    fulldate="`date +%Y%m%d_%H%M%S`"

}



# Set global variables
input=$1
filename=$(basename "$0")

work_dir="/root/safesearch/"
this_file=$work_dir"safesearch.sh"
out_file=$work_dir"safesearch.tmp"
log_file=$work_dir"safesearch.log"
host_file="/etc/hosts"
conf_file="/etc/dnsmasq.d/09-restrict.conf"
blocked_word_list=$work_dir"blocked_words.txt"
blocked_domain_list=$work_dir"blocked_domains.txt"
blocked_engine_list=$work_dir"blocked_engines.txt"
google_urls="https://www.google.com/supported_domains"

# Unused or for reference
#profanity_url="raw.https://github.com/RobertJGabriel/Google-profanity-words/blob/master/list.txt"
#redirected_domain_list=$work_dir"redirected_domains.txt"
#blocked_engines=$(curl -s https://gist.githubusercontent.com/NaveenDA/b1ff7d43812a3c79354f9b2fd9868186/raw/ec32665ac11d5b8085dc1b5842ad82ad35cd1396/List-of-search-engine.json | jq -r '.[].url' | sed 's/http:\/\///g' | sed 's/www\.//g')



function logger
{

    log() {
        refreshtime
        printf "$timestamp: $* \n" >> $log_file
    }
    out() {
        refreshtime
        printf "$timestamp: $* \n"
    }
    all() {
        log "$*"
        out "$*"
    }
    # Take input from the function call
    "$@"

}


function checkinput
{

    if [[ "$input" == "enable" ]]; then
        logger all "Enabling Pi-Hole SafeSearch..."
    elif [[ "$input" == "disable" ]]; then
        logger all "Reloading Pi-Hole SafeSearch..."
    elif [[ "$input" == "reload" ]]; then
        logger all "Disabling Pi-Hole SafeSearch..."
    elif [[ "$input" == "gonuclear" ]]; then
        logger all "Abandon hope all ye who enter here. Or gain hope? I don't know, totally up to you"
        logger all "Nuking Pi-Hole SafeSearch..."
    else
        logger all "Please use enable, reload, disable, or gonuclear as shown below"
        logger all "e.g. ./safesearch.sh enable"
        exit 0
    fi

}


function checkuser
{

    if [ "$?" -ne 0 ];then
        logger out "This script must be ran with root privileges. Exiting..."
        exit 0
    fi

}


function cleanup
{

    if [ -f $log_file ]; then
        rm -f $log_file
        touch $log_file
    fi

    if [ -f $out_file ]; then
        rm -f $out_file
    fi

}


function grabips
{

    logger all "Grabbing current IPs for SafeSearch sites..."

    google_safe_ip=$(dig -4 +short forcesafesearch.google.com @8.8.8.8 | \
        grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | head -n 1)
    youtube_safe_ip=$(dig -4 +short restrict.youtube.com @8.8.8.8 | \
         grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | head -n 1)

}


function createarrays
{

    # Set IPs for safe URLs
    host_records=(
        "host-record=forcesafesearch.google.com,$google_safe_ip"
        "host-record=restrict.youtube.com,$youtube_safe_ip"
    )

    # Force redirection of normal URLs to safe URL's IP
    youtube_cnames=(
        "cname=www.youtube.com,restrict.youtube.com"
        "cname=m.youtube.com,restrict.youtube.com"
        "cname=youtubei.googleapis.com,restrict.youtube.com"
        "cname=youtube.googleapis.com,restrict.youtube.com"
        "cname=www.youtube-nocookie.com,restrict.youtube.com"
    )

    blocked_domain_array=()
    mapfile -t blocked_domains < $blocked_domain_list
    for blocked_domain in "${blocked_domains[@]}"; do
        firstchar=$(echo $blocked_domain | cut -c1)
        if [ $firstchar != '#' ]; then
            blocked_domain_array+=("$blocked_domain")
        fi
    done

    blocked_word_array=()
    mapfile -t blocked_words < $blocked_word_list
    for blocked_word in "${blocked_words[@]}"; do
        firstchar=$(echo $blocked_word | cut -c1)
        # If blocked word is commented out
        if [ $firstchar != '#' ]; then
            # Blocked word contains space
            if [[ "$blocked_word" == *" "* ]]; then
	            blocked_word='(.+)?'$(echo $blocked_word | sed -r 's/\s+/(.*)?/g')'(.+)?'
            else
                # If blocked word is uncommented and contains no spaces
                blocked_word='(.+)?'"$blocked_word"'(.+)?'
            fi
        	blocked_word_array+=("$blocked_word")
        fi
    done

    blocked_engine_array=()
    mapfile -t blocked_engines < $blocked_engine_list
    for blocked_engine in "${blocked_engine[@]}"; do
        firstchar=$(echo $blocked_engine | cut -c1)
        if [ $firstchar != '#' ]; then
            blocked_engine_array+=("$blocked_engine")
        fi
    done

    # This is not working yet
    #redirected_domain_array=()
    #mapfile -t redirected_domains < $redirected_domain_list
    #for redirected_domain in "${redirected_domains[@]}"; do
    #    firstchar=$(echo $redirected_domain | cut -c1)
    #    if [ $firstchar != '#' ]; then
    #        requested_domain=$(echo $redirected_domain | cut -d' ' -f1)
    #        resulting_domain=$(echo $redirected_domain | cut -d' ' -f2)
    #        resulting_ip=$(dig -4 +short $resulting_domain @8.8.8.8 | \
    #            grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | head -n 1)
    #        requested_domain_array+=("$resulting_ip $requested_domain")
    #    fi
    #done

}


function usercheck
{

    if [ "$?" -ne 0 ];then 
        logger out "This script must be ran with root privileges. Exiting..."
        exit 1
    fi

}


function generate
{

    # Download List into an Array
    logger all "Retrieving complete list of Google domains..."
    google_domains=($(curl $google_urls 2>/dev/null))

    # Append File Header
    echo "# $out_file generated on $(date '+%m/%d/%Y %H:%M') by $(hostname)" > $out_file
    
    # Add host records
    logger all "Staging host records..."
    for host_record in "${host_records[@]}"; do
        echo "$host_record" >> $out_file
    done

    # Generate list of domains
    logger all "Staging Google domains..."
    for domain in "${google_domains[@]}"; do
        dom=$(echo $domain | cut -c 2-)
        echo cname=$dom,"www""$domain",forcesafesearch.google.com >> $out_file
    done

    # Get the number of domains
    count=$(cat $out_file | grep 'forcesafesearch.google.com' | wc -l)
    logger all "Staged $count known Google domains."

    # YouTube SafeSearch
    logger all "Staging YouTube redirects..."
    for cname in "${youtube_cnames[@]}"; do
        echo $cname >> $out_file
    done
    
}


function routeaccordingly
{

    if [[ "$input" == "enable" ]]; then
        logger all "Enabling Pi-Hole SafeSearch..."
        enableprotection
    elif [[ "$input" == "disable" ]]; then
        logger all "Reloading Pi-Hole SafeSearch..."
        disableprotection
    elif [[ "$input" == "reload" ]]; then
        logger all "Disabling Pi-Hole SafeSearch..."
        disableprotection
        enableprotection
    elif [[ "$input" == "gonuclear" ]]; then
        logger all "Reloading Pi-Hole SafeSearch..."
        nukeprotection
    else 
        logger all "How the hell did you even get here?"
    fi

}


function enableprotection
{

    logger all "Creating redirects via $conf_file..."

    cp -R "$out_file" "$conf_file"

    logger all "Creating entries in Pi-Hole Blacklist..."
    pihole -b --wild "${blocked_domain_array[@]}"
    pihole -b --wild "${blocked_engine_array[@]}"
    pihole -b --regex "${blocked_word_array[@]}"

    logger all "Restarting Pi-Hole DNS..."
    pihole restartdns

    logger all "Pi-Hole SafeSearch is Enabled."

}


function disableprotection
{

    logger all "Removing temp file ($out_file)..."
    rm -f "$out_file"

    logger all "Removing config file ($conf_file)..."
    rm -f "$conf_file"

    logger all "Unblocking words and domains in PiHole..."
    pihole -b -d --wild "${blocked_domain_array[@]}"
    pihole -b -d --wild "${blocked_engine_array[@]}"
    pihole -b -d --regex "${blocked_word_array[@]}"
    #pihole -b --regex --nuke

    logger all "Restarting DNS..."
    pihole restartdns

    logger all "Pi-Hole SafeSearch is Disabled."

}
   

function nukeprotection
{

    logger all "Carefully removing temp file ($out_file)..."
    rm -f "$out_file"

    logger all "Gracefully deleting config file ($conf_file)..."
    rm -f "$conf_file"

    logger all "Nuking the shit out of everything else!!!"
    pihole -b --regex --nuke
    pihole -b --wild --nuke

    logger all "If you're one of the lucky ones, you're about to have unrestricted internet..."
    logger all "Restarting DNS..."
    pihole restartdns

    logger all "Pi-Hole SafeSearch has been utterly demolished."

}

	

checkinput
checkuser
cleanup
grabips
createarrays
generate
routeaccordingly
