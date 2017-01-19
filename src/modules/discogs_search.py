#!/usr/bin/env python
# -*- coding: utf-8 -*-

#
# Simple script to parse and score discogs hits.
#
# ola : [ 23:32 ] > discogs_search.py -h
# usage: DiscogsParse [-h] [-artist -a [-a ...]] [-release -r [-r ...]]
# [-year -y] [-token -t] [-output -o] [-notracks -n]
# [-maxresults -m] [-pages -p] [-folder -f]
# [--user-agent -u] [-s] [-v]
#
# Wrapper tool for extracting music metadata via the Discog's API.
# It was written by Ola Aronsson in 2016 primarily as a meta data
# fetcher for nenRip (https://github.com/OlaAronsson/nenRip).
#
# optional arguments:
# -h, --help            show this help message and exit
# -artist -a [-a ...]   releasing artist to search for
# -release -r [-r ...]  release to search for
# -year -y              year of release
# -token -t             discogs API token
# -output -o            use output 'json' for JSON output,
#                       'meta' (default) for nenrip meta
#                       format output
# -notracks -n          number of tracks on the released CD
#                       to search for, 0 (default) means
#                       unknown
# -maxresults -m        max number of returned results. If
#                       'notracks' is provided, we will try
#                       to make all results match number of
#                       tracks
# -pages -p             max number of Discogs pages to parse;
#                       default is 35 (meaning 3500 results,
#                       which takes a looooong time)
# -folder -f            writable folder where results are saved
# --user-agent -u       user agent string used for (non-API)
#                       requests
# -s, -silent           script runs silently
# -v, -verbose          script runs verbose
#
# Some examples :
#
# # discogs_search.py -a talk talk -r spirit of eden -m 3
#
# query Discogs for a release called 'spirit of eden' by
# artist/s 'talk talk' and, upon success, deliver up to 3
# results.
#
# # discogs_search.py -a talk talk -o json
#
# query Discogs for up to 5 results (default max number
# of results), random releases (delivered in decending
# temporal order) by artist/s 'talk talk', JSON output.
#
# # discogs_search.py -a talk talk -y 1988
#
# query Discogs for random releases by artist/s 'talk talk'
# from 1988.
#
# # discogs_search.py -a talk talk -y 1988 -n 2 -m 1
#
# query Discogs for one 2-track release by artist/s
# 'talk talk' from 1988.
#
# # discogs_search.py -r talk talk -y 1982 -m 1
#
# query Discogs for 1 release named 'talk talk' from
# 1982.

import json, os.path, urllib, urllib2, codecs, requests, re, sys, argparse
from operator import attrgetter
from collections import namedtuple
from argparse import RawTextHelpFormatter

# our discogs result entity
DiscogsHit = namedtuple('DiscogsHit', 'type artistrelease notracks style genre year uri tracksurl score tracks imageurl')

# function to remove files in dir matching pattern
def purge(dir, pattern):
    for f in os.listdir(dir):
        if re.search(pattern, f):
            os.remove(os.path.join(dir, f))

# function to mkdir, if needed, and perform a simple testwrite; returns
# false if failed
def testwrite(fname):
    try:
        index = 1
        path = fname.split('/')

        pathStr = ''
        for p in path:
            if index < len(path):
                pathStr = pathStr + '/' + p
            else:
                break
        basedir = os.path.dirname(pathStr)
        if not os.path.exists(basedir):
            os.makedirs(basedir)
        if os.path.isfile(fname):
            os.remove(fname)
        open(fname, 'a').close()
        os.remove(fname)
        return True
    except:
        pass
        return False

# function for URL-ut8-encoding search query input
def searchStringToSearchable(searchString):
    return urllib.quote((' '.join(searchString.encode('utf-8').split()).replace('_', '+').replace(' ', '+').lower()))

