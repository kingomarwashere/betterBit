# VERSION: 1.0
# AUTHORS: betterBit

# Adult (XXX) results from The Pirate Bay via the apibay.org JSON API — the same
# reliable backend used by the piratebay plugin, restricted to the porn category.

import datetime
import gzip
import html
import http.client
import io
import json
import urllib.error
import urllib.request
from typing import Mapping
from urllib.parse import unquote, urlencode

import helpers  # for setting SOCKS proxy side-effect
from novaprinter import prettyPrinter

helpers.htmlentitydecode  # pylint: disable=pointless-statement # dirty workaround to surpress static checkers


class pornbay:
    url = 'https://thepiratebay.org'
    name = 'PornBay'
    # TPB top-level porn category is 500; apibay filters by the category prefix.
    supported_categories = {
        'all': '500',
        'movies': '505',
        'pictures': '503',
        'games': '504',
    }

    # initialize trackers for magnet links
    trackers_list = [
        'udp://tracker.internetwarriors.net:1337/announce',
        'udp://tracker.opentrackr.org:1337/announce',
        'udp://p4p.arenabg.ch:1337/announce',
        'udp://tracker.openbittorrent.com:6969/announce',
        'udp://www.torrent.eu.org:451/announce',
        'udp://tracker.torrent.eu.org:451/announce',
        'udp://retracker.lanta-net.ru:2710/announce',
        'udp://open.stealth.si:80/announce',
        'udp://exodus.desync.com:6969/announce',
        'udp://tracker.tiny-vps.com:6969/announce'
    ]
    trackers = '&'.join(urlencode({'tr': tracker}) for tracker in trackers_list)

    def search(self, what: str, cat: str = 'all') -> None:
        base_url = "https://apibay.org/q.php?%s"

        # get response json
        what = unquote(what)
        category = self.supported_categories[cat]
        params = {'q': what, 'cat': category}

        # Calling custom `retrieve_url` function with adequate escaping
        data = self.retrieve_url(base_url % urlencode(params))
        response_json = json.loads(data)

        # check empty response
        if len(response_json) == 0:
            return

        # parse results
        for result in response_json:
            if result['info_hash'] == '0000000000000000000000000000000000000000':
                continue
            prettyPrinter({
                'link': self.download_link(result),
                'name': result['name'],
                'size': str(result['size']) + " B",
                'seeds': result['seeders'],
                'leech': result['leechers'],
                'engine_url': self.url,
                'desc_link': self.url + '/description.php?id=' + result['id'],
                'pub_date': result['added'],
            })

    def download_link(self, result: Mapping[str, str]) -> str:
        dn = urlencode({'dn': result['name']})
        return f"magnet:?xt=urn:btih:{result['info_hash']}&{dn}&{self.trackers}"

    def retrieve_url(self, url: str) -> str:
        def getBrowserUserAgent() -> str:
            """ Disguise as browser to circumvent website blocking """

            baseDate = datetime.date(2024, 4, 16)
            baseVersion = 125

            nowDate = datetime.date.today()
            nowVersion = baseVersion + ((nowDate - baseDate).days // 30)

            return f"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:{nowVersion}.0) Gecko/20100101 Firefox/{nowVersion}.0"

        # Request data from API
        request = urllib.request.Request(url, None, {'User-Agent': getBrowserUserAgent()})

        try:
            response: http.client.HTTPResponse = urllib.request.urlopen(request)  # pylint: disable=consider-using-with
        except urllib.error.HTTPError:
            return ""

        data = response.read()

        if data[:2] == b'\x1f\x8b':
            # Data is gzip encoded, decode it
            with io.BytesIO(data) as stream, gzip.GzipFile(fileobj=stream) as gzipper:
                data = gzipper.read()

        charset = 'utf-8'
        try:
            charset = response.getheader('Content-Type', '').split('charset=', 1)[1]
        except IndexError:
            pass

        dataStr = data.decode(charset, 'replace')
        dataStr = dataStr.replace('&quot;', '\\"')  # Manually escape &quot; before
        dataStr = html.unescape(dataStr)

        return dataStr
