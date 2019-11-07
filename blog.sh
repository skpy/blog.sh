#!/bin/bash
# This script publishes content to a blog.

# load the config.
# May be specified as the first argument
# otherwise assume in CWD
if [[ -n "$1" ]]; then
  if [[ ! -e "$1" ]]; then
    echo "Config file not found. Exiting!"
    exit 1
  fi
  source $1
else
  if [[ ! -e "config" ]]; then
    echo "No config found. Exiting!"
    exit 1
  fi
  source config
fi

# This script relies on GNU date and sed.
# The BSD variants on OSX are not compatible.
if [[ $(uname) == 'Darwin' ]]; then
  shopt -s expand_aliases
  alias sed=gsed
  alias date=gdate
fi

## These variables will be used throughout the script
# today's date
DATE=$(date +%Y-%m-%d)
# today's time
TIME=$(date +%H:%M)

# munge DATE into YYYY/mm format
YYYYMM=${DATE:0:7}; YYYYMM=${YYYYMM//-/\/}

# store the day's date
DD=${DATE:8:2}

# remove colons from TIME
HHMM=${TIME/:/}

# we should have a Markdown file in our SRC directory
COUNT=0
for SOURCE in ${SRC}/*.md; do
  if [[ ! -e "${SOURCE}" ]]; then continue; fi
  (( COUNT=COUNT+1 ))
  TITLE=$(sed -n 's/^title: //p' $SOURCE)
  if [[ -n "${TITLE}" ]]; then
    # use the title for the permalink
    PERMALINK=$(echo $TITLE | tr '[:upper:]' '[:lower:]' | tr -d [:punct:] | tr ' ' '-')
    # does a post exist with this permalink?
    if [[ -e "${DOCROOT}/${PERMALINK}.md" ]]; then
      # append an incremental suffic to ensure unique permalinks and file names
      SUFFIX=1
      while [ -e "${DOCROOT}/${PERMALINK}-${SUFFIX}.md" ]; do
        (( SUFFIX=SUFFIX+1 ))
      done
      PERMALINK+="-${SUFFIX}"
    fi
  else
    # use the date for the permalink
    PERMALINK="${YYYYMM}/${DD}/${HHMM}"
    # does the YYYY/MM/DD directory exist?
    if [[ ! -d "${DOCROOT}/${YYYYMM}/${DD}" ]]; then
      # the target directory doesn't exist, so create it.
      mkdir -p ${DOCROOT}/${YYYYMM}/${DD}
    else
      # the directory already exists, so let's make sure
      # we don't have a file name conflict.
      if [[ -e "${DOCROOT}/${PERMALINK}.md" ]]; then
        # we have a file with this HHMM name. Let's get more granular.
        SECONDS=$(date +%S)
        PERMALINK+="${SECONDS}"
        if [[ -e "${DOCROOT}/${PERMALINK}.md" ]]; then
          # what to do? This should never happen, but bail out if it does
          echo "A file exists for this timestamp!"
          exit 1
        fi
        TIME+=":${SECONDS}"
        HHMM+=$SECONDS
      fi
    fi
  fi
  # replace the permalink placeholder with the real link
  # use @ instead of / so sed doesn't puke on directory names
  sed -i "s@PERMALINK@${PERMALINK}@" $SOURCE
  mv $SOURCE ${DOCROOT}/${PERMALINK}.md

  # insert this item to the list of all content
  # use @ as delimiter so that sed doesn't process slashes in permalink
  sed -i "1s@^@$PERMALINK\n@" $DOCROOT/permalinks.txt

  # update the /archive listing, too
  # if we have a custom archive function, invoke that
  if [[ -n "$ARCHIVE_FUNC" ]]; then
    # pass permalink, date and title to the function
    $ARCHIVE_FUNC $PERMALINK "$TITLE"
  else 
    sed -i "1s@^@* ${PERMALINK}\n@" $DOCROOT/archive.md
  fi
done

# generate an RSS feed of the last 10 items
TARGET="${DOCROOT}/index.xml"
FEED="${URL}/index.xml"
echo '<?xml version="1.0"?><rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel>' > $TARGET
echo "<title>skippy.net</title><link>${URL}</link>" >> $TARGET
echo "<description>${DESCRIPTION}</description><language>en-us</language>" >> $TARGET
echo "<pubDate>$(date -R)</pubDate><generator>skippy</generator>" >> $TARGET
echo "<atom:link href=\"${FEED}\" rel=\"self\" type=\"application/rss+xml\" />" >> $TARGET
for i in $(head -n ${RSSCOUNT} ${DOCROOT}/permalinks.txt); do
  FILE="$DOCROOT/$i.md"
  if [[ ! -e "$FILE" ]]; then continue; fi
  GUID="${URL}/${i}"
  DATESTRING=$(sed -n 's/^date: //p' $FILE)
  ITEMDATE=$(date -R -d "$DATESTRING")
  TITLE=$(sed -n 's/^title: //p' $FILE)
  # get the content.  Filter through pandoc to get HTML
  CONTENT=$(sed '/---/,/---/ d' $FILE | pandoc -f markdown -t html)
  echo -n '<item>' >> $TARGET
  if [[ -n "$TITLE" ]]; then
    echo -n "<title>${TITLE}</title>" >> $TARGET
  fi
  echo "<link>${GUID}</link><description><![CDATA[${CONTENT}]]></description><pubDate>${ITEMDATE}</pubDate><guid>${GUID}</guid></item>" >> $TARGET
done
echo '</channel></rss>' >> $TARGET

# update the home page
if [[ -n "$HOME_FUNC" ]]; then
  # run the custom home page function
  $HOME_FUNC
else
  INDEX="${DOCROOT}/index.md"
  echo -e "---\ntemplate: home\n---" > $INDEX
  for i in $(head -n ${HOMECOUNT} ${DOCROOT}/permalinks.txt); do
    file="${DOCROOT}/${i}.md"
    if [[ ! -e "$file" ]]; then continue; fi
    LINK="${URL}/${i}"
    PUBDATE=$(sed -n 's/^date: //p' ${file})
    sed -e '/---/,/---/d' $file >> $INDEX
    echo "[&num;](${LINK} '${PUBDATE}') " >> $INDEX
  done
fi

if [[ $COUNT -eq 1 ]]; then
  # if we had only one file, output a link to that
  echo $URL/$PERMALINK
else
  # otherwise, just send to the home page
  echo $URL
fi
