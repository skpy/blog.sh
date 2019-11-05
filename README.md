# blog.sh

Generate a (mostly) Markdown-powered blog. Source files are stored in Markdown, to be rendered on the fly by a web server like [Caddy](https://caddyserver.com/v1/docs/markdown).

This supports `posts` and `notes`, where the former is long-form content with titles, and the latter is short-form microblog entries with no titles.

In order to generate valid XML for RSS 2.0 feeds, `pandoc` is required to convert the Markdown to HTML for inclusion in the output feed file.

## Requirements
* GNU date (`brew install coreutils` on OSX)
* GNU sed (`brew install gnu-sed` on OSX)
* pandoc (`brew install pandoc` on OSX)

## Config
A config file is mandatory. Copy the provided `config.SAMPLE` to `config` and edit appropriately.

`DOCROOT` is the root directory for your website. All output files will be created here. No trailing slash.

`URL` is the full URL of your site. No trailing slash.

`DESCRIPTION` is the text to supply to the `<description>` element in the RSS feed(s).

`SRC` is the directory in which new content will be found for processing.

## Usage
`blog.sh` requires a command line argument to tell it what to do. 

Valid options are:
* post: process a new post
* note: process a new note
* home: generate the home page
* rss: generate the index.xml RSS feed

`post` and `note` each expect an appropriately named file in `SRC` to process. If any JPEG images are found in the source directory, they are copied to a sub-directory in `DOCROOT/images/`

## Data Organization
In addition to the output files created in `DOCROOT`, this script will create three additional files, stored in the same directory as this script:

* `all.txt` a list of permalinks for all content
* `notes.txt` a list of permalinks for all notes
* `posts.txt` a list of permlinks for posts

These three files are used to minimize the amount of `find`ing used in order to improve performance a little bit.

## How I use this
I use the iOS Shortcuts application on my iPhone and iPad to take input from me, prompt for an opitonal image, upload all of that to my server, then invoke `blog.sh` via SSH.

For notes, the Shortcuts prompts for input.  For posts, the Shortcut accepts text input passed to it from other apps. I use [Bear](https://bear.app) for creating posts, mostly.
