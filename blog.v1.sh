#!/bin/bash
# This script publishes content to my blog.

# load the config
source config

# This script relies on GNU date amd sed.
# The BSD variants on OSX are not compatible.
case $(uname) in
  'Darwin')
    shopt -s expand_aliases
    alias sed=gsed
    alias date=gdate
  ;;
esac

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

#
##### FUNCTIONS
#
# generate an RSS feed of the last 10 items of the specified content type
function rss {
  if [[ -z "$1" ]]; then
    # no input supplied, so generate the default feed
    TARGET="${DOCROOT}/index.xml"
    FEED="${URL}/index.xml"
    SOURCE="all"
  else
    # generate the content-specific feed
    TARGET="${DOCROOT}/${1}s.xml"
    FEED="${URL}/${1}s.xml"
    SOURCE="${1}s"
  fi
  echo '<?xml version="1.0"?><rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel>' > $TARGET
  echo '<title>skippy.net</title><link>https://skippy.net/</link>' >> $TARGET
  echo "<description>${DESCRIPTION}</description><language>en-us</language>" >> $TARGET
  echo "<pubDate>$(date -R)</pubDate><generator>skippy</generator>" >> $TARGET
  echo "<atom:link href=\"${FEED}\" rel=\"self\" type=\"application/rss+xml\" />" >> $TARGET
  for i in $(tail -n 10 $SOURCE.txt | tac); do
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
}

# generate this month's index of notes
function monthly_note_index {
  INDEX="${DOCROOT}/${YYYYMM}/index.md"
  # get a nice display of this date
  PUBDATE=$(date -d "${YYYYMM}/01" +"%B %Y")
  echo -e "---\ndate: ${PUBDATE}\n---# ${PUBDATE}" >> $INDEX
  for i in $(grep ${YYYYMM} notes.txt | tac); do
    echo "---" >> $INDEX
    # don't re-use PERMALINK here, so we don't clobber
    # that value from global scope
    LINK="${URL}/${i}"
    file="${DOCROOT}/${i}.md"
    if [[ ! -e "$file" ]]; then continue; fi
    PUBDATE=$(sed -n 's/^date: //p' ${file})
    echo "[&para;](${LINK} '${PUBDATE}') " >> $INDEX
    sed -e '/---/,/---/d' -e 's/#/\&num;/g' $file >> $INDEX
  done;
}

# update the home page
function update_home {
  INDEX="${DOCROOT}/index.md"
  echo -e "---\ntemplate: home\n---" > $INDEX
  echo "## Recent posts" >> $INDEX
  for i in $(tail -n 10 posts.txt | tac ); do
    file="${DOCROOT}/${i}.md"
    PUBDATE=$(sed -n 's/^date: //p' $file)
    TITLE=$(sed -n 's/^title: //p' $file | tr -d \"\')
    echo "* ${PUBDATE} - [${TITLE}](${URL}/${i})" >> $INDEX
  done
  echo -e "\n\n---\n## Recent notes" >> $INDEX
  COUNT=1
  for i in $(tail -n 5 notes.txt | tac ); do
    file="${DOCROOT}/${i}.md"
    if [[ ! -e "$file" ]]; then continue; fi
    LINK="${URL}/${i}"
    PUBDATE=$(sed -n 's/^date: //p' ${file})
    echo "[&para;](${LINK} '${PUBDATE}') " >> $INDEX
    # be sure to html-encode hashtags so that Markdown doesn't
    # try to make them headers!
    sed -e '/---/,/---/d' -e 's/#/\&num;/g' $file >> $INDEX
    if [[ $COUNT -lt 5 ]]; then
      echo -e "\n--\n" >> $INDEX
      (( COUNT=COUNT+1 ))
    fi
  done
}

# copy any uploaded images to the /images/YYYY/MM directory
# this creates an $IMAGES array with URLs of the images found
# iterate over images with ${IMAGES[@]} if needed
function copy_images {
  IMAGES=() # initialize empty array
  for i in ${SRC}/*.jpg ${SRC}/*.jpeg; do
    if [[ -e "$i" ]]; then
      INAME=$(basename $i)
      TARGET="${DOCROOT}/images/${YYYYMM}/${INAME}"
      IMAGES+=("${URL}/images/${YYYYMM}/${INAME}") # add this image to the array
      if [[ ! -d "${DOCROOT}/images/${YYYYMM}" ]]; then
        mkdir -p ${DOCROOT}/images/${YYYYMM}
      fi
      mv ${i} ${TARGET}
    fi
  done
}

#
##### Main script
#
# we need to be told what to do.
if [[ -z "$1" ]]; then
  echo "Need input!"
  echo "Valid options: post, note, rss"
  exit 1
fi

case $1 in
  'rss')
    # just regenerate the index.xml feed
    rss
    exit 0
  ;;
  'home')
    # regenerate home page
    update_home
    exit 0
  ;;
  'post'|'note')
    INPUT=$1
  ;;
  *)
    echo "Unrecognized input"
    exit 1
  ;;
esac

# find and copy any uploaded images
copy_images

if [[ $INPUT == 'note' ]]; then
  # this is a note, to be saved at YYYY/MM/DD/HHMM.md
  ORIGINAL="${SRC}/note.md"

  PERMALINK="${YYYYMM}/${DD}/${HHMM}"

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
elif [[ $INPUT == 'post' ]]; then
  # this is a long-form post.
  ORIGINAL="${SRC}/post.md"
  TITLE=$(grep -m 1 '^# ' $ORIGINAL | cut -c 3-)
  # make a permalink from the title
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
  # remove any cruft from Bear
  sed -i 's/^#blog.*//' $ORIGINAL
else
  echo "I have no idea what to do with this!"
  exit 1
fi

FILE="${DOCROOT}/${PERMALINK}.md"
echo '---' > $FILE
if [[ -n "$TITLE" ]]; then
  echo "title: ${TITLE}" >> $FILE
fi
echo "permalink: ${PERMALINK}" >> $FILE
echo "date: ${DATE} ${TIME}" >> $FILE
echo '---' >> $FILE
cat $ORIGINAL >> $FILE
rm -f $ORIGINAL

# notes get images appended to the end of them
# posts assume a human being has added the necessary
# Markdown in the body of the post somewhere.
if [[ "$INPUT" == 'note' ]] && [ ${#IMAGES[@]} -gt 0 ]; then
  # we have one or more images. Add Markdown for them in the note.
  for i in ${IMAGES[@]}; do
    echo -e "\n\n![](${i})" >> $FILE
  done
fi

# add this item to the list of all content
echo $PERMALINK >> all.txt

# add this item to the content-specific archive
if [[ $INPUT == 'note' ]]; then
  echo $PERMALINK >> notes.txt
  monthly_note_index
else
  echo $PERMALINK >> posts.txt
  # and update the /archive listing, too
  if [[ $(grep -c "^## ${YYYYMM:0:4}") -eq 0 ]]; then
    # first entry for this year.
    echo -e "\n## ${DATE:0:4}" >> $DOCROOT/archive.md
  fi
  echo "* ${DATE} - [${TITLE}](/${PERMALINK})" >> $DOCROOT/archive.md
fi

update_home

# generate RSS feed for the specific content
rss $INPUT
# and generate the unified RSS feed
rss

echo $URL/$PERMALINK

