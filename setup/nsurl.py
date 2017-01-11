import urllib2

password = 'i-047a1d0944bb06f77'
nsip = '172.90.50.91'
snip = "172.90.1.224"

def add_snip(nsip, snip, password):
    url = 'http://{}/nitro/v1/config/nsip'.format(nsip)
    jsons = '{{"nsip":{{"ipaddress":"{}", "netmask":"255.255.255.0", "type":"snip"}}}}'.format(snip)
    headers = {'Content-Type': 'application/json', 'X-NITRO-USER':'nsroot', 'X-NITRO-PASS':password}
    r = urllib2.Request(url, data=jsons, headers=headers)
    try:
       urllib2.urlopen(r)
    except urllib2.HTTPError as hte:
        print ("Error code: " + str(hte.code))
        if hte.code == 409:
            print 'Conflict, but OK'


if __name__ == "__main__":
    r = add_snip(nsip, snip, password)
