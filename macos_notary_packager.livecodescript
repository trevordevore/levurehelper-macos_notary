script "macOS Notary Packager"

/**
Summary: Update localization folders with ISO naming scheme.

*/
command finalizePackageForPlatform pBuildProfile, pPlatform, pAppA, pAppFolder, pOutputFolder
  local tFile, tData, tBuildProfile, tURL

  switch pPlatform
    case "macos"
      _standardizeLocalizationFolderNames pOutputFolder & "/" & levureStandaloneName()
      break
  end switch
end finalizePackageForPlatform


/**
Summary: Notarizes a DMG file.

Parameters:
pBuildProfile:
pOutputFolder: Root path to output folder.
pAppA: If the `macos dmg filename` key points to a DMG file that path will be used. Otherwise `pOutputFolder` is searched for a .dmg file.

Description:
This handler will notarize and staple the DMG file so it may take a while to run.

Returns: nothing

*/
command packagingComplete pBuildProfile, pOutputFolder, pAppA
  if the platform is not "macos" then return empty

  local tCmd, tPrimaryId, tEnvA, tResult, tReturnVal

  put levureAppGetENV() into tEnvA
  put _resolveFileToNotarize(pOutputFolder, pAppA["macos dmg filename"]) into tEnvA["macos dmg filename"]

  if there is not a file tEnvA["macos dmg filename"] then
    answer error "macOS Notary error: No path to DMG file provided and no DMG file was found in " &quote& pOutputFolder &quote& "."
    return empty
  end if

  put format("xcrun notarytool submit \"%s\" --wait", tEnvA["macos dmg filename"]) into tCmd

  if tEnvA["macos_notary_keychain"] is not empty then
    put format(" --keychain-profile \"%s\"", tEnvA["macos_notary_keychain"]) after tCmd
  else
    # URL encode special characters
    put _rawURLEncode(tEnvA["macos_notary_password"]) into tEnvA["macos_notary_password"]
    put format(" --apple-id \"%s\" --team-id \"%s\" --password \"%s\"", tEnvA["macos_notary_username"], tEnvA["macos_notary_teamid"], tEnvA["macos_notary_password"]) after tCmd
  end if

  _log "macos-notary --notarize-app command:" && tCmd
  put shell(tCmd) into tResult
  put the result into tReturnVal

  put textDecode(tResult, "utf8") into tResult
  _log "macos-notary --notarize-app response:" &cr& tResult

  if tReturnVal is empty then
    if tResult contains "status: Accepted" then
      local tRequestUUID

      put _extractRequestUUID(tResult) into tRequestUUID
      if tRequestUUID is not empty then
        _stapleDMG tEnvA["macos dmg filename"]
      else
        answer error "RequestUUID was not found in the response" & cr & "[" & tResult & "]"
      end if
    else
      answer error "Notarization failed. Check build.log for details."
    end if
  else
    answer error "macOS Notary reported an error in" && param(0) && "[" & tResult & "]"
  end if
end packagingComplete


/**
Summary: Locates a DMG file to notarize.

Parameters:
pRootFolder: The folder to search for a DMG.
pFilename: If this points to an existing file then that file will be notarized and pRootFolder will not be searched.

Returns: Filename
*/
private function _resolveFileToNotarize pRootFolder, pFilename
  if pFilename is not empty and there is a file pFilename then
    return pFilename
  else
    local tFiles

    put files(pRootFolder) into tFiles
    filter tFiles with "*.dmg"

    return line 1 of tFiles
  end if
end _resolveFileToNotarize


/**
Summary: Extract the RequestUUID from the `xcrun altool -type osx --notarize-app` response.

Parameters:
pAlToolResponse: The data returned from the call.

Returns: UUID
*/
private function _extractRequestUUID pAlToolResponse
  local tLineNo, tLine, tRequestUUID

  put lineoffset("  id: ", pAlToolResponse) into tLineNo
  if tLineNo > 0 then
    put word 1 to -1 of line tLineNo of pAlToolResponse into tLine
    split tLine by CR and ": "
    put word 1 to -1 of tLine["id"] into tRequestUUID
  end if

  return tRequestUUID
end _extractRequestUUID


/**
Summary: Converts a response from `xcrun altool --notarization-info` to an array.

Parameters:
pAlToolResponse: The data returned from the call.

Description:

Keys in the array include:

- RequestUUID
- Date
- Status
- LogFileURL
- Status Code
- Status Message

Returns: Array
*/
private function _extractResponseVariables pAlToolResponse
  local tLineNo, tVariables, tKey, tValuesA

  put lineoffset("RequestUUID: ", pAlToolResponse) into tLineNo
  if tLineNo > 0 then
    put line tLineNo to -1 of pAlToolResponse into tVariables
    split tVariables by CR and ": "

    # Strip out whitespace around keys
    repeat for each key tKey in tVariables
      put tVariables[tKey] into tValuesA[word 1 to -1 of tKey]
    end repeat
  end if

  return tValuesA
end _extractResponseVariables


/**
Summary: Staple notarization information to the DMG after it has been successfully notarized.

Parameters:
pFilename: The path to the file to staple.

Returns: nothing
*/
private command _stapleDMG pFilename
  local tCmd, tResult, tReturnVal

  put format("xcrun stapler staple -v \"%s\"", pFilename) into tCmd
  _log "macos-notary stapler command:" && tCmd
  put shell(tCmd) into tResult
  put the result into tReturnVal

  put textDecode(tResult, "utf8") into tResult
  _log "macos-notary stapler response:" &cr& tResult

  if tReturnVal is not empty then
    answer error "macOS Notary reported an error in stapler" && "[" & tResult & "]"
  end if

  return empty
end _stapleDMG


/**
Summary: Replaces .lproj folders with ISO names.

Returns: nothing
*/
private command _standardizeLocalizationFolderNames pAppBundleFolder
  local tError, tRsrcFolder, tFolders, tFolder
  local tNewFolder, tLocalesA

  put pAppBundleFolder & "/Contents/Resources" into tRsrcFolder

  put folders(tRsrcFolder) into tFolders
  filter tFolders with "*.lproj"

  put _localizationLookup() into tLocalesA

  set the itemDelimiter to "."

  repeat for each line tFolder in tFolders
    if item 1 of tFolder is among the keys of tLocalesA then
      put tFolder into tNewFolder
      put tLocalesA[item 1 of tFolder] into item 1 of tNewFolder
      rename (tRsrcFolder & "/" & tFolder) to (tRsrcFolder & "/" & tNewFolder)
      put the result into tError
    end if

    if tError is not empty then next repeat
  end repeat

  return tError
end _standardizeLocalizationFolderNames


private function _localizationLookup
  local tA

  put "nl" into tA["Dutch"]
  put "en" into tA["English"]
  put "fr" into tA["French"]
  put "de" into tA["German"]
  put "it" into tA["Italian"]
  put "jp" into tA["Japanese"]
  put "es" into tA["Spanish"]

  return tA
end _localizationLookup


private function _rawURLEncode pString
  put URLEncode(pString) into pString
  replace "+" with "%20" in pString
  replace "*" with "%2A" in pString
  return pString
end _rawURLEncode


private command _log pMsg
  put replaceText(pMsg, "--password " &quote& "(.*?)" &quote, "--password REDACTED") into pMsg
  dispatch "packagerLog" to stack "Levure Framework Application Packager" with pMsg
end _log