# main parsing function for results
def parseResult(results, typeStr, namedRelease, namedYear, alreadyFoundResults, namedArtist):
    parsedResults = []
    entry=0
    resultLen = str(len(results))
    for r in results:
        entry = entry + 1
        score = 0
        addIt = 0
        if typeStr == 'search':
            if silent == 1:
                print "--"
                print "Trying to match page entry "+str(entry)+"/"+resultLen
            title = None
            style = None
            genre = None
            year = None
            uri = None
            if 'style' in r and len(r["style"]) > 0:
                style = r["style"][0]
            if 'genre' in r and len(r["genre"]) > 0:
                genre = r["genre"][0]
            if 'year' in r:
                year = r["year"]
                if namedYear is not None and len(namedYear) > 0:
                    if year < int(namedYear):
                        break
                    yearToCompare = str(year)
                    if namedYear != yearToCompare:
                        addIt=1
                year=str(year)
            if 'uri' in r:
                uri = r["uri"]
            if 'resource_url' in r:
                tracksurl = r["resource_url"]
            if 'type' in r:
                type = r["type"]
            if uri is not None and year is not None and tracksurl is not None:
                score = 10
                if style is None:
                    score = score - 3
                if genre is None:
                    score = score - 3
                if type is None:
                    score = score - 3
                else:
                    if type == 'master':
                        score = score + 10
            else:
                if verbose == 0:
                    print "Missing required attributes : no match"
                addIt = 1
        if typeStr == 'release':
            release = None
            artist = None
            tracksurl = None
            year = None
            type = None
            id = None
            releaseToCompare = None
            style = ''
            genre = ''
            if 'year' in r:
                year = r["year"]
                if namedYear is not None and len(namedYear) > 0:
                    if year < int(namedYear):
                        break
                    yearToCompare = str(year)
                    if namedYear != yearToCompare:
                        addIt=1
                year=str(year)
            if 'resource_url' in r:
                tracksurl = r["resource_url"]
            if 'type' in r:
                type = r["type"]
            if 'id' in r:
                id = str(r["id"])
            if 'title' in r:
                release = r["title"]
                if namedRelease is not None and len(namedRelease) > 0:
                    releaseToCompare = searchStringToSearchable(release.lower())
                    namedReleaseToLookup = namedRelease.strip()
                    if releaseToCompare != namedReleaseToLookup:
                        addIt=1
            if 'artist' in r:
                artist = r["artist"]
            if release is not None and artist is not None and year is not None and tracksurl is not None:
                score = 10
                if type == 'master':
                    score = score + 10
            else:
                if verbose == 0:
                    print "Missing required attributes : no match"
                addIt = 1
        if addIt == 0:
            appendIt = 0
            # Fetch the tracks; don't append if we happen to know
            # how may tracks it should be and it's actually not
            response = urllib.urlopen(tracksurl)
            tracksData = json.loads(response.read(), 'utf-8')

            if typeStr == 'release':
                if 'styles' in tracksData and len(tracksData["styles"]) > 0:
                    style = tracksData["styles"][0]
                if 'genres' in tracksData and len(tracksData["genres"]) > 0:
                    genre = tracksData["genres"][0]
            else:
                year = str(tracksData["year"])

            resultsTracks = tracksData['tracklist']
            trackindex=1
            thetracks = []
            for t in resultsTracks:
                trackStr = str(trackindex)
                if trackindex < 10:
                    trackStr = "0" + trackStr
                thetracks.append(trackStr+'_'+t["title"]+'.mp3')
                trackindex=trackindex+1
            tracksInHit = trackindex-1

            if notracks == 0 or tracksInHit == notracks:
                if verbose == 0 and tracksInHit == notracks:
                    print " -matched number of tracks"

                matchedArtist=1
                matchedRelease=1
                if namedRelease is None or namedRelease == '':
                    if verbose == 0:
                        print " -we will not try to match release in this "+typeStr+" query"
                        matchedRelease=0
                if namedArtist is None or namedArtist == '':
                    if verbose == 0:
                        print " -we will not try to match artist in this "+typeStr+" query"
                    matchedArtist=0
                appendIt=1
                if typeStr == 'release':
                    artistrelease = artist+":::"+release
                    title = release.replace(' ','-')
                    appendIt=0
                else:
                    artist = tracksData['artists'][0]['name']
                    release = tracksData['title']
                    if namedRelease is not None and len(namedRelease) > 0:
                        releaseToCompare = searchStringToSearchable(release.lower())
                        namedReleaseToLookup = namedRelease.strip()
                        if releaseToCompare != namedReleaseToLookup:
                            matchedRelease=1
                        else:
                            if verbose == 0:
                                print " -release was matched"
                            matchedRelease=0

                    if namedArtist is not None and len(namedArtist) > 0:
                        artistToCompare = searchStringToSearchable(artist.lower())
                        namedArtistToLookup = namedArtist.strip()
                        if artistToCompare != namedArtistToLookup:
                            matchedArtist=1
                            print " -artist "+artistToCompare+" was NOT matched"
                        else:
                            if verbose == 0:
                                print " -artist was matched"
                            matchedArtist=0

                    if matchedArtist == 0 and matchedRelease == 0:
                        appendIt=0
                    else:
                        if verbose == 0:
                            print "Either artist or release was not matched : no match"

                    artistrelease = artist+":::"+release
                    id = str(tracksData['id'])
                    title = release.replace(' ','-')
                if appendIt == 0:
                    if silent == 1:
                        print "Swell - we have another match!"

                    headers = { 'User-Agent' : userAgent }
                    imageResourceUrl = "https://www.discogs.com/"+type+"/"+id+"-"+urllib.quote(title.encode('utf-8'))+"/images"
                    req = urllib2.Request(imageResourceUrl, None, headers)
                    html = urllib2.urlopen(req).read()
                    imageurl = ''
                    for link in re.findall(r'img src=[\'"]?([^\'" >]+)', html):
                        if link.endswith(".jpeg.jpg"):
                            try:
                                response = requests.get(link)
                                if response.status_code == 200:
                                    imageurl = link
                                    if silent == 1:
                                        print 'Located '+type+' image art : '+link
                                    break
                                else:
                                    if verbose == 0:
                                        print "Image URL : "+imageResourceUrl+" response was non-HTTP-OK - no image art"
                            except urllib2.HTTPError as e:
                                if silent == 1:
                                    print e
                                pass
                    parsedResults.append(DiscogsHit(type, artistrelease, tracksInHit, style, genre, year, None, tracksurl, score, thetracks, imageurl))
            else:
                if verbose == 0:
                    print "Wrong number of tracks : no match"
        if len(parsedResults) + alreadyFoundResults > maxResults - 1:
            break
    if verbose == 0:
        print "--"
    return parsedResults

