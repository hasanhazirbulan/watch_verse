#!/usr/bin/env python3
"""Prepares (and optionally submits) a new App Store version in one go.

Run it once the previous version is approved / Ready for Sale:

    pip install pyjwt cryptography requests
    ASC_ISSUER_ID=... python3 tool/asc_release.py 1.0.1 26            # prepare only
    ASC_ISSUER_ID=... python3 tool/asc_release.py 1.0.1 26 --submit   # and submit

What it does, in order:
1. Creates the App Store version (or reuses it if it already exists).
2. Sets the English "What's New" text (WHATS_NEW below).
3. Attaches the processed build with that build number.
4. Replaces the screenshot sets with build/screenshots/* (made by
   tool/app_store_screenshots.sh), one set per entry in SETS.
5. With --submit, submits the version for review.

Key: App Store Connect API key ASC_KEY_ID (default MG839P5X8H) at
~/.appstoreconnect/private_keys/AuthKey_<id>.p8, issuer from ASC_ISSUER_ID.
"""
import glob
import hashlib
import os
import sys
import time

import jwt
import requests

APP_ID = '6797998286'
KEY_ID = os.environ.get('ASC_KEY_ID', 'MG839P5X8H')
ISSUER = os.environ.get('ASC_ISSUER_ID')
LOCALE = 'en-US'

# screenshotDisplayType -> folder under build/screenshots.
SETS = {
    'APP_IPHONE_61': 'iphone_6_3',
    'APP_IPHONE_67': 'iphone_6_9',
    'APP_IPAD_PRO_3GEN_129': 'ipad_13',
    'APP_IPHONE_DUO': ['duo_outer', 'duo_inner'],
}

WHATS_NEW = """\
• Fits tonight: tell it how much time you have and see the movies and episode runs from your own lists that fit — optionally only what's on your streaming services.
• Common ground: on a friend's profile, see what's on both your watchlists, how often your ratings agree, and start a watch poll in one tap.
• Where you left off: shows you haven't touched in a month get a spoiler-free recap of the last episodes you watched.
• Redesigned Games hub, and layouts made for iPhone Duo, iPad and landscape.
• Fixes: subscriptions now end correctly, imported films show their hours right away, PNG profile photos work, and you can remove your photo."""

API = 'https://api.appstoreconnect.apple.com'


def _token():
    key = open(os.path.expanduser(
        f'~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8')).read()
    now = int(time.time())
    return jwt.encode(
        {'iss': ISSUER, 'iat': now, 'exp': now + 1100, 'aud': 'appstoreconnect-v1'},
        key, algorithm='ES256', headers={'kid': KEY_ID})


def call(method, path, body=None):
    r = requests.request(method, API + path, json=body,
                         headers={'Authorization': 'Bearer ' + _token()})
    if r.status_code >= 400:
        sys.exit(f'{method} {path} -> {r.status_code}\n{r.text[:1500]}')
    return r.json() if r.text else {}


def ensure_version(version):
    found = call('GET', f'/v1/apps/{APP_ID}/appStoreVersions'
                 f'?filter[versionString]={version}&filter[platform]=IOS')['data']
    if found:
        print(f'version {version}: exists ({found[0]["attributes"]["appStoreState"]})')
        return found[0]['id']
    created = call('POST', '/v1/appStoreVersions', {'data': {
        'type': 'appStoreVersions',
        'attributes': {'platform': 'IOS', 'versionString': version},
        'relationships': {'app': {'data': {'type': 'apps', 'id': APP_ID}}}}})
    print(f'version {version}: created')
    return created['data']['id']


def localization(version_id):
    locs = call('GET', f'/v1/appStoreVersions/{version_id}'
                '/appStoreVersionLocalizations')['data']
    for loc in locs:
        if loc['attributes']['locale'] == LOCALE:
            return loc['id']
    sys.exit(f'no {LOCALE} localization on the version')


