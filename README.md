# levurehelper-macos_notary
Levure helper for notarizing the DMG file that will be used to distribute your macOS application. This helper runs when you package your Levure application and will notarize a DMG file that exists in the package folder alongside the `macos` folder.

For detailed instructions on how the notarization process works please refer to the following article by Matthias Rebbe: 

http://lessons.livecode.com/m/4071/l/1122100-codesigning-and-notarizing-your-lc-standalone-for-distribution-outside-the-mac-appstore

If you need a helper that creates DMG files refer to the [DropDMG helper](https://github.com/trevordevore/levurehelper-dropDMG).

## Contents

* [Activate the macos_notary helper](#activate-the-macos_notary-helper)
* [Configuring settings for the helper](#configuring-settings-for-the-helper)
* [Monitoring progress during notarization](#monitoring-progress-during-notarization)

## Activate the macos_notary helper

To add the macos_notary helper to your application you must download it and add the `macos_notary` folder to your application `helpers` folder.

Click on the green **Clone or download** button on the GitHub page and select **Download ZIP** from the menu that appears. Grab the folder from the archive and rename it to `macos_notary`. Add the renamed folder to your application `helpers` folder.

You will then need to explicitly add an entry to the `helpers` section of your `app.yml` file. This helper must be run AFTER a DMG file has been created. 
for example, if you are using the DropDMG helper your `app.yml` file might look like this:

```
helpers:
  - filename: helpers/dropDMG
  - filename: helpers/macos_notary
  - folder: helpers/
```

## Configuring settings for the helper

You will store the username, password, and teamid in an `.env` file that sits alongside the `app.yml` file in your application folder. This file SHOULD NOT be included in your git repository as you do not want your username or password to be stored.

The `.env` file should contain the following lines although `macos_notary_ascprovider` is optional):

```
macos_notary_username=YOUR_APPLE_ID
macos_notary_password=YOUR_APP_PASSWORD_OR_KEYCHAIN_ITEM
macos_notary_teamid=YOUR_TEAMID
```

The macos_notary_username APPLE_ID will typically be the email address you use to login to Apple Developer service.  
The macos_notary_password is an application specific password (see heading 1.3 of the article by Matthias Rebbe - link above).
You can find the Team ID used for macos_notary_teamid on the Apple developer website. At the time of this writing it is listed under Membership Details at https://developer.apple.com/account#MembershipDetailsCard.

If you would like to store the information in the macOS Keychain then follow the instructions at https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow which explain how to use `xcrun notarytool store-credentials` to store credentials. In the `.env` file set the `macos_notary_keychain` value to the name of the keychain and omit `macos_notary_username`, `macos_notary_password`, and `macos_notary_teamid`.

Example `.env` entry using the keychain name in the Apple docs example:

```
macos_notary_keychain=AC_PASSWORD
```

## Monitoring progress during notarization

All status updates will be logged to the `build.log` file that is generated whenever calling `levurePackageApplication`. This file is located in the root of the `builds` folder. You will find all command line calls as well as the data returned from those calls in the log. Note that the password will be redacted.
