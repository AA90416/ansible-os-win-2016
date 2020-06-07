#!/usr/bin/python

try:
    import json
    import logging
    import base64
    import requests
    import time
    IMPORT_STATUS = True
except ImportError:
    IMPORT_STATUS = False


def _getApiSession(module, ontap_credentials):
    apiuri = '/auth/login'
    url = ontap_credentials['apiurl'] + apiuri
    data = { 
        "email": ontap_credentials['username'], 
        "password": ontap_credentials['password'] 
    }
    headers = { "Content-Type": "application/json" }

    session = requests.Session()
    try:
        session.post(url, json=data, headers=headers, verify=False) 
    except requests.exceptions.RequestException as e:
        module.fail_json(msg=e)

    return session

def _getVolumeStatus(module, ontap_credentials, session):
    apiuri = '/vsa/volumes?workingEnvironmentId=' + ontap_credentials['workingEnvironment']
    url = ontap_credentials['apiurl'] + apiuri

    try:
        vols = session.get(url)
    except requests.exceptions.RequestException as e:
        module.fail_json(msg=e)

    found = False

    if vols.status_code == 200: 
        volJson = json.loads(vols.text)
        for volume in volJson:
            if volume['name'] == ontap_credentials['volName']:
                found = True	
    else:
        print "Volume status call failed! " + vols.text

    return found

def _createVolume(module, ontap_credentials, session):
    apiuri = '/vsa/volumes'
    url = ontap_credentials['apiurl'] + apiuri
    body = {
        "workingEnvironmentId": ontap_credentials['workingEnvironment'],
        "svmName": ontap_credentials['svmName'],
        "aggregateName": ontap_credentials['aggrName'],
        "name": ontap_credentials['volName'],
        "size": {
          "size": ontap_credentials['volSize'],
          "unit": "GB"
        },
        "snapshotPolicyName": "default",
        "exportPolicyInfo": {
          "policyType": "custom",
          "ips": [
            ontap_credentials['export']
          ]
        },
        "enableThinProvisioning": "true",
        "enableCompression": "true",
        "enableDeduplication": "true",
        "maxNumOfDisksApprovedToAdd": "1",
        "syncToS3": "false",
    }

    try:
        new_vol = session.post(url, json=body)
    except requests.exceptions.RequestException as e:
        module.fail_json(msg=e)

    return new_vol

def main():
    module = AnsibleModule(
        supports_check_mode=True,
        argument_spec=dict(
            apiurl = dict(required=True),
            workingEnvironment = dict(required=True),
            svmName = dict(required=True),
            aggrName = dict(required=True),
            volName = dict(required=True),
            volSize = dict(required=True),
            export = dict(required=True),
            username = dict(required=True),
            password = dict(required=True,no_log=True)
        )
    )
    if not IMPORT_STATUS:
	module.fail_json(msg='Missing dependencies for module')
    has_changed = False
    req_accepted = False

    # Create cred object from params
    ontap_credentials = {}
    ontap_credentials['apiurl'] = module.params['apiurl'] 
    ontap_credentials['workingEnvironment'] = module.params['workingEnvironment']
    ontap_credentials['svmName'] = module.params['svmName']
    ontap_credentials['aggrName'] = module.params['aggrName']
    ontap_credentials['username'] = module.params['username']
    ontap_credentials['password'] = module.params['password']
    ontap_credentials['volName'] = module.params['volName']
    # Volume size unit is GB!
    ontap_credentials['volSize'] = module.params['volSize']
    ontap_credentials['export'] = module.params['export']

    # Start API session
    session = _getApiSession(module, ontap_credentials)
    # Check if volume already exists
    volume_exists = _getVolumeStatus(module, ontap_credentials, session)

    # If volume doesn't already exist, create it.
    if volume_exists == False:
        result = _createVolume(module, ontap_credentials, session)
        if result.status_code == 202: req_accepted = True

    # The API returns an ambivalent 'message recieved' 202 status on a successful call. This doesn't mean the volume gets created, though. We need to poll the NAS to confirm the volume spins up.
    if req_accepted:
        t_end = time.time() + 30
        while time.time() < t_end:
            new_volume_exists = _getVolumeStatus(module, ontap_credentials, session)
            if new_volume_exists:
                has_changed = True
                break
            time.sleep(10)
        if new_volume_exists == False:
            module.fail_json(msg="Timeout received before volume could be confirmed.")
    elif volume_exists == False:
        failmsg = "Unable to create volume. HTTP Status code " + result.status_code
        module.fail_json(msg=failmsg)

    # Exit and report result	
    module.exit_json(changed=has_changed, apiurl=ontap_credentials['apiurl'], datacenter=ontap_credentials['workingEnvironment'], username=ontap_credentials['username'], password=ontap_credentials['password'] )

# import module snippets; maybe I'll be an Ansible module someday
from ansible.module_utils.basic import *
from ansible.module_utils.urls import *
if __name__ == '__main__':
    main()