# function for matching a title, artist or release
# with provided input
def parseTitleMatch(results, titleToLookup):
    for r in results:
        title = None
        if 'title' in r:
            titleForSearching = searchStringToSearchable(r["title"].lower())
            titleToLookup = titleToLookup.strip()
            if len(titleForSearching) > 0 and titleToLookup == titleForSearching:
                id = str(r["id"])
                if verbose == 0:
                    print "Found mathching artist with id "+id
                return id
    return "0"

# funtion for writing output
def writeOutput(parsedResults):
    if silent == 1:
        if mode == 'json':
            print "Yep, Discogs sure delivered "+str(len(parsedResults))+" results. We shall rank masters first & output (json) will be : "+outputJson
        if mode == 'meta':
            print "Yep, Discogs sure delivered "+str(len(parsedResults))+" results. We shall rank masters first & output (meta) will be : "+outputMeta+"_[n]"
    parsedResults = sorted(parsedResults, key=attrgetter('score'), reverse=True)

    if mode == 'json':
        with codecs.open(outputJson, "w", "utf-8") as myfile:
            for r in parsedResults:
                if notracks == 0:
                    myfile.write(json.dumps(r.__dict__, ensure_ascii=False)+ "\n")
                else:
                    if r.notracks == notracks:
                        myfile.write(json.dumps(r.__dict__, ensure_ascii=False)+ "\n")
    if mode == 'meta':
        index=0
        for r in parsedResults:
            doit=1
            if notracks == 0:
                doit=0
            else:
                if r.notracks == notracks:
                    doit=0

            if doit == 0:
                index=index + 1
                with codecs.open(outputMeta+'_'+str(index), "w", "utf-8") as myfile:
                    artistAndRelease = r.artistrelease
                    artist = artistAndRelease[0:artistAndRelease.find(':::')]
                    release = artistAndRelease[artistAndRelease.find(':::')+3:]

                    myfile.write('ARTIST      :'+artist+"\n")
                    myfile.write('ALBUM       :'+release+"\n")
                    myfile.write('YEAR        :'+r.year+"\n")
                    myfile.write('GENRE       :'+r.genre+"\n")
                    myfile.write('ALBUMARTURL :'+r.imageurl+"\n")
                    myfile.write('TRACKS      :'+ str(r.notracks)+"\n")
                    myfile.write('\n')
                    for track in r.tracks:
                        myfile.write(track+'\n')

