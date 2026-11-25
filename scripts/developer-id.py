#!/usr/bin/env python3
"""Find, install or create the team's Developer ID Application certificate through the App Store Connect API.

The API key comes from ASC_KEY_PATH (the .p8 file), ASC_KEY_ID and ASC_ISSUER_ID. The release workflow runs
`install` to put the identity for DEVELOPER_ID_KEY into its keychain; set-release-secrets.sh runs `check`, `count`
and `create`. Nothing here prints key material. See docs/release.md.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = 'https://api.appstoreconnect.apple.com/v1/'
# Certificates issued from the G2 Sub-CA report the _G2 type.
TYPES = ('DEVELOPER_ID_APPLICATION', 'DEVELOPER_ID_APPLICATION_G2')
# Apple's limit on Developer ID Application certificates per team.
CAP = 5


def encode(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=')


def openssl(*args, data=None):
    return subprocess.run(['/usr/bin/openssl', *args], input=data, capture_output=True, check=True).stdout


def token():
    """An ES256 JWT for the API key, signed with openssl and converted from DER to the raw r||s JWS form."""
    header = {'alg': 'ES256', 'kid': os.environ['ASC_KEY_ID'], 'typ': 'JWT'}
    now = int(time.time())
    claims = {'iss': os.environ['ASC_ISSUER_ID'], 'iat': now, 'exp': now + 600, 'aud': 'appstoreconnect-v1'}
    signed = encode(json.dumps(header).encode()) + b'.' + encode(json.dumps(claims).encode())
    der = openssl('dgst', '-sha256', '-sign', os.environ['ASC_KEY_PATH'], data=signed)
    # SEQUENCE { INTEGER r, INTEGER s }, each at most 33 bytes, so every length fits in one byte.
    if der[0] != 0x30 or der[2] != 0x02:
        raise RuntimeError('Unexpected ECDSA signature encoding')
    r_end = 4 + der[3]
    r, s = der[4:r_end], der[r_end + 2:r_end + 2 + der[r_end + 1]]
    raw = b''.join(value.lstrip(b'\0').rjust(32, b'\0') for value in (r, s))
    return (signed + b'.' + encode(raw)).decode()


def request(method, path, body=None, **query):
    url = API + path + ('?' + urllib.parse.urlencode(query) if query else '')
    data = json.dumps(body).encode() if body is not None else None
    call = urllib.request.Request(url, data=data, method=method, headers={
        'Authorization': 'Bearer ' + token(), 'Content-Type': 'application/json'})
    with urllib.request.urlopen(call, timeout=60) as response:
        content = response.read()
    return json.loads(content) if content else None


def certificates():
    return request('GET', 'certificates', limit=200, **{'filter[certificateType]': ','.join(TYPES)})['data']


def find(key):
    """The Developer ID Application certificate whose public key is `key`'s, as (ID, expiry, PEM)."""
    public = openssl('pkey', '-in', str(key), '-pubout')
    for item in certificates():
        pem = openssl('x509', '-inform', 'DER', data=base64.b64decode(item['attributes']['certificateContent']))
        if openssl('x509', '-noout', '-pubkey', data=pem) == public:
            return item['id'], item['attributes'].get('expirationDate', '?'), pem
    raise RuntimeError('No Developer ID Application certificate on the team matches this private key')


def install(key, keychain, state):
    """Imports the identity (certificate and key) into `keychain`."""
    certificate_id, expiry, pem = find(key)
    state.mkdir(parents=True, exist_ok=True)
    cer, p12 = state / 'developer-id.pem', state / 'developer-id.p12'
    cer.write_bytes(pem)
    password = base64.b16encode(os.urandom(16)).decode()
    # LibreSSL's PKCS#12 defaults (3DES key bag, SHA-1 MAC) are what `security import` reads.
    openssl('pkcs12', '-export', '-inkey', str(key), '-in', str(cer), '-out', str(p12), '-passout', 'pass:' + password)
    try:
        subprocess.run(['/usr/bin/security', 'import', str(p12), '-k', keychain, '-P', password,
                        '-T', '/usr/bin/codesign'], check=True)
    finally:
        p12.unlink()
    print(f'Installed Developer ID certificate {certificate_id} (expires {expiry})')


def count():
    """Prints the team's Developer ID Application certificates against the cap and returns how many there are."""
    existing = certificates()
    print(f'The team has {len(existing)} of at most {CAP} Developer ID Application certificates:')
    for item in existing:
        print(f"  {item['id']}  {item['attributes'].get('displayName', '')}, "
              f"expires {item['attributes'].get('expirationDate', '?')}")
    return len(existing)


def create(csr):
    """Asks Apple for a Developer ID Application certificate for `csr` and prints its ID."""
    if count() >= CAP:
        raise RuntimeError(f'The team is at the cap of {CAP}: revoke one at developer.apple.com first')
    created = request('POST', 'certificates', {'data': {'type': 'certificates', 'attributes': {
        'certificateType': 'DEVELOPER_ID_APPLICATION_G2', 'csrContent': csr.read_text()}}})
    print(f"Created Developer ID certificate {created['data']['id']} "
          f"(expires {created['data']['attributes'].get('expirationDate', '?')})")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('command', choices=('check', 'count', 'install', 'create'))
    parser.add_argument('--key', type=Path, help='Developer ID private key, PEM (check, install)')
    parser.add_argument('--keychain', help='Keychain to import the identity into (install)')
    parser.add_argument('--state', type=Path, help='Scratch directory for the certificate (install)')
    parser.add_argument('--csr', type=Path, help='Certificate signing request, PEM (create)')
    args = parser.parse_args()
    if args.command == 'check':
        if not args.key:
            parser.error('check requires --key')
        certificate_id, expiry, _ = find(args.key)
        print(f'The key belongs to Developer ID certificate {certificate_id} (expires {expiry})')
    elif args.command == 'count':
        count()
    elif args.command == 'install':
        if not (args.key and args.keychain and args.state):
            parser.error('install requires --key, --keychain and --state')
        install(args.key, args.keychain, args.state)
    else:
        if not args.csr:
            parser.error('create requires --csr')
        create(args.csr)


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        sys.exit(f'App Store Connect: {error.code} {error.read().decode(errors="replace")}')
    except (RuntimeError, OSError, KeyError, IndexError, subprocess.CalledProcessError) as error:
        sys.exit(f'Developer ID: {error}')
