#!/usr/bin/python

rest_url = 'http://modbase.compbio.ucsf.edu/modfoo/job'

import urllib2
from xml.dom.minidom import parseString
import time
import subprocess

def submit_job(pdb, job_name):
    # Sadly Python currently has no method to POST multipart forms, so we
    # use curl instead
    p = subprocess.Popen(['/usr/bin/curl', '-F', 'input_pdb=@' + pdb,
                          '-F', 'job_name=' + job_name, rest_url],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out, err) = p.communicate()
    dom = parseString(out)

    top = dom.getElementsByTagName('saliweb')[0]
    for results in top.getElementsByTagName('job'):
        url = results.getAttribute('xlink:href')
        dom.unlink()
        return url
    dom.unlink()
    raise IOError("Cannot submit job: " + out + err)

def get_results(url):
    while True:
        try:
            u = urllib2.urlopen(url)
            return u
        except urllib2.HTTPError, detail:
            if detail.code == 503:
                print "Not done yet: waiting and retrying"
            else:
                raise
        time.sleep(30)

def main():
    pdb = 'input.pdb'
    job_name = 'testjob'
    url = submit_job(pdb, job_name)
    print "Results will be found at " + url

    u = get_results(url)
    dom = parseString(u.read())

    print "Got results:"
    top = dom.getElementsByTagName('saliweb')[0]
    for results in top.getElementsByTagName('results_file'):
        url = results.getAttribute('xlink:href')
        print "   " + url
        u = urllib2.urlopen(url)
        print u.read()
    dom.unlink()

if __name__ == '__main__':
    main()