# ------------- MAIN ----------------

# make sure _all_ IO is UTF-8 by default
reload(sys)
sys.setdefaultencoding('utf-8')

# used during test-write
my_secret_XOR = '6332467403651412386a771c00756f0a'

# API token
token='sGvVgNzyisfYBWkgctcqTVrWeKJLdCqXXxjQTqFc'

# mode:
# if mode='json' we will output a JSON-file,
# if mode='meta' we shall write meta-files
mode='meta'

# notracks:
# if notracks=0 we will not filter results
# on no of tracks, otherwise we will
notracks=0

# maxResults:
# max results to choose from; if notracks
# is set, ie is not 0, then we shall aim
# for maxResults of releases with notracks
# tracks
maxResults = 5
maxPages=35

# output folder
folder='/tmp'

# user agent used for image fetching (which is, non-API)
userAgent = ' Mozilla/5.0 (Windows NT 6.1; WOW64; rv:12.0) Gecko/20100101 Firefox/12.0'

# user agent used for API-calls
userAgent_API = 'NenRipDiscogsClient/1.0 +http://thehole.black'
class AppURLopener(urllib.FancyURLopener):
    version = userAgent_API
urllib._urlopener = AppURLopener()

# just some initial values
artist=''
release=''
searchyear=''

# first setup and parse args
parser = argparse.ArgumentParser(prog='DiscogsParse', formatter_class=RawTextHelpFormatter, description=''+
          'Wrapper tool for extracting music metadata via the Discog\'s API.\n'
          'It was written by Ola Aronsson in 2016 primarily as a meta data\nfetcher'
          ' for nenRip (https://github.com/OlaAronsson/nenRip).', epilog='Some examples :\n\n'+
          '  # discogs_search.py -a talk talk -r spirit of eden -m 3\n\n'
          'query Discogs for a release called \'spirit of eden\' by \nartist/s '+
          '\'talk talk\' and, upon success, deliver up to 3\nresults.\n\n'+
          '  # discogs_search.py -a talk talk -o json\n\n'
          'query Discogs for up to 5 results (default max number\nof results), random releases (delivered in decending\n'+
          'temporal order) by artist/s \'talk talk\', JSON output.\n\n'
          '  # discogs_search.py -a talk talk -y 1988\n\n'
          'query Discogs for random releases by artist/s \'talk talk\'\nfrom 1988.\n\n'
          '  # discogs_search.py -a talk talk -y 1988 -n 2 -m 1\n\n'
          'query Discogs for one 2-track release by artist/s\n\'talk talk\' from 1988.\n\n'
          '  # discogs_search.py -r talk talk -y 1982 -m 1\n\n'
          'query Discogs for 1 release named \'talk talk\' from\n1982.\n '
                                 )
parser.add_argument('-artist', metavar='-a', dest='artist', nargs='+',
                    help='releasing artist to search for')
parser.add_argument('-release', metavar='-r', dest='release',nargs='+',
                    help='release to search for')
parser.add_argument('-year', metavar='-y', dest='year', default=searchyear,
                    help='year of release')
parser.add_argument('-token', metavar='-t', dest='token', default=token,
                    help='discogs API token')
