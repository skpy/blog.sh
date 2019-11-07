# blog.sh

Generate a (mostly) Markdown-powered blog. Source files are stored in Markdown, to be rendered on the fly by a web server like [Caddy](https://caddyserver.com/v1/docs/markdown).

In order to generate valid XML for RSS 2.0 feeds, `pandoc` is required to convert the Markdown to HTML for inclusion in the output feed file.

## Requirements
* GNU date (`brew install coreutils` on OSX)
* GNU sed (`brew install gnu-sed` on OSX)
* pandoc (`brew install pandoc` on OSX)

## Config
A config file is mandatory. Copy the provided `config.SAMPLE` to `config` and edit appropriately.

`SRC` is the directory in which new content will be found for processing.

`DOCROOT` is the root directory for your website. All output files will be created here. No trailing slash.

`URL` is the full URL of your site. No trailing slash.

`DESCRIPTION` is the text to supply to the `<description>` element in the RSS feed(s).

`HOMECOUNT` is the number of items to display on the home page.

`RSSCOUNT` is the number of items to display in the RSS feed.

## Custom Functions
You may define custom functions inside the config file to alter the execution of some parts of this script. 

`ARCHIVE_FUNC` is the name of a function that you declare in your config file.  This function will be invoked when building the archive list of all content. By default, `blog.sh` will create a full list of all content.  You can override this in your own function.

`HOME_FUNC` is the name of a function tha you declare in your config file to alter how the home page is generated. By default, `blog.sh` will create a list of `HOMECOUNT` items, newest first.

## Usage
`blog.sh` requires a command line argument to tell it what config file to use. If no option is provided, it will look for a file named `config` in the current working directory.  If none is found, the script will exit with an error.

## Data Organization
In addition to the output files created in `DOCROOT`, this script will create a file named `permalinks.txt` that contains a complete list of all permalinks for content processed by `blog.sh`.


## How I use this
I use the iOS Shortcuts application on my iPhone and iPad to take input from me, prompt for an opitonal image, upload all of that to my server, then invoke `blog.sh` via SSH.
