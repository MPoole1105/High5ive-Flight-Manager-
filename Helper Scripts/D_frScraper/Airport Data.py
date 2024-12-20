"""
CKM

Code to fetch information like type and age about a set of airplane registrations automatically

// @param iata: the table of IATA codes to look up
// @param website: the website data is being sourced from
// @param latTest: select which of the different categories of airports which have different styles to test
// return output.csv: a version of the input table but with any information it could find in the relevant row

"""

import requests, time, string, random
from bs4 import BeautifulSoup

headers1 = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-GB,en;q=0.5",
    "Accept-Encoding": "gzip, deflate",
    "DNT": "1",
    "Upgrade-Insecure-Requests": "1",
    "Sec-gpc": "1",
    "If-Modified-Since": "Tue, 30 Mar 2024 23:34:21 GMT",
    "Connection": "keep-alive"
}

session1 = requests.Session()
session1.headers = headers1

iata = open("dataneeded.csv", "r")
output = open("output.csv", "a")
website = "http://www.gcmap.com/airport/"
latTest = 13
airports = []
for i in iata:
    airports.append(i.strip())
iata.close()

for i in airports:
    response = session1.get(f"{website}{i}")
    content = response.content.decode('utf-8', errors='ignore')
    soup = BeautifulSoup(content, 'html.parser')
    print(i)
    if response.history:
        output.write(f",,,,{i},," + "\n")
    elif response.status_code == 200:
        Tables = soup.body.find_all('table')
        trTables = soup.find_all('tr')
        citySection = str(trTables[4].find_all(class_='locality'))[24:-8]
        countrySection = str(trTables[4].find_all(class_='country-name'))[28:-8]
        nameSection = str(trTables[7].find_all(class_='fn org'))[32:-6]
        try:
            latSection = str(trTables[latTest].find_all(class_='latitude'))[31:-10]
            longSection = str(trTables[latTest+1].find_all(class_="longitude"))[32:-10]
        except:
            latSection = ""
            longSection = ""
        output.write(f"{nameSection},{citySection},,{countrySection},{i},{latSection},{longSection}" + "\n")

    else:
        print(response.status_code)