parser.add_argument('-output', metavar='-o', dest='mode', default=mode,
                    help='use output \'json\' for JSON output,\n\'meta\' (default) for nenrip meta\nformat output')
parser.add_argument('-notracks', metavar='-n', dest='notracks',type=int, default=notracks,
                    help='number of tracks on the released CD\nto search for, 0 (default) means\nunknown')
parser.add_argument('-maxresults', metavar='-m', dest='maxresults', type=int, default=maxResults,
                    help='max number of returned results. If\n\'notracks\' is provided, we will try\nto make all results match number of\ntracks')
parser.add_argument('-pages', metavar='-p', dest='maxpages', type=int, default=maxPages,
                    help='max number of Discogs pages to parse;\ndefault is 35 (meaning 3500 results,\nwhich takes a looooong time)')
parser.add_argument('-folder', metavar='-f', dest='folder', default=folder,
                    help='writable folder where results are saved')
parser.add_argument('--user-agent', metavar='-u', dest='userAgent', default=userAgent,
                    help='user agent string used for (non-API)\nrequests')
parser.add_argument('-s', '-silent', action='store_true', help='script runs silently')
parser.add_argument('-v', '-verbose', action='store_true', help='script runs verbose')
parser.add_argument('-e', '-encode', action='store_true', help='just echo back UTF-8 URL-encoded artist and or release')

opts = parser.parse_args()
if opts.artist is not None and len(opts.artist) > 0:
    opts.artist=' '.join(opts.artist)
else:
    opts.artist=''
if opts.release is not None and len(opts.release) > 0:
    opts.release=' '.join(opts.release)
else:
    opts.release=''

silent=1
verbose=1
justEcho=1
if len(opts.artist)==0 and len(opts.release)==0:
    print 'At least artist or release has to be provided'
    sys.exit(1)
if len(opts.artist) > 0:
    artist=searchStringToSearchable(opts.artist)
if len(opts.release) > 0:
    release=searchStringToSearchable(opts.release)
if len(opts.mode) > 0:
    if opts.mode == 'json' or opts.mode == 'meta':
        mode = opts.mode
    else:
        print 'mode is either json or meta please'
        sys.exit(1)
if len(opts.token) > 0:
    token = opts.token
else:
    print 'API token has to be provided'
    sys.exit(1)

if opts.notracks > -1:
    if opts.notracks >-1 and opts.notracks <100:
        notracks = opts.notracks
    else:
        print 'no of tracks is between 0 (unknown) and 99'
        sys.exit(1)
if opts.maxpages > 0:
    if opts.maxpages > 0 and opts.maxpages <101:
        maxPages = opts.maxpages + 1
    else:
        print 'maxpages is between 1 and 100'
        sys.exit(1)
if opts.maxresults>0:
    if opts.maxresults >0 and opts.maxresults <101:
        maxResults = opts.maxresults
    else:
        print 'maxresults is between 1 and 100'
        sys.exit(1)
if len(opts.folder) > 0:
    if testwrite(opts.folder+'/.'+my_secret_XOR):
        folder = opts.folder
    else:
        print 'provided folder '+opts.folder+' is not writable'
        sys.exit(1)
if len(opts.userAgent) > 0:
    userAgent = opts.userAgent
if len(str(opts.year)) > 0:
    searchyear = str(opts.year)
if opts.s:
    silent=0
if opts.v:
    verbose=0
if opts.e:
    justEcho=0

if silent == 0 and verbose == 0:
    print 'we cannot be both silent and verbose'
    sys.exit(1)

if justEcho == 0:
    print "artist:|"+searchStringToSearchable(artist)+"|release:|"+searchStringToSearchable(release)+"|"
    sys.exit(0)

outputJson = folder+'/discogsJson'
outputMeta = folder+'/discogsMeta'

if silent == 1:
    print 'Running with options:'
    print opts
    print