def attach_build(version_id, version, build_number):
    builds = call('GET', f'/v1/builds?filter[app]={APP_ID}'
                  f'&filter[version]={build_number}'
                  f'&filter[preReleaseVersion.version]={version}')['data']
    if not builds:
        sys.exit(f'build {version} ({build_number}) not found — upload it and '
                 'wait for processing to finish')
    state = builds[0]['attributes']['processingState']
    if state != 'VALID':
        sys.exit(f'build {build_number} is still {state}; rerun when processed')
    call('PATCH', f'/v1/appStoreVersions/{version_id}/relationships/build',
         {'data': {'type': 'builds', 'id': builds[0]['id']}})
    print(f'build {build_number}: attached')


def upload_screenshot(set_id, path):
    data = open(path, 'rb').read()
    shot = call('POST', '/v1/appScreenshots', {'data': {
        'type': 'appScreenshots',
        'attributes': {'fileName': os.path.basename(path), 'fileSize': len(data)},
        'relationships': {'appScreenshotSet': {
            'data': {'type': 'appScreenshotSets', 'id': set_id}}}}})['data']
    for op in shot['attributes']['uploadOperations']:
        chunk = data[op['offset']:op['offset'] + op['length']]
        headers = {h['name']: h['value'] for h in op['requestHeaders']}
        requests.request(op['method'], op['url'], data=chunk,
                         headers=headers).raise_for_status()
    call('PATCH', f'/v1/appScreenshots/{shot["id"]}', {'data': {
        'type': 'appScreenshots', 'id': shot['id'],
        'attributes': {'uploaded': True,
                       'sourceFileChecksum': hashlib.md5(data).hexdigest()}}})


def replace_screenshots(loc_id):
    existing = {s['attributes']['screenshotDisplayType']: s['id'] for s in call(
        'GET', f'/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets')['data']}
    for display_type, folders in SETS.items():
        folders = folders if isinstance(folders, list) else [folders]
        files = [f for d in folders
                 for f in sorted(glob.glob(f'build/screenshots/{d}/*.png'))][:10]
        if not files:
            print(f'{display_type}: no screenshots in {folders}, left as is')
            continue
        if display_type in existing:
            call('DELETE', f'/v1/appScreenshotSets/{existing[display_type]}')
        set_id = call('POST', '/v1/appScreenshotSets', {'data': {
            'type': 'appScreenshotSets',
            'attributes': {'screenshotDisplayType': display_type},
            'relationships': {'appStoreVersionLocalization': {
                'data': {'type': 'appStoreVersionLocalizations', 'id': loc_id}}}}}
                      )['data']['id']
        for f in files:
            upload_screenshot(set_id, f)
        print(f'{display_type}: uploaded {len(files)} screenshots')


def submit(version_id):
    sub = call('POST', '/v1/reviewSubmissions', {'data': {
        'type': 'reviewSubmissions', 'attributes': {'platform': 'IOS'},
        'relationships': {'app': {'data': {'type': 'apps', 'id': APP_ID}}}}})['data']
    call('POST', '/v1/reviewSubmissionItems', {'data': {
        'type': 'reviewSubmissionItems',
        'relationships': {
            'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': sub['id']}},
            'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': version_id}}}}})
    call('PATCH', f'/v1/reviewSubmissions/{sub["id"]}', {'data': {
        'type': 'reviewSubmissions', 'id': sub['id'],
        'attributes': {'submitted': True}}})
    print('submitted for review')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) != 2 or not ISSUER:
        sys.exit(__doc__)
    version, build_number = args
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    version_id = ensure_version(version)
    loc_id = localization(version_id)
    call('PATCH', f'/v1/appStoreVersionLocalizations/{loc_id}', {'data': {
        'type': 'appStoreVersionLocalizations', 'id': loc_id,
        'attributes': {'whatsNew': WHATS_NEW}}})
    print("what's new: set")
    attach_build(version_id, version, build_number)
    replace_screenshots(loc_id)
    if '--submit' in sys.argv:
        submit(version_id)
    else:
        print('prepared; review it in App Store Connect, then rerun with --submit')


if __name__ == '__main__':
    main()