# setting up flagged URLs
ARTIST = ':::ARTIST:::'
RELEASE = ':::RELEASE:::'
TOKEN = ':::TOKEN:::'
ID = ':::ID:::'
main_search_url = 'https://api.discogs.com/database/search?artist='+ARTIST+'&release_title='+RELEASE+'&token='+TOKEN+'&per_page=100'
artist_search_url = 'https://api.discogs.com/database/search?q='+ARTIST+'&type=artist&token='+TOKEN+'&per_page=100'
release_search_url = 'https://api.discogs.com/database/search?q='+RELEASE+'&type=release&token='+TOKEN+'&per_page=100'
artist_release_url = 'https://api.discogs.com/artists/'+ID+'/releases?sort=year&sort_order=desc&per_page=100'

baseurl=''
values=None
artisturl=''
searchTerm=''
artistUrl2=''
parsedResults=[]
if len(artist) > 0 and len(release) > 0:
    baseurl= main_search_url.replace(ARTIST, artist).replace(RELEASE, release).replace(TOKEN, token)
if len(artist) > 0 and not len(release) > 0:
    artisturl = artist_search_url.replace(ARTIST, artist).replace(TOKEN, token)
    artistUrl2 = "weshalluseit"
    searchTerm = artist
if len(release) > 0 and not len(artist) > 0:
    artisturl = release_search_url.replace(RELEASE, release).replace(TOKEN, token)
    searchTerm = release

# our very first page (we rotate over paging at discogs)
pageNumber=1

# max pages to go through per query
maxPage=100

# perform the actual searches and parse the results
if len(baseurl):
    if silent == 1:
        if verbose == 1:
            print baseurl
    while pageNumber < 2:
        nextUrl = baseurl+"&page="+str(pageNumber)
        if silent == 1:
            print '..working URL : '+nextUrl
        response = urllib.urlopen(nextUrl)
        data = json.loads(response.read())
        if 'pagination' in data:
            maxPage = data['pagination']['pages']
        if 'results' in data and len(data['results']) > 0:
            roundResult = parseResult(data['results'], 'search', release, searchyear, len(parsedResults), artist)
            parsedResults.extend(roundResult)
            if len(parsedResults) > maxResults - 1 or (maxPage > 1 and pageNumber + 1 > maxPage):
                if len(parsedResults) < maxResults:
                    artisturl = artist_search_url.replace(ARTIST, artist).replace(TOKEN, token)
                    artistUrl2 = "weshalluseit"
                    searchTerm = artist
                break
            else:
                pageNumber = pageNumber + 1
        else:
            artisturl = artist_search_url.replace(ARTIST, artist).replace(TOKEN, token)
            artistUrl2 = "weshalluseit"
            searchTerm = artist
            break
if len(artisturl):
    if silent == 1:
        print artisturl
    response = urllib.urlopen(artisturl)
    data = json.loads(response.read())
    if len(artistUrl2):
        id = parseTitleMatch(data['results'], searchTerm)
        if id != "0":
            artistUrl2 = artist_release_url.replace(ID, id)
            if silent == 1:
                if verbose == 1:
                    print artistUrl2
            while pageNumber < maxPages:
                nextUrl = artistUrl2+"&page="+str(pageNumber)
                if silent == 1:
                    print '..working URL : '+nextUrl
                response = urllib.urlopen(nextUrl)
                data = json.loads(response.read())
                if 'pagination' in data:
                    maxPage = data['pagination']['pages']
                    roundResult = parseResult(data['releases'], 'release', release, searchyear, len(parsedResults), artist)
                    parsedResults.extend(roundResult)
                    if len(parsedResults) > maxResults - 1 or pageNumber + 1 > maxPage:
                        break
                    else:
                        pageNumber = pageNumber + 1
    else:
        parsedResults = parseResult(data['results'], 'search', release, searchyear, 0, artist)

# remove previous output files if we got this far!
try:
    if os.path.isfile(outputJson):
        os.remove(outputJson)
    purge(folder, "^discogsMeta_")
except OSError as e:
    if silent == 1:
        print e
    pass

# write the output or fail
if len(parsedResults) > 0:
    writeOutput(parsedResults)
    sys.exit(0)
else:
    if silent == 1:
        print 'Sadly we could not match any meta data..'
    sys.exit(1)